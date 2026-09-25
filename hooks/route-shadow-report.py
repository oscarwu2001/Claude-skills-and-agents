#!/usr/bin/env python3
"""Compare the shadow router's decisions with the routes the main model took.

Reads <.claude>/route-shadow/log.jsonl written by route-shadow.sh. For each
prompt: the shadow mode + confidence, and the first skill/agent the main model
invoked before the next prompt ("direct" if none). A shadow mode counts as
agreeing when any route taken for that prompt maps to it (docs work that
searches with Explore first still agrees with "docs"). Prints agreement by
confidence band, so you can see whether "act when confidence >= T" would have
been right, and lists the disagreements worth reading.

    python3 ~/.claude/hooks/route-shadow-report.py [--days N] [--threshold 0.85]
"""
import argparse, collections, datetime as dt, json, pathlib, sys

# First route taken -> work mode. Names not listed count as "other".
ROUTE_MODE = {
    "research": "research", "researcher": "research",
    "deep-research": "deep-research", "anthropic-skills:deep-research": "deep-research",
    "Explore": "codebase-analysis", "graphify": "codebase-analysis",
    "system-map": "codebase-analysis", "archify": "codebase-analysis",
    "runner": "data-analysis",
    "code-review": "review", "reviewer": "review", "silent-failure-hunter": "review",
    "ui-reviewer": "review", "security-review": "review",
    "documenting": "docs",
    "grill-with-docs": "planning", "grill-me": "planning", "grilling": "planning",
    "to-spec": "planning", "to-tickets": "planning", "wayfinder": "planning",
    "prototype": "planning", "Plan": "planning", "triage": "planning",
    "implement": "coding", "tdd": "coding",
    "diagnosing-bugs": "bug",
    "task-observer": "skill-meta", "writing-great-skills": "skill-meta",
    "anthropic-skills:skill-creator": "skill-meta", "ask-matt": "skill-meta",
}
BANDS = [(0.95, 1.01), (0.85, 0.95), (0.7, 0.85), (0.0, 0.7)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=14)
    ap.add_argument("--threshold", type=float, default=0.85)
    ap.add_argument("--log", default=str(pathlib.Path(__file__).resolve().parent.parent / "route-shadow" / "log.jsonl"))
    a = ap.parse_args()

    path = pathlib.Path(a.log)
    if not path.exists():
        sys.exit(f"No log at {path}. Is the route-shadow hook installed?")
    since = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=a.days)

    prompts, shadow, routes, bad = [], {}, collections.defaultdict(list), 0
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            e = json.loads(line)
            t = dt.datetime.fromisoformat(e["ts"].replace("Z", "+00:00"))
        except (ValueError, KeyError):
            bad += 1
            continue
        if t < since:
            continue
        e["_t"] = t
        if e["event"] == "prompt":
            prompts.append(e)
        elif e["event"] == "shadow":
            shadow[e["pid"]] = e
        elif e["event"] == "route":
            routes[e["session"]].append(e)

    rows = []
    for i, p in enumerate(prompts):
        nxt = next((q["_t"] for q in prompts[i + 1:] if q["session"] == p["session"]), None)
        taken = [r for r in routes[p["session"]] if r["_t"] >= p["_t"] and (nxt is None or r["_t"] < nxt)]
        s = shadow.get(p["pid"])
        if not s:
            continue  # classifier still running, timed out, or failed to write
        d = s.get("decision") or {}
        modes = [ROUTE_MODE.get(r["name"], "other") for r in taken]
        actual = modes[0] if modes else "direct"
        mode = d.get("mode", "error")
        rows.append({"t": p["_t"], "mode": mode, "conf": float(d.get("confidence") or 0),
                     "actual": actual, "agree": mode in modes, "first": taken[0]["name"] if taken else "-",
                     "cost": float(s.get("cost_usd") or 0)})

    n = len(rows)
    print(f"{n} classified prompts in the last {a.days:g} days  ({len(prompts)} logged, {bad} unreadable lines)")
    if not n:
        return
    errors = sum(r["mode"] == "error" for r in rows)
    print(f"Classifier cost: ${sum(r['cost'] for r in rows):.3f} total, {errors} failed calls\n")

    routed = [r for r in rows if r["actual"] not in ("direct", "other") and r["mode"] != "error"]
    print("Agreement where the main model used a skill or agent")
    print(f"  {'confidence':<12}{'prompts':>8}{'agree':>8}")
    for lo, hi in BANDS:
        b = [r for r in routed if lo <= r["conf"] < hi]
        if b:
            ok = sum(r["agree"] for r in b)
            print(f"  {lo:.2f}-{min(hi, 1):.2f}   {len(b):>8}{ok / len(b):>8.0%}")
    gated = [r for r in routed if r["conf"] >= a.threshold]
    if gated:
        ok = sum(r["agree"] for r in gated)
        print(f"\nAt threshold {a.threshold}: would act on {len(gated)}/{len(routed)} routed prompts, "
              f"agreeing with the main model {ok / len(gated):.0%} of the time.")

    direct = [r for r in rows if r["actual"] == "direct" and r["mode"] not in ("chat", "error")]
    print(f"\nMain model worked directly, shadow suggested a mode ({len(direct)}):")
    for m, c in collections.Counter(r["mode"] for r in direct if r["conf"] >= a.threshold).most_common():
        print(f"  {m:<18}{c:>4}  (confidence >= {a.threshold}) -- candidates for a missed skill")

    dis = [r for r in routed if not r["agree"] and r["conf"] >= a.threshold]
    if dis:
        print(f"\nConfident disagreements ({len(dis)}) -- read these first:")
        for r in dis[-15:]:
            print(f"  {r['t']:%m-%d %H:%M}  shadow={r['mode']} ({r['conf']:.2f})  main={r['actual']} via {r['first']}")


if __name__ == "__main__":
    main()
