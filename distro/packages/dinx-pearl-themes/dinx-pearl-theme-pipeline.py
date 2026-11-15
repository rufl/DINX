#!/usr/bin/env python3
import argparse
import filecmp
import hashlib
import json
import os
from pathlib import Path

APPLICATIONS = ("gtk", "qt5ct", "qt6ct", "kcolorscheme", "ghostty")
DISPLAY_NAMES = {
    "dinx.skeuos-rounded": "Skeuos Rounded (DINX)",
    "dinx.skeuos-square": "Skeuos Square (DINX)",
    "dinx.orchis-rounded": "Orchis Rounded (DINX)",
    "dinx.orchis-square": "Orchis Square (DINX)",
    "dinx.fluent-rounded": "Fluent Rounded (DINX)",
    "dinx.fluent-square": "Fluent Square (DINX)",
    "dinx.jasper-rounded": "Jasper Rounded (DINX)",
    "dinx.jasper-square": "Jasper Square (DINX)",
}
LIGHT_OVERRIDES = {
    "dinx.fluent-rounded": {"primary": "#1565c0"},
    "dinx.fluent-square": {"primary": "#1565c0"},
    "dinx.jasper-rounded": {"primary": "#00796b", "error_color": "#b3261e"},
    "dinx.jasper-square": {"primary": "#00796b", "error_color": "#b3261e"},
}
REQUIRED_FILES = (
    "theme.json",
    "tokens.json",
    "light.json",
    "dark.json",
    "components.css",
    "profiles/gtk.json",
    "profiles/qt5ct.json",
    "profiles/qt6ct.json",
    "profiles/kcolorscheme.json",
    "profiles/ghostty.json",
    "profiles/kcolorscheme.colors",
    "profiles/dark-kcolorscheme.colors",
    "profiles/light-kcolorscheme.colors",
)


def read_json(path):
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def write_json(path, value):
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, separators=(",", ":"))
        stream.write("\n")


def luminance(color):
    if not isinstance(color, str) or len(color) != 7 or not color.startswith("#"):
        raise ValueError(f"invalid color: {color!r}")
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    channels = [
        channel / 12.92 if channel <= 0.04045
        else ((channel + 0.055) / 1.055) ** 2.4
        for channel in channels
    ]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def normalize(root):
    for theme_id, display_name in DISPLAY_NAMES.items():
        theme_root = root / theme_id
        light_path = theme_root / "light.json"
        light = read_json(light_path)
        light.update(LIGHT_OVERRIDES.get(theme_id, {}))
        write_json(light_path, light)

        manifest_path = theme_root / "theme.json"
        manifest = read_json(manifest_path)
        manifest["defaults"] = [
            {"application": app, "profile": f"{theme_id}.{app}"}
            for app in APPLICATIONS
        ]
        write_json(manifest_path, manifest)

        for name in (
            "kcolorscheme.colors",
            "dark-kcolorscheme.colors",
            "light-kcolorscheme.colors",
        ):
            path = theme_root / "profiles" / name
            lines = path.read_text(encoding="utf-8").splitlines()
            path.write_text(
                "\n".join(
                    f"Name={display_name}" if line.startswith("Name=") else line
                    for line in lines
                ) + "\n",
                encoding="utf-8",
            )

    for path in sorted(root.rglob("*.json")):
        write_json(path, read_json(path))


def validate(root):
    actual = {path.name for path in root.iterdir() if path.is_dir()}
    expected = set(DISPLAY_NAMES)
    if actual != expected:
        raise ValueError(
            f"theme directory mismatch: missing={sorted(expected - actual)} "
            f"unexpected={sorted(actual - expected)}"
        )

    for theme_id, display_name in DISPLAY_NAMES.items():
        theme_root = root / theme_id
        for relative in REQUIRED_FILES:
            path = theme_root / relative
            if not path.is_file() or path.stat().st_size == 0:
                raise ValueError(f"missing or empty theme asset: {path}")

        manifest = read_json(theme_root / "theme.json")
        if manifest.get("schema_version") != 2 or manifest.get("id") != theme_id:
            raise ValueError(f"invalid manifest identity: {theme_root / 'theme.json'}")
        expected_defaults = [
            {"application": app, "profile": f"{theme_id}.{app}"}
            for app in APPLICATIONS
        ]
        if manifest.get("defaults") != expected_defaults:
            raise ValueError(f"invalid application defaults: {theme_root / 'theme.json'}")

        tokens = read_json(theme_root / "tokens.json")
        radii = (tokens.get("card_radius"), tokens.get("control_radius"))
        if theme_id.endswith("-square") and radii != (0, 0):
            raise ValueError(f"square theme has non-zero radii: {theme_id} {radii}")
        if theme_id.endswith("-rounded") and any(
            not isinstance(radius, int) or radius <= 0 for radius in radii
        ):
            raise ValueError(f"rounded theme has invalid radii: {theme_id} {radii}")

        for variant in ("light", "dark"):
            path = theme_root / f"{variant}.json"
            palette = read_json(path)
            for foreground, background in (
                ("primary", "on_primary"),
                ("error_color", "error_container"),
            ):
                ratio = contrast(palette.get(foreground), palette.get(background))
                if ratio < 4.5:
                    raise ValueError(
                        f"{path}: {foreground}/{background} contrast "
                        f"{ratio:.2f}:1 < 4.5:1"
                    )

        expected_name = f"Name={display_name}"
        for name in (
            "kcolorscheme.colors",
            "dark-kcolorscheme.colors",
            "light-kcolorscheme.colors",
        ):
            path = theme_root / "profiles" / name
            if expected_name not in path.read_text(encoding="utf-8").splitlines():
                raise ValueError(f"wrong KDE display name: {path}")


def digest_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.digest()


def deduplicate(root):
    seen = {}
    linked = 0
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
        if path.is_symlink():
            continue
        digest = digest_file(path)
        key = (path.stat().st_size, digest)
        previous = seen.get(key)
        if previous is None:
            seen[key] = path
            continue
        if filecmp.cmp(previous, path, shallow=False):
            path.unlink()
            os.link(previous, path)
            linked += 1
    return linked


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("normalize", "validate"))
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    if args.mode == "normalize":
        normalize(args.root)
        validate(args.root)
        linked = deduplicate(args.root)
        print(f"pearl_theme_pipeline themes={len(DISPLAY_NAMES)} hardlinks={linked}")
    else:
        validate(args.root)
        print(f"pearl_theme_validation themes={len(DISPLAY_NAMES)} contrast=wcag-aa")


if __name__ == "__main__":
    main()
