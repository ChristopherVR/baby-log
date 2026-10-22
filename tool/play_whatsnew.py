"""Turn a release's notes into Google Play's "What's new" text (500 characters at most)."""
import argparse
from pathlib import Path

LIMIT = 500
LANGUAGE = "en-GB"


def whats_new(notes: str) -> str:
    lines = [line.rstrip() for line in notes.strip().splitlines() if line.strip()]
    text = ""
    for line in lines:
        candidate = f"{text}\n{line}" if text else line
        # Leave room for the ellipsis line that says more changes were left out.
        if len(candidate) > LIMIT - 2:
            return f"{text}\n…" if text else line[: LIMIT - 1] + "…"
        text = candidate
    if not text:
        raise ValueError("Release notes must not be empty")
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("notes", type=Path)
    parser.add_argument("out_dir", type=Path)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    text = whats_new(args.notes.read_text(encoding="utf-8"))
    (args.out_dir / f"whatsnew-{LANGUAGE}").write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
