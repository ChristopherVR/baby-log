"""Bundle the same git-cliff notes into the APK and the GitHub release."""
import argparse
import json
import re
import subprocess
from pathlib import Path


def previous_published_tag(pages: list, version: str) -> str:
    current = tuple(map(int, version.split(".")))
    candidates = []
    for page in pages:
        for release in page:
            tag = release.get("tag_name", "")
            if release.get("draft") is not False or release.get("prerelease") is not False:
                continue
            if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
                continue
            numbers = tuple(map(int, tag[1:].split(".")))
            if numbers < current:
                candidates.append((numbers, tag))
    return max(candidates)[1] if candidates else ""


def generate_notes(version: str, previous_tag: str = "") -> str:
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a stable release version")
    command = ["git-cliff", "--config", "cliff.toml", "--ignore-tags", ".*", "--strip", "all"]
    if previous_tag:
        if not re.fullmatch(r"v\d+\.\d+\.\d+", previous_tag):
            raise ValueError("Expected a stable previous release tag")
        # Validate the tag before invoking cliff. Draft/cancelled tags inside
        # this range are ignored, so their changes join the next release.
        subprocess.run(["git", "merge-base", "--is-ancestor", previous_tag, "HEAD"], check=True)
        command.append(f"{previous_tag}..HEAD")
    notes = subprocess.check_output(command, text=True, encoding="utf-8").strip()
    if not notes:
        raise ValueError("Release notes must not be empty")
    return notes


def bundle_notes(version: str, notes: str, asset: Path, release_file: Path) -> None:
    asset.parent.mkdir(parents=True, exist_ok=True)
    asset.write_text(json.dumps({"version": version, "notes": notes}, ensure_ascii=False) + "\n", encoding="utf-8")
    release_file.write_text(notes + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    previous = parser.add_mutually_exclusive_group()
    previous.add_argument("--previous-tag", default="")
    previous.add_argument("--releases-json", type=Path)
    args = parser.parse_args()
    tag = args.previous_tag
    if args.releases_json:
        tag = previous_published_tag(json.loads(args.releases_json.read_text(encoding="utf-8")), args.version)
    notes = generate_notes(args.version, tag)
    bundle_notes(args.version, notes, Path("assets/release_notes.json"), Path("RELEASE_NOTES.md"))


if __name__ == "__main__":
    main()
