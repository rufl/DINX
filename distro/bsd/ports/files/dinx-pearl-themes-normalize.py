#!/usr/bin/env python3
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
targets = {
    "fluent": {"primary": "#1565c0"},
    "jasper": {"primary": "#00796b", "error_color": "#b3261e"},
}
display_names = {
    "dinx.skeuos-rounded": "Skeuos Rounded (DINX)",
    "dinx.skeuos-square": "Skeuos Square (DINX)",
    "dinx.orchis-rounded": "Orchis Rounded (DINX)",
    "dinx.orchis-square": "Orchis Square (DINX)",
    "dinx.fluent-rounded": "Fluent Rounded (DINX)",
    "dinx.fluent-square": "Fluent Square (DINX)",
    "dinx.jasper-rounded": "Jasper Rounded (DINX)",
    "dinx.jasper-square": "Jasper Square (DINX)",
}
for brand, colors in targets.items():
    for corners in ("rounded", "square"):
        path = root / f"dinx.{brand}-{corners}" / "light.json"
        data = json.loads(path.read_text())
        data.update(colors)
        path.write_text(json.dumps(data, separators=(",", ":")) + "\n")
for theme_id, display_name in display_names.items():
    theme_root = root / theme_id
    manifest_path = theme_root / "theme.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["defaults"] = [
        {"application": app, "profile": f"{theme_id}.{app}"}
        for app in ("gtk", "qt5ct", "qt6ct", "kcolorscheme", "ghostty")
    ]
    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    for name in ("kcolorscheme.colors", "dark-kcolorscheme.colors", "light-kcolorscheme.colors"):
        path = theme_root / "profiles" / name
        lines = path.read_text().splitlines()
        path.write_text("\n".join(
            f"Name={display_name}" if line.startswith("Name=") else line
            for line in lines
        ) + "\n")
