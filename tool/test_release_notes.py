import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from release_notes import bundle_notes, generate_notes, previous_published_tag


class ReleaseNotesTest(unittest.TestCase):
    def test_previous_release_ignores_drafts_prereleases_and_current_or_newer_versions(self):
        def release(tag, **extra):
            return {"tag_name": tag, "draft": False, "prerelease": False, **extra}
        pages = [[release("v1.4.10"), release("v1.4.9"), release("v1.4.8", draft=True)],
                 [release("v1.4.7", prerelease=True), release("v1.4.6"), release("v1.4.5")]]
        self.assertEqual(previous_published_tag(pages, "1.4.9"), "v1.4.6")
        self.assertEqual(previous_published_tag(pages, "1.4.0"), "")

    @patch("release_notes.subprocess.run")
    @patch("release_notes.subprocess.check_output", return_value="Changes\n- Improve editing\n")
    def test_collects_every_commit_since_published_tag_ignoring_intermediate_tags(self, output, run):
        self.assertEqual(generate_notes("1.4.9", "v1.4.5"), "Changes\n- Improve editing")
        self.assertEqual(output.call_args.args[0], [
            "git-cliff", "--config", "cliff.toml", "--ignore-tags", ".*", "--strip", "all", "v1.4.5..HEAD",
        ])
        run.assert_called_once_with(["git", "merge-base", "--is-ancestor", "v1.4.5", "HEAD"], check=True)

    @patch("release_notes.subprocess.check_output", return_value="Changes\n- First release")
    def test_first_release_uses_full_history(self, output):
        generate_notes("1.4.0")
        self.assertNotIn("..HEAD", " ".join(output.call_args.args[0]))

    def test_bundle_preserves_exact_unicode_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            asset = Path(directory) / "assets" / "release_notes.json"
            release = Path(directory) / "RELEASE_NOTES.md"
            notes = "Changes\n- Improve baby’s feed editing"
            bundle_notes("1.4.9", notes, asset, release)
            payload = json.loads(asset.read_text(encoding="utf-8"))
            self.assertEqual(payload, {"version": "1.4.9", "notes": notes})
            self.assertEqual(release.read_text(encoding="utf-8").strip(), payload["notes"])

    @patch("release_notes.subprocess.check_output", return_value="\n")
    def test_empty_notes_and_invalid_versions_fail(self, output):
        for version, tag in [("bad", ""), ("1.4.9", "--bad"), ("1.4.9", "")]:
            with self.assertRaises(ValueError):
                generate_notes(version, tag)


if __name__ == "__main__":
    unittest.main()
