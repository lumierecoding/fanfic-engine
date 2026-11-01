"""Settings kept on this computer (QSettings: the registry on Windows, a config file on Linux).

Developer options can override a setting for one run without saving it (`--set fandomsExpanded=true`).
"""

from __future__ import annotations

from PySide6.QtCore import QSettings

DEFAULTS: dict[str, object] = {
    "showFandoms": True,
    "showCharacters": True,
    "showPairings": True,
    "sidebarSort": "name",  # "name" | "count"
    "includeFriendships": True,
    "fandomsExpanded": False,
    "charactersExpanded": False,
    "pairingsExpanded": False,
}


class Prefs:
    def __init__(self, overrides: dict[str, str] | None = None):
        self._settings = QSettings("Fanfic Engine", "Fanfic Engine")
        self._overrides = dict(overrides or {})

    def get(self, key: str):
        default = DEFAULTS[key]
        raw = self._overrides[key] if key in self._overrides else self._settings.value(key, default)
        if isinstance(default, bool):
            return raw if isinstance(raw, bool) else str(raw).lower() in ("1", "true", "yes")
        return str(raw)

    def set(self, key: str, value) -> None:
        self._overrides.pop(key, None)
        self._settings.setValue(key, value)
        self._settings.sync()
