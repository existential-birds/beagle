#!/usr/bin/env python3
"""Repository survey artifacts. stdlib + git + gh; no semantic auto-review."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import fnmatch
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
from urllib.parse import quote


class SurveyError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise SurveyError(message)


def stamp():
    return datetime.now(timezone.utc).isoformat()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def save_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         delete=False) as stream:
            name = stream.name
            json.dump(value, stream, ensure_ascii=True, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if name and os.path.exists(name):
            os.unlink(name)


def command(argv, input_text=None):
    result = subprocess.run(argv, input=input_text, text=True, encoding="utf-8",
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if result.returncode:
        # Do not echo arbitrary remote response bodies or auth diagnostics into logs.
        raise SurveyError(f"{argv[0]} command failed (exit {result.returncode}); inspect safely, no automatic write retry")
    return result.stdout


def repo_name(value):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9-]+/[A-Za-z0-9_.-]+", value)
            and value.split("/")[1] not in {".", ".."}, "Expected exact OWNER/REPO for github.com")
    return value


def gh(endpoint, payload=None, paginate=False):
    args = ["gh", "api", "--hostname", "github.com", "--method",
            "POST" if payload is not None else "GET", endpoint]
    if paginate:
        args += ["--paginate", "--slurp"]
    if payload is not None:
        args += ["--input", "-"]
    data = json.loads(command(args, json.dumps(payload) if payload is not None else None))
    if paginate:
        require(isinstance(data, list) and all(isinstance(p, list) for p in data),
                "Unexpected paginated API shape; refusing partial snapshot")
        data = [item for page in data for item in page]
    return data


def list_issues(repo):
    items = gh(f"repos/{repo}/issues?state=all&per_page=100&sort=created&direction=asc", paginate=True)
    require(all(isinstance(i, dict) and isinstance(i.get("number"), int) for i in items),
            "Invalid issue listing")
    # Adjacent pages can overlap during concurrent updates; never inflate counts.
    return list({i["number"]: i for i in items}.values())


def snapshot(repo, ref=None):
    repo_name(repo)
    metadata = gh(f"repos/{repo}")
    require(metadata["full_name"].casefold() == repo.casefold(), "Repository identity mismatch")
    ref = ref or metadata["default_branch"]
    head = gh(f"repos/{repo}/commits/{quote(ref, safe='')}")["sha"]
    issues = list_issues(repo)
    labels = gh(f"repos/{repo}/labels?per_page=100", paginate=True)
    return {"version": 1, "repo": repo, "ref": ref, "sha": head, "captured_at": stamp(),
            "complete": True, "labels": sorted({v["name"] for v in labels}),
            "items": [{k: i[k] for k in ("number", "title", "body", "state", "html_url", "pull_request")
                       if k in i} for i in issues]}


SKIP_DIRS = {".git", ".venv", "venv", "node_modules", "vendor", "third_party", "dist", "build",
             "target", "coverage", ".next", ".cache", "__pycache__", "generated", "__generated__"}
TEXT_SUFFIXES = {".py", ".go", ".rs", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".java",
                 ".kt", ".kts", ".swift", ".m", ".mm", ".h", ".hpp", ".c", ".cpp", ".cs", ".rb",
                 ".ex", ".exs", ".erl", ".php", ".scala", ".sh", ".bash", ".ps1", ".sql", ".proto",
                 ".graphql", ".gql", ".vue", ".svelte", ".css", ".scss", ".html", ".md", ".rst",
                 ".txt", ".json", ".yaml", ".yml", ".toml", ".xml", ".ini", ".cfg", ".tf", ".dart"}
TEXT_NAMES = {"Dockerfile", "Makefile", "Gemfile", "Rakefile", "Justfile", "CMakeLists.txt"}


def excluded(path, mode, size, patterns):
    p = PurePosixPath(path)
    lower = p.name.lower()
    if (any(x.lower() in {".ssh", "secrets", "credentials"} for x in p.parts)
            or lower.startswith(".env") or lower in {"credentials.json", "auth.json", "id_rsa", "id_ed25519"}
            or p.suffix.lower() in {".pem", ".key", ".p12", ".pfx", ".keystore"}):
        return "sensitive-path"
    if mode not in {"100644", "100755"}:
        return "symlink-or-submodule"
    if any(x in SKIP_DIRS for x in p.parts):
        return "dependency-build-or-generated"
    if (lower.endswith((".min.js", ".min.css", ".pb.go", "_pb2.py", "_pb2_grpc.py", ".lock"))
            or lower in {"package-lock.json", "pnpm-lock.yaml", "yarn.lock"}):
        return "generated-or-lockfile"
    if any(fnmatch.fnmatchcase(path, pat) for pat in patterns):
        return "user-exclusion"
    if size > 2_000_000:
        return "large-file"
    if p.suffix.lower() not in TEXT_SUFFIXES and p.name not in TEXT_NAMES:
        return "non-source-or-unknown"
    return None


def inventory(root, ref="HEAD", patterns=()):
    root = str(Path(root).resolve())
    sha = command(["git", "-C", root, "rev-parse", "--verify", f"{ref}^{{commit}}"]).strip()
    raw = command(["git", "-C", root, "ls-tree", "-r", "-l", "-z", "--full-tree", sha])
    files, omissions, counts = [], [], Counter()
    for entry in raw.split("\0"):
        if not entry:
            continue
        meta, path = entry.split("\t", 1)
        mode, kind, oid, size = meta.split()
        size = int(size) if size != "-" else 0
        reason = excluded(path, mode, size, patterns)
        if reason:
            counts[reason] += 1
            if reason != "sensitive-path":
                omissions.append({"path": path, "reason": reason})
            continue
        parts = PurePosixPath(path).parts
        component = "/".join(parts[:2]) if len(parts) > 2 and parts[0] in {"apps", "packages", "services", "plugins", "crates"} else (parts[0] if len(parts) > 1 else "__root__")
        files.append({"path": path, "blob": oid, "bytes": size, "component": component})
    files.sort(key=lambda x: x["path"])
    return {"version": 1, "root": root, "sha": sha, "files": files, "excluded": omissions,
            "excluded_counts": dict(counts), "components": dict(Counter(f["component"] for f in files)),
            "note": "Tracked commit metadata only; no semantic coverage or source-content reads."}


def nonempty(value, name):
    require(isinstance(value, str) and bool(value.strip()), f"Missing text: {name}")


def strings(value, name, allow_empty=False):
    require(isinstance(value, list) and (allow_empty or bool(value)), f"Expected list: {name}")
    for item in value:
        nonempty(item, name)


def check_coverage(inv, coverage):
    require(coverage.get("sha") == inv["sha"], "Coverage SHA mismatch")
    universe = {f["path"] for f in inv["files"]}
    triaged, read = coverage.get("triaged", []), coverage.get("read", [])
    strings(triaged, "triaged", True)
    strings(read, "read", True)
    skipped = coverage.get("skipped", [])
    require(isinstance(skipped, list), "Expected skipped list")
    for item in skipped:
        nonempty(item.get("reason"), "skip reason")
        nonempty(item.get("path"), "skip path")
    skipped_paths = [i["path"] for i in skipped]
    require(len(set(triaged + skipped_paths)) == len(triaged + skipped_paths), "Duplicate/overlapping coverage ownership")
    require(set(triaged + skipped_paths) == universe, "Coverage missing paths or contains foreign paths")
    require(len(set(read)) == len(read) and set(read) <= set(triaged), "Read paths must be unique and triaged")
    nonempty(coverage.get("crosscut_review"), "crosscut_review")
    return {"included": len(universe), "triaged": len(triaged), "read": len(read), "skipped": len(skipped)}


def fingerprint(repo, key):
    return hashlib.sha256((repo.casefold() + "\n" + key).encode()).hexdigest()


def marker(repo, key):
    return f"<!-- refactor-repo:v1:{fingerprint(repo, key)} -->"


def bullets(items):
    return "\n".join("- " + v for v in items)


def render(repo, sha, candidate):
    c = candidate
    evidence = []
    for e in c["evidence"]:
        url = f"https://github.com/{repo}/blob/{sha}/{quote(e['path'], safe='/')}#L{e['start']}-L{e['end']}"
        evidence.append(f"{e['path']}:{e['start']}-{e['end']} ({e['symbol']}) — {e['note']} — {url}")
    sections = [marker(repo, c["id"]), f"## Problem\n{c['problem']}",
                f"## Why this change is worthwhile\n{c['change_cost']}",
                f"## Evidence at {sha}\n{bullets(evidence)}",
                "## Fowler diagnosis\n" + bullets(c["smells"]) + "\n" + bullets(
                    [f"{r['name']} — Refactoring, Second Edition, Chapter {r['chapter']}" for r in c["refactorings"]]),
                "## Proposed small-step sequence\n" + "\n".join(f"{i}. {s}" for i, s in enumerate(c["steps"], 1))]
    for title, key in [("Behavior and compatibility invariants", "invariants"), ("Validation plan", "tests"),
                       ("Acceptance criteria", "acceptance"), ("Non-goals", "non_goals"),
                       ("Risks and migration", "risks"), ("Alternatives, including no change", "alternatives")]:
        sections.append(f"## {title}\n{bullets(c[key])}")
    sections += [f"## Prioritization\nPriority: {c['priority']}; effort: {c['effort']}.\n{c['ranking_reason']}",
                 f"## Review and existing work\n{c['review']}\n{c['duplicate_check']['rationale']}",
                 f"## Validation performed during survey\n{c['validation']['status']}: {c['validation']['detail']}",
                 "Proposal only: implementation and completion of its acceptance criteria remain future work."]
    return "\n\n".join(sections) + "\n"


def prepare(inv, snap, plan, coverage, out):
    require(snap.get("complete") is True, "Incomplete GitHub snapshot")
    repo = repo_name(plan.get("repo"))
    require(repo == snap["repo"] and inv["sha"] == snap["sha"] == plan.get("sha"), "Repository/source SHA mismatch")
    summary = check_coverage(inv, coverage)
    candidates = plan.get("candidates")
    require(isinstance(candidates, list), "Expected candidates array (empty is valid)")
    paths = {f["path"] for f in inv["files"]}
    ids, drafts, decisions = set(), [], Counter()
    for c in candidates:
        key = c.get("id", "")
        require(isinstance(key, str) and re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", key), "Invalid stable candidate id")
        require(key != "manifest", "Reserved candidate id: manifest")
        require(key not in ids, "Duplicate candidate id")
        ids.add(key)
        decision = c.get("decision")
        require(decision in {"accepted", "rejected", "duplicate", "needs-evidence"}, "Invalid decision")
        decisions[decision] += 1
        if decision != "accepted":
            nonempty(c.get("reason"), "non-accepted decision reason")
            continue
        require(c.get("confidence") == "high", "Only high-confidence proposals may publish")
        for field in ("title", "problem", "change_cost", "ranking_reason", "review"):
            nonempty(c.get(field), field)
        require(len(c["title"]) <= 256, "Issue title too long")
        for field in ("smells", "steps", "invariants", "tests", "acceptance", "non_goals", "risks", "alternatives"):
            strings(c.get(field), field)
        for field in ("labels", "assignees"):
            strings(c.get(field), field, True)
            require(len(set(c[field])) == len(c[field]), f"Duplicate {field}")
        require(set(c["labels"]) <= set(snap["labels"]), "Unknown repository labels")
        require(c.get("priority") in {"high", "medium", "low"} and c.get("effort") in {"small", "medium", "large"}, "Invalid priority/effort")
        require(c.get("duplicate_check", {}).get("status") == "clear", "Semantic duplicate check not clear")
        nonempty(c["duplicate_check"].get("rationale"), "duplicate rationale")
        require(c.get("validation", {}).get("status") in {"not-run", "passed", "failed", "unavailable"}, "Invalid validation status")
        nonempty(c["validation"].get("detail"), "validation detail")
        require(isinstance(c.get("refactorings"), list) and c["refactorings"], "Missing Fowler moves")
        for r in c["refactorings"]:
            nonempty(r.get("name"), "refactoring name")
            require(type(r.get("chapter")) is int and 6 <= r["chapter"] <= 12, "Invalid catalog chapter")
        require(isinstance(c.get("evidence"), list) and c["evidence"], "Missing evidence")
        for e in c["evidence"]:
            require(e.get("path") in paths and e["path"] in coverage["read"], "Evidence must cite an included, deeply read path")
            require(type(e.get("start")) is int and type(e.get("end")) is int and 1 <= e["start"] <= e["end"], "Invalid evidence line range")
            nonempty(e.get("symbol"), "evidence symbol")
            nonempty(e.get("note"), "evidence note")
        token = marker(repo, key)
        duplicate = [i for i in snap["items"] if token in (i.get("body") or "") or i["title"].casefold() == c["title"].casefold()]
        require(not duplicate, f"Existing issue/PR for {key}; adjudicate before preparing")
        payload = {"title": c["title"], "body": render(repo, inv["sha"], c),
                   "labels": c["labels"], "assignees": c["assignees"]}
        drafts.append({"version": 1, "repo": repo, "ref": snap["ref"], "sha": inv["sha"], "id": key, "payload": payload})
    out = Path(out)
    require(not out.exists() or not any(out.iterdir()), "Draft directory must be new/empty; preserve old publication journals")
    out.mkdir(parents=True, exist_ok=True)
    for d in drafts:
        save_json(out / (d["id"] + ".json"), d)
        (out / (d["id"] + ".md")).write_text(d["payload"]["body"], encoding="utf-8")
    result = {"repo": repo, "sha": inv["sha"], "coverage": summary, "decisions": dict(decisions),
              "draft_ids": [d["id"] for d in drafts]}
    save_json(out / "manifest.json", result)
    return result


def verify_issue(repo, item, payload):
    number = item.get("number")
    require(type(number) is int and number > 0, "Invalid issue number in response")
    exact = gh(f"repos/{repo}/issues/{number}")
    require("pull_request" not in exact and exact.get("state") == "open", "Readback is not an open issue")
    require(exact.get("title") == payload["title"] and exact.get("body") == payload["body"], "Issue content readback mismatch")
    require({x["name"] for x in exact.get("labels", [])} == set(payload["labels"]), "Issue labels readback mismatch")
    require({x["login"] for x in exact.get("assignees", [])} == set(payload["assignees"]), "Issue assignees readback mismatch")
    url = exact.get("html_url")
    match = re.fullmatch(r"https://github\.com/([^/]+/[^/]+)/issues/([1-9][0-9]*)", url) if isinstance(url, str) else None
    require(match is not None and match[1].casefold() == repo.casefold() and match[2] == str(number), "Unexpected issue URL")
    return exact


def publish(draft_path, confirm_repo):
    path = Path(draft_path)
    d = read_json(path)
    repo = repo_name(d["repo"])
    require(repo == confirm_repo, "Publication target confirmation mismatch")
    payload = d["payload"]
    token = marker(repo, d["id"])
    require(payload["body"].startswith(token + "\n"), "Draft stable marker missing")
    journal = path.with_suffix(".journal.json")
    lock = path.parent / ".publish-lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise SurveyError("Another publisher or stale lock exists; investigate before retry")
    try:
        existing = [i for i in list_issues(repo) if token in (i.get("body") or "")]
        require(len(existing) <= 1, "Multiple stable-marker matches; manual reconciliation required")
        if existing:
            exact = verify_issue(repo, existing[0], payload)
            result = {"status": "verified-existing", "number": exact["number"], "url": exact["html_url"], "verified_at": stamp()}
            save_json(journal, result)
            return result
        require(not journal.exists(), "Journal exists but issue not found; ambiguous outcome, never automatically retry POST")
        current = gh(f"repos/{repo}/commits/{quote(d['ref'], safe='')}")["sha"]
        require(current == d["sha"], "Remote source changed; refresh evidence and proposals")
        labels = {x["name"] for x in gh(f"repos/{repo}/labels?per_page=100", paginate=True)}
        require(set(payload["labels"]) <= labels, "Labels changed or do not exist")
        for login in payload["assignees"]:
            require(re.fullmatch(r"[A-Za-z0-9-]+", login), "Invalid assignee login")
            # GitHub returns 204 with no JSON for a successful assignability check.
            command(["gh", "api", "--hostname", "github.com", "--method", "GET", f"repos/{repo}/assignees/{login}"])
        items = list_issues(repo)
        require(not any(token in (i.get("body") or "") or i["title"].casefold() == payload["title"].casefold() for i in items), "Duplicate appeared during preflight")
        save_json(journal, {"status": "pending", "repo": repo, "id": d["id"], "started_at": stamp()})
        created = gh(f"repos/{repo}/issues", payload=payload)
        save_json(journal, {"status": "created-unverified", "repo": repo, "id": d["id"], "number": created.get("number"), "started_at": stamp()})
        exact = verify_issue(repo, created, payload)
        result = {"status": "verified-created", "number": exact["number"], "url": exact["html_url"], "verified_at": stamp()}
        save_json(journal, result)
        return result
    finally:
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="action", required=True)
    p = subs.add_parser("inventory")
    p.add_argument("--root", required=True)
    p.add_argument("--ref", default="HEAD")
    p.add_argument("--exclude", action="append", default=[])
    p.add_argument("--out", required=True)
    p = subs.add_parser("snapshot")
    p.add_argument("--repo", required=True)
    p.add_argument("--ref")
    p.add_argument("--out", required=True)
    p = subs.add_parser("prepare")
    for flag in ("inventory", "snapshot", "proposals", "coverage", "out"):
        p.add_argument("--" + flag, required=True)
    p = subs.add_parser("publish")
    p.add_argument("--draft", required=True)
    p.add_argument("--confirm-repo", required=True)
    args = parser.parse_args()
    if args.action == "inventory":
        data = inventory(args.root, args.ref, args.exclude)
        save_json(args.out, data)
        result = {"sha": data["sha"], "included": len(data["files"]), "excluded_counts": data["excluded_counts"], "components": data["components"]}
    elif args.action == "snapshot":
        data = snapshot(args.repo, args.ref)
        save_json(args.out, data)
        result = {"repo": data["repo"], "sha": data["sha"], "items": len(data["items"]), "labels": len(data["labels"])}
    elif args.action == "prepare":
        result = prepare(read_json(args.inventory), read_json(args.snapshot), read_json(args.proposals), read_json(args.coverage), args.out)
    else:
        result = publish(args.draft, args.confirm_repo)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (SurveyError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
