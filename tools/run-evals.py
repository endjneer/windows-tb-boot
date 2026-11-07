"""run-evals.py — esegue i casi di prova di evals/ con `claude -p`.

Alternativa a `claude plugin eval`, per gli ambienti in cui le sue sessioni figlie
non possono partire (per esempio per un hook che controlla l'account). Legge gli
stessi file: evals/<caso>/prompt.md e evals/<caso>/graders/*.md.

Ogni esecuzione parte da una cartella vuota, con `claude -p --restricted`: niente
Bash ne' strumenti che eseguono codice, niente impostazioni utente o di progetto,
solo Read, Glob, Grep e Skill. Il braccio "with" carica il plugin del repository
(--plugin-dir), il braccio "without" no.

Valutatori:
  regex      espressione regolare in Python (per questi casi equivalente a JavaScript)
  tool_used  solo indicatore, non entra nel punteggio
  llm        un giudice `claude -p`, tre voti a maggioranza come plugin eval (--votes)

Uso:  python3 tools/run-evals.py [--list] [--arms with,without] [--runs N]
                                 [--case GLOB] [-j N] [--model M] [--judge-model M]
                                 [--votes N] [--out CARTELLA]

Codice di uscita: 0 se nel braccio "with" ogni caso ha punteggio 1.00, altrimenti 1.
Risultati e tracce in evals/results/local-<data>/ (ignorata da git).
"""
import argparse
import concurrent.futures as cf
import datetime
import fnmatch
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILL_DIR = ROOT / ".claude" / "skills" / "windows-tb-boot"
TIMEOUT = 300

JUDGE = """Sei un valutatore rigoroso. Ricevi la richiesta di un utente, la risposta finale di un assistente
e alcuni criteri. Per ogni criterio decidi PASS o FAIL seguendo alla lettera le righe PASS se / FAIL se.
Giudica solo la risposta finale riportata. Rispondi SOLO con un oggetto JSON, senza testo prima o dopo:
{"<nome criterio>": {"verdict": "PASS" oppure "FAIL", "why": "<una frase>"}, ...}

=== RICHIESTA DELL'UTENTE ===
%s

=== RISPOSTA DELL'ASSISTENTE ===
%s

=== CRITERI ===
%s
"""


def split_front(text, where):
    lines = text.replace("\r\n", "\n").split("\n")
    if not lines or lines[0] != "---" or "---" not in lines[1:]:
        raise ValueError(f"{where}: frontmatter mancante o non chiuso")
    end = lines.index("---", 1)
    return lines[1:end], "\n".join(lines[end + 1:]).strip()


def parse_case(d):
    front, body = split_front((d / "prompt.md").read_text(encoding="utf-8"), d / "prompt.md")
    role, in_role = [], False
    for line in front:
        if line.startswith("append_system_prompt: |"):
            in_role = True
            continue
        if in_role:
            if line.startswith("  "):
                role.append(line[2:])
                continue
            in_role = False
    graders = {}
    for g in sorted((d / "graders").glob("*.md")):
        gf, gbody = split_front(g.read_text(encoding="utf-8"), g)
        meta = {}
        for line in gf:
            k, _, v = line.partition(":")
            v = v.strip()
            if len(v) >= 2 and v[0] == v[-1] == "'":
                v = v[1:-1]
            meta[k.strip()] = v
        meta["body"] = gbody
        if meta.get("type") not in ("regex", "llm", "tool_used"):
            raise ValueError(f"{g}: tipo di valutatore non gestito: {meta.get('type')}")
        if meta["type"] == "regex":
            re.compile(meta["pattern"])
        graders[g.stem] = meta
    if not body or not graders:
        raise ValueError(f"{d}: messaggio o valutatori mancanti")
    return {"name": d.name, "role": "\n".join(role), "prompt": body, "graders": graders}


def claude(prompt, extra):
    """Lancia claude -p in una cartella vuota; restituisce risposta, costo, strumenti, traccia."""
    cmd = ["claude", "-p", prompt, "--restricted", "--strict-mcp-config", "--no-session-persistence",
           "--output-format", "stream-json", "--verbose"] + extra
    with tempfile.TemporaryDirectory(prefix="run-evals-") as cwd:
        try:
            out = subprocess.run(cmd, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                 timeout=TIMEOUT).stdout
        except subprocess.TimeoutExpired as e:
            out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    result, cost, tools, blocked = "", 0.0, [], False
    for line in out.splitlines():
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if o.get("type") == "assistant":
            for c in o.get("message", {}).get("content", []):
                if c.get("type") == "tool_use":
                    tools.append(c.get("name"))
        elif o.get("type") == "result":
            result = o.get("result") or ""
            cost = o.get("total_cost_usd") or 0.0
        elif o.get("type") == "system" and o.get("subtype") == "informational" \
                and "blocked" in str(o.get("content")):
            blocked = True
    return result, cost, tools, blocked, out


def judge_once(case, answer, model, crit):
    text, cost, _, _, _ = claude(JUDGE % (case["prompt"], answer or "(nessuna risposta)", crit),
                                 ["--tools", "", "--model", model])
    m = re.search(r"\{.*\}", text, re.S)
    try:
        raw = json.loads(m.group(0))
        return {k.strip().strip("[]").strip(): v for k, v in raw.items()}, cost, text
    except (AttributeError, ValueError):
        return {}, cost, text


