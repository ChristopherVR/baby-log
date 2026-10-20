"""Fail before publishing if Android ignored the configured signing key."""
import hashlib
import os
import re
import subprocess
from pathlib import Path


def main() -> None:
    key = os.environ["ANDROID_KEYSTORE_PATH"]
    certificate = subprocess.check_output([
        "keytool", "-exportcert", "-keystore", key,
        "-storepass", "android", "-alias", "androiddebugkey",
    ])
    expected = hashlib.sha256(certificate).hexdigest()
    sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
    name = "apksigner.bat" if os.name == "nt" else "apksigner"
    candidates = [p for p in (sdk / "build-tools").glob(f"*/{name}") if p.is_file()]
    if not candidates:
        raise SystemExit("Android apksigner is required to verify release signing")
    signer = max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name)))
    result = subprocess.check_output([
        str(signer), "verify", "--print-certs",
        "build/app/outputs/flutter-apk/app-github-release.apk",
    ], text=True)
    actual = re.findall(r"certificate SHA-256 digest:\s*([0-9a-fA-F]+)", result)
    if actual != [expected]:
        raise SystemExit("APK signing certificate does not match the configured key; release blocked")
    print(f"APK signing certificate verified: {expected}")


if __name__ == "__main__":
    main()
