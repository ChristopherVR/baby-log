"""Restore the Play upload key on CI without printing signing credentials."""
import base64
import os
from pathlib import Path


def main() -> None:
    names = (
        "PLAY_UPLOAD_KEYSTORE", "PLAY_UPLOAD_STORE_PASSWORD",
        "PLAY_UPLOAD_KEY_ALIAS", "PLAY_UPLOAD_KEY_PASSWORD",
    )
    missing = [name for name in names if not os.environ.get(name, "").strip()]
    if missing:
        raise SystemExit("Missing Play signing secrets: " + ", ".join(missing))
    key = Path(os.environ["RUNNER_TEMP"]) / "baby-log-play-signing" / "upload.jks"
    key.parent.mkdir(parents=True, exist_ok=True)
    key.write_bytes(base64.b64decode(os.environ["PLAY_UPLOAD_KEYSTORE"], validate=True))
    key.chmod(0o600)
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
        stream.write(f"PLAY_UPLOAD_KEYSTORE_PATH={key}\n")
    print("Play upload key restored")


if __name__ == "__main__":
    main()
