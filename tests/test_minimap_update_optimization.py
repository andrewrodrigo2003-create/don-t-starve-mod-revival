from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "dst-mods" / "metals_and_reforged" / "initialise" / "modded_map.lua"


class MinimapUpdateOptimizationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_position_helper_uses_scalar_screen_dimensions(self):
        self.assertIn(
            "local function PositionMiniMap(controls, screenw_full, screenh_full)",
            self.source,
        )
        self.assertNotIn("GLOBAL.unpack(screensize)", self.source)

    def test_update_wrapper_reuses_vanilla_cached_dimensions(self):
        self.assertIn("local curscreenw, curscreenh = self._scrnw, self._scrnh", self.source)
        self.assertIn("PositionMiniMap(self, screenw, screenh)", self.source)

    def test_base_update_runs_before_cached_dimensions_are_read(self):
        base_call = self.source.index("OnUpdate_base(self, dt)")
        cached_read = self.source.index("local curscreenw, curscreenh = self._scrnw, self._scrnh")
        self.assertLess(base_call, cached_read)

    def test_no_per_frame_temporary_screen_size_tables(self):
        self.assertNotIn("{GLOBAL.TheSim:GetScreenSize()}", self.source)

    def test_fallback_only_queries_screen_size_when_cache_is_missing(self):
        self.assertIn(
            "if curscreenw == nil or curscreenh == nil then",
            self.source,
        )
        self.assertIn(
            "curscreenw, curscreenh = GLOBAL.TheSim:GetScreenSize()",
            self.source,
        )


if __name__ == "__main__":
    unittest.main()
