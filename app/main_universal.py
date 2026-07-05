"""Universal GUI entrypoint."""

from __future__ import annotations

from app.gui.universal_main_window import UniversalMainWindow


def main() -> None:
    app = UniversalMainWindow()
    app.mainloop()


if __name__ == "__main__":
    main()
