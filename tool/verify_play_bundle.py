"""Verify that a Play bundle is signed by the configured non-debug upload key."""
import argparse
import base64
import hashlib
import os
import re
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    # Passwords are read by keytool from the environment, never command arguments.
    certificate = subprocess.check_output([
        "keytool", "-exportcert", "-keystore", os.environ["PLAY_UPLOAD_KEYSTORE_PATH"],
        "-storepass:env", "PLAY_UPLOAD_STORE_PASSWORD",
        "-alias", os.environ["PLAY_UPLOAD_KEY_ALIAS"],
    ])
    info = subprocess.check_output([
        "keytool", "-J-Duser.language=en", "-list", "-v",
        "-keystore", os.environ["PLAY_UPLOAD_KEYSTORE_PATH"],
        "-storepass:env", "PLAY_UPLOAD_STORE_PASSWORD",
        "-alias", os.environ["PLAY_UPLOAD_KEY_ALIAS"],
    ], text=True)
    if "CN=Android Debug" in info:
        raise SystemExit("Play bundles must not use an Android debug certificate")
    verified = subprocess.check_output([
        "jarsigner", "-J-Duser.language=en", "-verify", "-verbose", str(args.bundle),
    ], text=True)
    if "jar verified." not in verified or "unsigned entries" in verified:
        raise SystemExit("AAB signature verification failed or bundle contains unsigned entries")
    signed = subprocess.check_output([
        "keytool", "-printcert", "-rfc", "-jarfile", str(args.bundle),
    ], text=True)
    certificates = re.findall(
        r"-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----", signed, re.DOTALL,
    )
    if not certificates or base64.b64decode(certificates[0]) != certificate:
        raise SystemExit("AAB signing certificate does not match the configured upload key")
    print("Play bundle signature verified: " + hashlib.sha256(certificate).hexdigest())


if __name__ == "__main__":
    main()
