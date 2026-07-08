from pathlib import Path


def test_pattern_canvas_lives_in_main_dedicated_tab_not_below_form():
    source = Path("app/gui/universal_main_window.py").read_text(encoding="utf-8")

    assert "CTkTabview" in source
    assert 'self.main_tabs.add("Generacion / Editor")' in source
    assert 'self.main_tabs.add("Vista patron")' in source

    # The canvas may be instantiated in one line or multiline depending on
    # later phases. The contract is that it lives inside pattern_tab, not below
    # the form or directly in the root window.
    assert "ReadOnlyPatternCanvas(" in source
    assert "self.pattern_tab" in source
    assert "height=680" in source
    assert 'self.main_tabs.set("Vista patron")' in source

    assert "self.workspace_tabs" not in source
    assert "ReadOnlyPatternCanvas(self)" not in source
