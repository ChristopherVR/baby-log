import unittest

from verify_distribution_manifest import PACKAGES, verify_manifest


def manifest(*, installer=False, provider=False, package=PACKAGES["play"]):
    permission = '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>' if installer else ""
    component = '<provider android:authorities="com.babyapp.baby_app.updates"/>' if provider else ""
    return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package}">
        {permission}<application>{component}</application></manifest>'''


class DistributionManifestTest(unittest.TestCase):
    def test_play_rejects_installation_permission_or_provider(self):
        verify_manifest(manifest(), "play")
        for installer, provider in ((True, False), (False, True), (True, True)):
            with self.subTest(installer=installer, provider=provider), self.assertRaises(ValueError):
                verify_manifest(manifest(installer=installer, provider=provider), "play")

    def test_github_requires_both_installer_components(self):
        github = PACKAGES["github"]
        verify_manifest(manifest(installer=True, provider=True, package=github), "github")
        for installer, provider in ((False, False), (False, True), (True, False)):
            with self.subTest(installer=installer, provider=provider), self.assertRaises(ValueError):
                verify_manifest(manifest(installer=installer, provider=provider, package=github), "github")

    def test_identity_changes_are_rejected(self):
        with self.assertRaises(ValueError):
            verify_manifest(manifest(package="com.other.app"), "play")
        with self.assertRaises(ValueError):
            verify_manifest(manifest(package=PACKAGES["play"], installer=True, provider=True), "github")


if __name__ == "__main__":
    unittest.main()
