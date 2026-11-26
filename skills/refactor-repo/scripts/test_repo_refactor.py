#!/usr/bin/env python3
"""Hermetic tests: temporary Git fixtures and mocked GitHub, never live API calls."""
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_refactor as rr


class SurveyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.sha = "a" * 40
        self.inv = {"sha": self.sha, "files": [{"path": "src/a.py", "blob": "b" * 40, "bytes": 40}]}
        self.snap = {"complete": True, "repo": "example/repo", "ref": "main", "sha": self.sha,
                     "labels": ["refactoring"], "items": []}
        self.coverage = {"sha": self.sha, "triaged": ["src/a.py"], "read": ["src/a.py"],
                         "skipped": [], "crosscut_review": "Synthetic fixture: no cross-package consumers."}
        self.c = {"id": "billing-shared-pricing", "title": "Extract shared pricing policy", "decision": "accepted",
                  "confidence": "high", "problem": "Synthetic duplicate policy in fixture.",
                  "change_cost": "Two fixture callers require coordinated edits.",
                  "ranking_reason": "Recurring fixture change with local scope.",
                  "review": "Synthetic reviewer checked both fixture callers and their intentional differences.",
                  "smells": ["Duplicated Code"], "refactorings": [{"name": "Extract Function", "chapter": 6}],
                  "steps": ["Characterize both callers.", "Extract shared policy; verify each caller."],
                  "invariants": ["Results and errors stay unchanged."], "tests": ["Compare both caller outputs."],
                  "acceptance": ["One policy implementation, both callers tested."], "non_goals": ["No pricing change."],
                  "risks": ["Preserve rounding order."], "alternatives": ["Retain duplication if policies diverge."],
                  "labels": ["refactoring"], "assignees": [], "priority": "medium", "effort": "small",
                  "duplicate_check": {"status": "clear", "rationale": "Synthetic empty backlog inspected."},
                  "validation": {"status": "not-run", "detail": "Proposal-only fixture, not production results."},
                  "evidence": [{"path": "src/a.py", "start": 1, "end": 2, "symbol": "price", "note": "Synthetic repeated formula."}]}
        self.plan = {"repo": "example/repo", "sha": self.sha, "candidates": [self.c]}

    def prepare(self):
        return rr.prepare(self.inv, self.snap, self.plan, self.coverage, self.root / "drafts")

    def draft(self):
        self.prepare()
        return self.root / "drafts" / (self.c["id"] + ".json")

    def issue(self, path):
        payload = rr.read_json(path)["payload"]
        return {"number": 42, "state": "open", "title": payload["title"], "body": payload["body"],
                "labels": [{"name": x} for x in payload["labels"]],
                "assignees": [{"login": x} for x in payload["assignees"]],
                "html_url": "https://github.com/example/repo/issues/42"}

    def fake_api(self, path, existing=False, fail_post=False, bad_readback=False, stale=False):
        state = {"posts": 0, "exists": existing}
        issue = self.issue(path)
        def api(endpoint, payload=None, paginate=False):
            if payload is not None:
                state["posts"] += 1
                state["exists"] = True
                if fail_post:
                    raise rr.SurveyError("Simulated transport loss after creation")
                return deepcopy(issue)
            if "/issues?" in endpoint:
                return [deepcopy(issue)] if state["exists"] else []
            if endpoint.endswith("/issues/42"):
                result = deepcopy(issue)
                if bad_readback:
                    result["labels"] = []
                return result
            if "/commits/" in endpoint:
                return {"sha": "c" * 40 if stale else self.sha}
            if "/labels?" in endpoint:
                return [{"name": "refactoring"}]
            raise AssertionError("Unexpected mock endpoint: " + endpoint)
        return state, api

    def test_prepare_writes_payload_and_markdown(self):
        result = self.prepare()
        path = self.root / "drafts" / (self.c["id"] + ".json")
        data = rr.read_json(path)
        self.assertEqual(result["draft_ids"], [self.c["id"]])
        self.assertEqual(result["coverage"]["read"], 1)
        self.assertIn(self.sha + "/src/a.py#L1-L2", data["payload"]["body"])
        self.assertIn("not-run", data["payload"]["body"])
        self.assertEqual(path.with_suffix(".md").read_text(), data["payload"]["body"])

    def test_empty_candidates_valid(self):
        self.plan["candidates"] = []
        self.assertEqual(self.prepare()["draft_ids"], [])

    def test_rejected_candidates_need_no_full_proposal(self):
        self.plan["candidates"] = [{"id": "intentional-boundary", "decision": "rejected", "reason": "Boundary is deliberate."}]
        self.assertEqual(self.prepare()["decisions"], {"rejected": 1})

    def test_rejected_reason_required(self):
        self.plan["candidates"] = [{"id": "candidate", "decision": "rejected"}]
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_missing_coverage_blocks(self):
        self.coverage["triaged"] = []
        self.coverage["read"] = []
        with self.assertRaisesRegex(rr.SurveyError, "Coverage missing"):
            self.prepare()

    def test_overlapping_coverage_blocks(self):
        self.coverage["skipped"] = [{"path": "src/a.py", "reason": "Would duplicate coverage."}]
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_unread_evidence_blocks(self):
        self.coverage["read"] = []
        with self.assertRaisesRegex(rr.SurveyError, "deeply read"):
            self.prepare()

    def test_unknown_path_blocks(self):
        self.c["evidence"][0]["path"] = "src/imaginary.py"
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_stale_sha_blocks_prepare(self):
        self.snap["sha"] = "c" * 40
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_incomplete_snapshot_blocks(self):
        self.snap["complete"] = False
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_unknown_labels_block(self):
        self.c["labels"] = ["invented"]
        with self.assertRaisesRegex(rr.SurveyError, "Unknown"):
            self.prepare()

    def test_low_confidence_blocks(self):
        self.c["confidence"] = "medium"
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_semantic_duplicate_not_clear_blocks(self):
        self.c["duplicate_check"]["status"] = "uncertain"
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_duplicate_candidate_ids_block(self):
        self.plan["candidates"].append(deepcopy(self.c))
        with self.assertRaisesRegex(rr.SurveyError, "Duplicate candidate"):
            self.prepare()
        self.assertFalse((self.root / "drafts").exists())

    def test_closed_and_pr_duplicates_block(self):
        for extra in ({"state": "closed"}, {"state": "open", "pull_request": {}}):
            with self.subTest(extra=extra):
                self.snap["items"] = [{"title": self.c["title"], "body": "", **extra}]
                with self.assertRaises(rr.SurveyError):
                    self.prepare()

    def test_existing_marker_blocks_despite_renamed_title(self):
        self.snap["items"] = [{"title": "Another title", "body": rr.marker("example/repo", self.c["id"])}]
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_id_rejects_traversal(self):
        self.c["id"] = "../escape"
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_manifest_id_is_reserved_before_any_write(self):
        self.c["id"] = "manifest"
        with self.assertRaisesRegex(rr.SurveyError, "Reserved"):
            self.prepare()
        self.assertFalse((self.root / "drafts").exists())

    def test_readback_accepts_canonical_repository_casing(self):
        path = self.draft()
        issue = self.issue(path)
        issue["html_url"] = "https://github.com/Example/Repo/issues/42"
        with patch.object(rr, "gh", return_value=issue):
            verified = rr.verify_issue("example/repo", issue, rr.read_json(path)["payload"])
        self.assertEqual(verified["html_url"], issue["html_url"])

    def test_readback_url_keeps_exact_host_target_and_number(self):
        path = self.draft()
        issue = self.issue(path)
        for url in ["http://github.com/example/repo/issues/42",
                    "https://other.test/example/repo/issues/42",
                    "https://github.com/example/other/issues/42",
                    "https://github.com/example/repo/issues/43",
                    "https://github.com/example/repo/issues/42?unexpected=1",
                    "https://github.com/example/repo/issues/42/", None]:
            with self.subTest(url=url):
                issue["html_url"] = url
                with patch.object(rr, "gh", return_value=issue):
                    with self.assertRaisesRegex(rr.SurveyError, "Unexpected issue URL"):
                        rr.verify_issue("example/repo", issue, rr.read_json(path)["payload"])

    def test_invalid_line_range_blocks(self):
        self.c["evidence"][0]["start"] = 0
        with self.assertRaises(rr.SurveyError):
            self.prepare()

    def test_existing_output_is_not_overwritten(self):
        self.prepare()
        with self.assertRaisesRegex(rr.SurveyError, "new/empty"):
            self.prepare()

    def test_github_pagination_flattens_all_pages(self):
        with patch.object(rr, "command", return_value='[[{"number":1}],[{"number":2}]]') as cmd:
            values = rr.gh("endpoint", paginate=True)
        self.assertEqual([v["number"] for v in values], [1, 2])
        self.assertIn("--paginate", cmd.call_args.args[0])
        self.assertIn("--slurp", cmd.call_args.args[0])

    def test_bad_pagination_shape_fails(self):
        with patch.object(rr, "command", return_value='{"message":"error"}'):
            with self.assertRaises(rr.SurveyError):
                rr.gh("endpoint", paginate=True)

    def test_overlapping_api_pages_deduplicate(self):
        with patch.object(rr, "gh", return_value=[{"number": 1}, {"number": 1}, {"number": 2}]):
            self.assertEqual(len(rr.list_issues("example/repo")), 2)

    def test_publish_verifies_and_is_idempotent(self):
        path = self.draft()
        state, api = self.fake_api(path)
        with patch.object(rr, "gh", side_effect=api):
            first = rr.publish(path, "example/repo")
            second = rr.publish(path, "example/repo")
        self.assertEqual(first["status"], "verified-created")
        self.assertEqual(second["status"], "verified-existing")
        self.assertEqual(state["posts"], 1)

    def test_wrong_target_never_calls_api(self):
        path = self.draft()
        with patch.object(rr, "gh") as api:
            with self.assertRaises(rr.SurveyError):
                rr.publish(path, "other/repo")
        api.assert_not_called()

    def test_changed_remote_head_blocks_publication(self):
        path = self.draft()
        state, api = self.fake_api(path, stale=True)
        with patch.object(rr, "gh", side_effect=api):
            with self.assertRaisesRegex(rr.SurveyError, "Remote source changed"):
                rr.publish(path, "example/repo")
        self.assertEqual(state["posts"], 0)

    def test_readback_mismatch_is_unverified(self):
        path = self.draft()
        state, api = self.fake_api(path, bad_readback=True)
        with patch.object(rr, "gh", side_effect=api):
            with self.assertRaisesRegex(rr.SurveyError, "labels readback"):
                rr.publish(path, "example/repo")
        self.assertEqual(state["posts"], 1)
        self.assertEqual(rr.read_json(path.with_suffix(".journal.json"))["status"], "created-unverified")

    def test_ambiguous_post_recovers_by_read_not_second_post(self):
        path = self.draft()
        state, api = self.fake_api(path, fail_post=True)
        with patch.object(rr, "gh", side_effect=api):
            with self.assertRaises(rr.SurveyError):
                rr.publish(path, "example/repo")
            result = rr.publish(path, "example/repo")
        self.assertEqual(state["posts"], 1)
        self.assertEqual(result["status"], "verified-existing")

    def test_pending_without_remote_match_does_not_retry(self):
        path = self.draft()
        rr.save_json(path.with_suffix(".journal.json"), {"status": "pending"})
        state, api = self.fake_api(path)
        with patch.object(rr, "gh", side_effect=api):
            with self.assertRaisesRegex(rr.SurveyError, "ambiguous outcome"):
                rr.publish(path, "example/repo")
        self.assertEqual(state["posts"], 0)

    def test_publisher_lock_prevents_second_writer(self):
        path = self.draft()
        (path.parent / ".publish-lock").mkdir()
        with patch.object(rr, "gh") as api:
            with self.assertRaisesRegex(rr.SurveyError, "lock"):
                rr.publish(path, "example/repo")
        api.assert_not_called()

    def test_inventory_uses_committed_metadata_and_excludes_sensitive_paths(self):
        repo = self.root / "fixture-repo"
        repo.mkdir()
        def git(*args):
            return subprocess.run(["git", "-C", str(repo), *args], check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout
        git("init", "-q")
        for name in ["src/a b.py", "src/line\nbreak.py", ".env", "secrets/private.json", "node_modules/lib.js", "gen/a.pb.go", "docs/book.pdf", "README.md"]:
            p = repo / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("synthetic fixture only\n")
        git("add", "--all")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")
        (repo / "src/a b.py").write_text("uncommitted data must not affect blob size\n")
        inv = rr.inventory(repo)
        names = {f["path"] for f in inv["files"]}
        self.assertEqual(names, {"src/a b.py", "src/line\nbreak.py", "README.md"})
        self.assertEqual(inv["excluded_counts"]["sensitive-path"], 2)
        self.assertNotIn("private.json", json.dumps(inv))
        self.assertEqual(next(f["bytes"] for f in inv["files"] if f["path"] == "src/a b.py"), len("synthetic fixture only\n"))

    def test_exclusion_overrides(self):
        self.assertEqual(rr.excluded("src/a.py", "100644", 10, ["src/*"]), "user-exclusion")
        self.assertEqual(rr.excluded("src/a.py", "120000", 10, []), "symlink-or-submodule")
        self.assertEqual(rr.excluded("src/a.py", "100644", 2_000_001, []), "large-file")


if __name__ == "__main__":
    unittest.main(verbosity=2)
