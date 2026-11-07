// ===========================================================================
// Usb4BootGuard.cs
//
// Servizio "guardiano" per l'avvio di Windows dall'SSD Thunderbolt.
//
// Gli aggiornamenti di Windows reinstallano i driver USB4 e riportano
// Services\Usb4HostRouter\Start e Services\Usb4DeviceRouter\Start a 3.
// Il reset avviene durante l'installazione degli aggiornamenti che precede
// lo spegnimento, quando i servizi sono ancora attivi. Questo servizio:
//  - all'avvio controlla i valori e corregge quelli diversi;
//  - si fa avvisare da Windows a ogni modifica delle chiavi sorvegliate
//    (RegNotifyChangeKeyValue) e ripristina subito i valori;
//  - ricontrolla comunque a intervalli regolari e allo spegnimento.
// Valori sorvegliati: gli stessi di repair-usb4-boot.bat.
//
// Non crea mai chiavi mancanti: se un servizio non esiste, lo segnala e basta.
//
// Modalita' di prova (mai sul registro di sistema):
//   Usb4BootGuard.exe /console <percorso sotto HKCU> [secondi]
// sorveglia <percorso>\Services\... e <percorso>\Control sotto
// HKEY_CURRENT_USER, finche' non si preme Invio.
//
// Compilazione (C# 5, compilatore incluso in .NET Framework 4):
//   csc /target:exe /reference:System.ServiceProcess.dll Usb4BootGuard.cs
// L'installazione la fa usb4-boot-guard.ps1.
// ===========================================================================

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.ServiceProcess;
using System.Threading;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;

[assembly: System.Reflection.AssemblyTitle("Usb4BootGuard")]
[assembly: System.Reflection.AssemblyDescription("Keeps the USB4 drivers loaded at boot (windows-tb-boot)")]
[assembly: System.Reflection.AssemblyVersion("1.0.0.0")]

namespace WindowsTbBoot
{
    // Un valore DWORD da mantenere, relativo al control set.
    internal sealed class GuardedValue
    {
        public readonly string SubKey;
        public readonly string Name;
        public readonly int Expected;

        public GuardedValue(string subKey, string name, int expected)
        {
            SubKey = subKey;
            Name = name;
            Expected = expected;
        }
    }

    // Messaggi: italiano se la lingua di sistema e' l'italiano, altrimenti inglese.
    internal static class Msg
    {
        private static readonly bool It =
            CultureInfo.InstalledUICulture.TwoLetterISOLanguageName == "it";

        public static readonly string Started = It
            ? "Servizio avviato. Valori sorvegliati:"
            : "Service started. Guarded values:";
        public static readonly string Stopped = It
            ? "Servizio arrestato."
            : "Service stopped.";
        public static readonly string Restored = It
            ? "Valore ripristinato"
            : "Value restored";
        public static readonly string KeyMissing = It
            ? "Chiave mancante, nessuna modifica:"
            : "Key missing, nothing changed:";
        public static readonly string Error = It
            ? "Errore:"
            : "Error:";
        public static readonly string Missing = It ? "assente" : "missing";
        public static readonly string ReasonStartup = It ? "avvio" : "startup";
        public static readonly string ReasonChange = It ? "modifica rilevata" : "change detected";
        public static readonly string ReasonPeriodic = It ? "controllo periodico" : "periodic check";
        public static readonly string ReasonRetry = It ? "nuovo tentativo" : "retry";
        public static readonly string ReasonShutdown = It ? "spegnimento" : "shutdown";
        public static readonly string Usage = It
            ? "Questo programma e' un servizio di Windows: si installa con usb4-boot-guard.ps1.\r\n" +
              "Prova senza toccare il sistema: Usb4BootGuard.exe /console <percorso sotto HKCU> [secondi]"
            : "This program is a Windows service: install it with usb4-boot-guard.ps1.\r\n" +
              "Test without touching the system: Usb4BootGuard.exe /console <path under HKCU> [seconds]";
    }

    internal delegate void LogWriter(EventLogEntryType type, int eventId, string message);

    internal sealed class Guard
    {
        // ID degli eventi nel registro Applicazione
        public const int EvStarted = 1;
        public const int EvRestored = 2;
        public const int EvKeyMissing = 3;
        public const int EvError = 4;
        public const int EvStopped = 5;

