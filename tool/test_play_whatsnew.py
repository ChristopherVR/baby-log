import unittest

from play_whatsnew import LIMIT, whats_new


class PlayWhatsNewTest(unittest.TestCase):
    def test_short_notes_are_kept_without_blank_lines(self):
        self.assertEqual(whats_new("Changes\n\n- Rename to Nestling\n"), "Changes\n- Rename to Nestling")

    def test_long_notes_stop_at_a_whole_line(self):
        notes = "Changes\n" + "\n".join(f"- Change number {i} with some words" for i in range(40))
        text = whats_new(notes)
        self.assertLessEqual(len(text), LIMIT)
        self.assertTrue(text.endswith("\n…"))
        self.assertIn("- Change number 0 with some words", text)

    def test_single_overlong_line_is_cut(self):
        self.assertEqual(len(whats_new("x" * 900)), LIMIT)

    def test_empty_notes_are_rejected(self):
        with self.assertRaises(ValueError):
            whats_new("  \n")


if __name__ == "__main__":
    unittest.main()
