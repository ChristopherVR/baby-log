"""Version each main push without committing generated changes back to main."""
import argparse
import re
from pathlib import Path

VERSION = re.compile(r"^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$", re.MULTILINE)


def release_version(source: str, run_number: int) -> tuple[str, dict[str, str]]:
    match = VERSION.search(source)
    if match is None:
        raise ValueError("pubspec.yaml must contain version: major.minor.patch+build")
    if run_number < 1:
        raise ValueError("run number must be positive")
    major, minor, patch, baseline_build = map(int, match.groups())
    # GitHub run numbers increase for each push; retries keep the same number.
    # Failed runs may leave gaps. Versions never depend on which build finishes first.
    version = f"{major}.{minor}.{patch + run_number - 1}"
    build = baseline_build + run_number
    if build > 2100000000:
        raise ValueError("Android version code exceeds the supported maximum")
    updated = source[:match.start()] + f"version: {version}+{build}" + source[match.end():]
    return updated, {"version": version, "build": str(build), "tag": f"v{version}"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--run-number", type=int, required=True)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    updated, metadata = release_version(args.pubspec.read_text(encoding="utf-8"), args.run_number)
    args.pubspec.write_text(updated, encoding="utf-8")
    output = "".join(f"{key}={value}\n" for key, value in metadata.items())
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as stream:
            stream.write(output)
    print(output, end="")


if __name__ == "__main__":
    main()