        public static readonly GuardedValue[] Values =
        {
            new GuardedValue(@"Services\Usb4HostRouter", "Start", 0),
            new GuardedValue(@"Services\Usb4DeviceRouter", "Start", 0),
            new GuardedValue(@"Control", "BootDriverFlags", 0x14),
        };

        private const uint REG_NOTIFY_CHANGE_NAME = 0x1;
        private const uint REG_NOTIFY_CHANGE_LAST_SET = 0x4;

        [DllImport("advapi32.dll")]
        private static extern int RegNotifyChangeKeyValue(
            SafeRegistryHandle hKey, bool bWatchSubtree, uint dwNotifyFilter,
            SafeWaitHandle hEvent, bool fAsynchronous);

        private readonly RegistryKey root;
        private readonly string basePath;
        private readonly TimeSpan interval;
        private readonly LogWriter log;
        private readonly object sync = new object();
        private readonly ManualResetEvent stopEvent = new ManualResetEvent(false);
        private readonly HashSet<string> missingReported = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        private Thread thread;

        public Guard(RegistryKey root, string basePath, TimeSpan interval, LogWriter log)
        {
            this.root = root;
            this.basePath = basePath.TrimEnd('\\');
            this.interval = interval;
            this.log = log;
        }

        public void Start()
        {
            thread = new Thread(Run);
            thread.IsBackground = true;
            thread.Name = "Usb4BootGuard";
            thread.Start();
        }

        public void Stop()
        {
            stopEvent.Set();
            if (thread != null)
            {
                thread.Join(10000);
            }
        }

        // Controlla tutti i valori e corregge quelli diversi.
        // Restituisce il numero di valori corretti.
        public int Enforce(string reason)
        {
            lock (sync)
            {
                int corrected = 0;
                foreach (GuardedValue v in Values)
                {
                    string path = basePath + "\\" + v.SubKey;
                    try
                    {
                        using (RegistryKey key = root.OpenSubKey(path, true))
                        {
                            if (key == null)
                            {
                                if (missingReported.Add(path))
                                {
                                    log(EventLogEntryType.Warning, EvKeyMissing, Msg.KeyMissing + " " + path);
                                }
                                continue;
                            }
                            missingReported.Remove(path);

                            object current = key.GetValue(v.Name, null, RegistryValueOptions.DoNotExpandEnvironmentNames);
                            RegistryValueKind kind = current == null ? RegistryValueKind.Unknown : key.GetValueKind(v.Name);
                            if (kind == RegistryValueKind.DWord && current is int && (int)current == v.Expected)
                            {
                                continue;
                            }

                            key.SetValue(v.Name, v.Expected, RegistryValueKind.DWord);
                            corrected++;
                            log(EventLogEntryType.Warning, EvRestored, string.Format(
                                "{0} ({1}): {2}\\{3} {4} -> 0x{5:x}",
                                Msg.Restored, reason, v.SubKey, v.Name, Describe(current, kind), v.Expected));
                        }
                    }
                    catch (Exception ex)
                    {
                        log(EventLogEntryType.Error, EvError, Msg.Error + " " + path + "\\" + v.Name + ": " + ex.Message);
                    }
                }
                return corrected;
            }
        }

        public static string DescribeValues()
        {
            var parts = new List<string>();
            foreach (GuardedValue v in Values)
            {
                parts.Add(string.Format("{0}\\{1} = 0x{2:x}", v.SubKey, v.Name, v.Expected));
            }
            return string.Join("; ", parts.ToArray());
        }

        private static string Describe(object value, RegistryValueKind kind)
        {
            if (value == null)
            {
                return Msg.Missing;
            }
            if (value is int)
            {
                return "0x" + ((int)value).ToString("x", CultureInfo.InvariantCulture);
            }
            return kind + " \"" + value + "\"";
        }

        private IEnumerable<string> WatchedSubKeys()
        {
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (GuardedValue v in Values)
            {
                if (seen.Add(v.SubKey))
                {
                    yield return basePath + "\\" + v.SubKey;
                }
            }
        }

