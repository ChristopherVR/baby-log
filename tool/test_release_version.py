import unittest

from release_version import release_version


class ReleaseVersionTest(unittest.TestCase):
    def test_each_push_increments_version_and_android_build(self):
        source = "name: baby_app\nversion: 1.4.0+7\n\nenvironment:\n  sdk: ^3.13.5\n"
        first, metadata = release_version(source, 1)
        second, next_metadata = release_version(source, 2)
        self.assertIn("version: 1.4.0+8", first)
        self.assertIn("version: 1.4.1+9", second)
        self.assertIn("\nenvironment:\n", first)
        self.assertEqual(metadata, {"version": "1.4.0", "build": "8", "tag": "v1.4.0"})
        self.assertEqual(next_metadata["tag"], "v1.4.1")
        self.assertEqual(release_version(source, 2), (second, next_metadata))

    def test_invalid_version_or_run_fails_instead_of_reusing_a_version(self):
        for source, run in [("version: nope", 1), ("version: 1.4.0+7", 0),
                            ("version: 1.4.0+2100000000", 1)]:
            with self.assertRaises(ValueError):
                release_version(source, run)


if __name__ == "__main__":
    unittest.main()