def judge(case, answer, model, votes):
    """Maggioranza di `votes` giudizi indipendenti; un giudizio illeggibile vale FAIL."""
    crit = "\n\n".join(f"[{n}]\n{g['body']}" for n, g in case["graders"].items() if g["type"] == "llm")
    if not crit:
        return {}, 0.0, ""
    rounds = [judge_once(case, answer, model, crit) for _ in range(votes)]
    verdicts = {}
    for n, g in case["graders"].items():
        if g["type"] != "llm":
            continue
        got = [r[0].get(n, {}) for r in rounds]
        passes = sum(v.get("verdict") == "PASS" for v in got)
        verdicts[n] = {"verdict": "PASS" if passes * 2 > votes else "FAIL",
                       "why": f"{passes}/{votes} PASS: " + (got[0].get("why") or "manca nel giudizio")}
    return verdicts, sum(r[1] for r in rounds), "\n---\n".join(r[2] for r in rounds)


def run_one(case, arm, i, args, out):
    extra = ["--tools", "Read,Glob,Grep,Skill", "--model", args.model]
    if case["role"]:
        extra += ["--append-system-prompt", case["role"]]
    if arm == "with":
        extra += ["--plugin-dir", str(ROOT), "--add-dir", str(SKILL_DIR)]
    answer, cost, tools, blocked, trace = claude(case["prompt"], extra)
    tag = f"{case['name']}-{arm}-{i}"
    (out / "traces" / f"{tag}.jsonl").write_text(trace, encoding="utf-8")
    verdicts, jcost, jtext = judge(case, answer, args.judge_model, args.votes)
    res = {}
    for n, g in case["graders"].items():
        if g["type"] == "regex":
            found = re.search(g["pattern"], answer, re.I if "i" in g.get("flags", "") else 0) is not None
            res[n] = {"pass": (not found) if g.get("match") == "not_contains" else found,
                      "why": "regex", "scored": True}
        elif g["type"] == "tool_used":
            k = tools.count(g.get("tool"))
            res[n] = {"pass": k >= 1, "why": f"{g.get('tool')} x{k}", "scored": False}
        else:
            v = verdicts.get(n, {})
            res[n] = {"pass": v.get("verdict") == "PASS", "why": v.get("why", "manca nel giudizio"),
                      "scored": True}
    scored = [r for r in res.values() if r["scored"]]
    return {"case": case["name"], "arm": arm, "run": i,
            "score": sum(r["pass"] for r in scored) / len(scored) if scored else 0.0,
            "graders": res, "answer": answer, "tools": tools, "blocked": blocked,
            "cost": cost + jcost, "judge": jtext}


def main():
    ap = argparse.ArgumentParser(description="Esegue i casi di evals/ con claude -p.")
    ap.add_argument("--list", action="store_true", help="controlla e elenca i casi, senza eseguirli")
    ap.add_argument("--arms", default="with,without")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--case", default="*")
    ap.add_argument("-j", type=int, default=4)
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--judge-model", default="sonnet")
    ap.add_argument("--votes", type=int, default=3, help="voti del giudice per esecuzione (dispari)")
    ap.add_argument("--out")
    args = ap.parse_args()

    if args.votes < 1 or args.votes % 2 == 0:
        sys.exit("ERRORE: --votes deve essere un numero dispari")
    arms = args.arms.split(",")
    if any(a not in ("with", "without") for a in arms):
        sys.exit("ERRORE: --arms accetta solo with e without")
    try:
        cases = [parse_case(d) for d in sorted((ROOT / "evals").iterdir())
                 if d.is_dir() and (d / "prompt.md").exists() and fnmatch.fnmatch(d.name, args.case)]
    except (ValueError, re.error) as e:
        sys.exit(f"ERRORE: {e}")
    if not cases:
        sys.exit("ERRORE: nessun caso trovato")
    if args.list:
        for c in cases:
            print(f"{c['name']:34} {'shell' if 'ESEGUO' in c['role'] else 'chat':5}  "
                  + ", ".join(f"{n} ({g['type']})" for n, g in c["graders"].items()))
        print(f"\n{len(cases)} casi")
        return 0

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = pathlib.Path(args.out) if args.out else ROOT / "evals" / "results" / f"local-{stamp}"
    (out / "traces").mkdir(parents=True, exist_ok=True)
    jobs = [(c, a, i) for c in cases for a in arms for i in range(1, args.runs + 1)]
    results = []
    with cf.ThreadPoolExecutor(args.j) as ex:
        for r in ex.map(lambda j: run_one(*j, args, out), jobs):
            results.append(r)
            bad = [n for n, g in r["graders"].items() if g["scored"] and not g["pass"]]
            print(f"{r['case']:34} {r['arm']:7} run {r['run']}  score {r['score']:.2f}"
                  f"  skill={'Skill' in r['tools']}{'  BLOCCATO' if r['blocked'] else ''}"
                  f"  falliti: {', '.join(bad) or '-'}", flush=True)
    (out / "results.json").write_text(json.dumps(results, indent=1, ensure_ascii=False), encoding="utf-8")

    print(f"\n{'CASO':34} " + " ".join(f"{a:>8}" for a in arms))
    ok = True
    for c in cases:
        row = []
        for a in arms:
            s = [r["score"] for r in results if r["case"] == c["name"] and r["arm"] == a]
            m = sum(s) / len(s)
            row.append(f"{m:8.2f}")
            ok &= not (a == "with" and m < 1.0)
        print(f"{c['name']:34} " + " ".join(row))
    if any(r["blocked"] for r in results):
        print("\nATTENZIONE: alcune esecuzioni sono state bloccate da un hook: risultati non validi.")
        ok = False
    print(f"\nCosto totale: ${sum(r['cost'] for r in results):.2f}  Risultati: {out}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