        // Ciclo di sorveglianza: registra le notifiche, POI controlla i valori,
        // poi attende. Cosi' una modifica avvenuta durante il controllo non va persa.
        // Ogni giro riapre le chiavi, quindi una chiave ricreata torna sorvegliata.
        private void Run()
        {
            string reason = Msg.ReasonStartup;
            while (!stopEvent.WaitOne(0))
            {
                var keys = new List<RegistryKey>();
                var waits = new List<WaitHandle>();
                waits.Add(stopEvent);
                try
                {
                    foreach (string path in WatchedSubKeys())
                    {
                        RegistryKey key = root.OpenSubKey(path, RegistryKeyPermissionCheck.ReadSubTree, RegistryRights.ReadKey);
                        if (key == null)
                        {
                            continue;
                        }
                        keys.Add(key);
                        var changed = new AutoResetEvent(false);
                        waits.Add(changed);
                        int rc = RegNotifyChangeKeyValue(key.Handle, false,
                            REG_NOTIFY_CHANGE_NAME | REG_NOTIFY_CHANGE_LAST_SET, changed.SafeWaitHandle, true);
                        if (rc != 0)
                        {
                            throw new Win32Exception(rc);
                        }
                    }

                    Enforce(reason);

                    int index = WaitHandle.WaitAny(waits.ToArray(), interval);
                    if (index == 0)
                    {
                        break;
                    }
                    reason = index == WaitHandle.WaitTimeout ? Msg.ReasonPeriodic : Msg.ReasonChange;
                }
                catch (Exception ex)
                {
                    log(EventLogEntryType.Error, EvError, Msg.Error + " " + ex.Message);
                    if (stopEvent.WaitOne(interval))
                    {
                        break;
                    }
                    reason = Msg.ReasonRetry;
                }
                finally
                {
                    foreach (RegistryKey key in keys)
                    {
                        key.Close();
                    }
                    for (int i = 1; i < waits.Count; i++)
                    {
                        waits[i].Close();
                    }
                }
            }
        }
    }

    internal sealed class GuardService : ServiceBase
    {
        public const string Name = "Usb4BootGuard";
        private Guard guard;

        public GuardService()
        {
            ServiceName = Name;
            CanStop = true;
            CanShutdown = true;
            AutoLog = false;
        }

        protected override void OnStart(string[] args)
        {
            WriteEvent(EventLogEntryType.Information, Guard.EvStarted, Msg.Started + " " + Guard.DescribeValues());
            guard = new Guard(Registry.LocalMachine, @"SYSTEM\CurrentControlSet", TimeSpan.FromSeconds(60), WriteEvent);
            guard.Start();
        }

        protected override void OnStop()
        {
            guard.Stop();
            WriteEvent(EventLogEntryType.Information, Guard.EvStopped, Msg.Stopped);
        }

        // Ultimo controllo: arriva dopo la fase di pre-spegnimento,
        // in cui Windows installa gli aggiornamenti.
        protected override void OnShutdown()
        {
            guard.Enforce(Msg.ReasonShutdown);
            guard.Stop();
        }

        public static void WriteEvent(EventLogEntryType type, int eventId, string message)
        {
            try
            {
                EventLog.WriteEntry(Name, message, type, eventId);
            }
            catch (Exception)
            {
                // Durante lo spegnimento il registro eventi puo' non essere piu' disponibile.
            }
        }
    }

    internal static class Program
    {
        private static int Main(string[] args)
        {
            if (args.Length >= 1 && string.Equals(args[0], "/console", StringComparison.OrdinalIgnoreCase))
            {
                return RunConsole(args);
            }
            if (Environment.UserInteractive)
            {
                Console.Error.WriteLine(Msg.Usage);
                return 2;
            }
            ServiceBase.Run(new GuardService());
            return 0;
        }

        // Modalita' di prova: lavora solo sotto HKEY_CURRENT_USER.
        private static int RunConsole(string[] args)
        {
            if (args.Length < 2)
            {
                Console.Error.WriteLine(Msg.Usage);
                return 2;
            }
            int seconds = 60;
            if (args.Length >= 3 && (!int.TryParse(args[2], out seconds) || seconds < 1))
            {
                Console.Error.WriteLine(Msg.Usage);
                return 2;
            }

            var guard = new Guard(Registry.CurrentUser, args[1], TimeSpan.FromSeconds(seconds), ConsoleLog);
            guard.Start();
            Console.WriteLine("ready");
            Console.ReadLine();
            guard.Stop();
            return 0;
        }

        private static void ConsoleLog(EventLogEntryType type, int eventId, string message)
        {
            Console.WriteLine("{0:HH:mm:ss.fff} [{1}] {2}", DateTime.Now, eventId, message);
        }
    }
}
