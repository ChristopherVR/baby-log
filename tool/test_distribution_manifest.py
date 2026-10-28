import unittest

from verify_distribution_manifest import PACKAGES, verify_manifest


GITHUB_PERMISSIONS = ("USE_EXACT_ALARM", "FOREGROUND_SERVICE_SPECIAL_USE")
PLAY_PERMISSIONS = ("FOREGROUND_SERVICE_SPECIAL_USE",)


def manifest(*, installer=False, provider=False, package=PACKAGES["play"], permissions=None):
    if permissions is None:
        permissions = GITHUB_PERMISSIONS if package == PACKAGES["github"] else PLAY_PERMISSIONS
    extra = "".join(f'<uses-permission android:name="android.permission.{name}"/>' for name in permissions)
    permission = '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>' if installer else ""
    component = '<provider android:authorities="com.babyapp.baby_app.updates"/>' if provider else ""
    return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{package}">
        {permission}{extra}<application>{component}</application></manifest>'''


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

    def test_play_rejects_restricted_permissions(self):
        for name in ("USE_EXACT_ALARM", "USE_FULL_SCREEN_INTENT", "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                verify_manifest(manifest(permissions=PLAY_PERMISSIONS + (name,)), "play")
        verify_manifest(manifest(permissions=PLAY_PERMISSIONS + ("SCHEDULE_EXACT_ALARM", "WAKE_LOCK")), "play")

    def test_play_requires_sync_service_permission(self):
        with self.assertRaises(ValueError):
            verify_manifest(manifest(permissions=()), "play")

    def test_github_requires_alarm_and_service_permissions(self):
        github = PACKAGES["github"]
        for permissions in ((), ("USE_EXACT_ALARM",), ("FOREGROUND_SERVICE_SPECIAL_USE",)):
            with self.subTest(permissions=permissions), self.assertRaises(ValueError):
                verify_manifest(manifest(installer=True, provider=True, package=github, permissions=permissions),
                                "github")

    def test_identity_changes_are_rejected(self):
        with self.assertRaises(ValueError):
            verify_manifest(manifest(package="com.other.app"), "play")
        with self.assertRaises(ValueError):
            verify_manifest(manifest(package=PACKAGES["play"], installer=True, provider=True), "github")


if __name__ == "__main__":
    unittest.main()
