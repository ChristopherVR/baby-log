"""Check the merged manifest rather than only the flavor source manifests."""
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"


def verify_manifest(source: str, flavor: str) -> None:
    root = ET.fromstring(source)
    if root.get("package") != "com.babyapp.baby_app":
        raise ValueError("Distribution must preserve the existing application ID")
    permissions = {item.get(ANDROID + "name") for item in root.findall("uses-permission")}
    installer = "android.permission.REQUEST_INSTALL_PACKAGES" in permissions
    providers = root.findall("application/provider")
    update_provider = any(item.get(ANDROID + "authorities") == "com.babyapp.baby_app.updates" for item in providers)
    expected = flavor == "github"
    if installer != expected or update_provider != expected:
        raise ValueError(f"Unexpected installer permission/provider in {flavor} manifest")


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
