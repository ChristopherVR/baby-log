"""Check the merged manifest rather than only the flavor source manifests."""
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"
# GitHub keeps the original ID so sideloaded installs update in place.
PACKAGES = {"github": "com.babyapp.baby_app", "play": "io.github.christophervr.nestling"}


PLAY_FORBIDDEN = (
    "USE_EXACT_ALARM",
    "USE_FULL_SCREEN_INTENT",
    "FOREGROUND_SERVICE_SPECIAL_USE",
    "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
)
GITHUB_REQUIRED = ("USE_EXACT_ALARM", "FOREGROUND_SERVICE_SPECIAL_USE")


def verify_manifest(source: str, flavor: str) -> None:
    root = ET.fromstring(source)
    if root.get("package") != PACKAGES[flavor]:
        raise ValueError(f"{flavor} must use the application ID {PACKAGES[flavor]}")
    permissions = {item.get(ANDROID + "name") for item in root.findall("uses-permission")}
    installer = "android.permission.REQUEST_INSTALL_PACKAGES" in permissions
    providers = root.findall("application/provider")
    update_provider = any(item.get(ANDROID + "authorities") == "com.babyapp.baby_app.updates" for item in providers)
    expected = flavor == "github"
    if installer != expected or update_provider != expected:
        raise ValueError(f"Unexpected installer permission/provider in {flavor} manifest")
    names = {name.rsplit(".", 1)[-1] for name in permissions if name}
    if flavor == "play":
        found = [name for name in PLAY_FORBIDDEN if name in names]
        if found:
            raise ValueError(f"Play manifest must not declare {', '.join(found)}")
    else:
        missing = [name for name in GITHUB_REQUIRED if name not in names]
        if missing:
            raise ValueError(f"GitHub manifest must declare {', '.join(missing)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("flavor", choices=["github", "play"])
    args = parser.parse_args()
    paths = list(Path("build/app/intermediates/merged_manifests").glob(
        f"{args.flavor}Release/**/AndroidManifest.xml"))
    if not paths:
        raise SystemExit("Merged release manifest not found")
    for path in paths:
        verify_manifest(path.read_text(encoding="utf-8"), args.flavor)
    print(f"{args.flavor} merged manifest verified")


if __name__ == "__main__":
    main()
