#!/usr/bin/env python3
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

skeuos, skeuos_fork, orchis, fluent, jasper, out = map(Path, sys.argv[1:])
shutil.rmtree(out, ignore_errors=True)
out.mkdir(parents=True)


def sass(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sassc", "-M", "-t", "expanded", str(source), str(target)], check=True)


def copy_assets(source, target):
    for name in ("assets", "scalable"):
        path = source / name
        if path.is_dir():
            destination = target / "assets"
            destination.mkdir(parents=True, exist_ok=True)
            for item in path.iterdir():
                destination_item = destination / item.name
                if item.is_dir():
                    shutil.copytree(item, destination_item, dirs_exist_ok=True)
                else:
                    shutil.copy2(item, destination_item)


def index(name, brand):
    return (
        "[Desktop Entry]\nType=X-GNOME-Metatheme\n"
        f"Name={name}\nComment=DINX port of the {brand} GTK theme\n"
        "Encoding=UTF-8\n\n[X-GNOME-Metatheme]\n"
        f"GtkTheme={name}\nMetacityTheme={name}\nIconTheme=Papirus\n"
        "CursorTheme=Adwaita\nButtonLayout=close,minimize,maximize:menu\n"
    )


def build_brand(root, brand, base, license_name, gtk_prefix, asset_root):
    for suffix in ("", "-Square"):
        for variant in ("Light", "Dark"):
            name = f"{brand}{suffix}-{variant}"
            target = out / name
            for gtk in ("3.0", "4.0"):
                source = root / base / f"{gtk_prefix}{gtk}"
                gtk_target = target / f"gtk-{gtk}"
                sass(source / f"gtk-{variant}.scss", gtk_target / "gtk.css")
                sass(source / "gtk-Dark.scss", gtk_target / "gtk-dark.css")
                copy_assets(root / asset_root, gtk_target)
            (target / "index.theme").write_text(index(name, brand))
            shutil.copy2(root / license_name, target / "COPYING")


build_brand(fluent, "Fluent", "src/gtk", "COPYING", "", "src/gtk")
build_brand(jasper, "Jasper", "src/main", "LICENSE", "gtk-", "src/assets/gtk")

for suffix in ("", "-Square"):
    for variant in ("Light", "Dark"):
        name = f"Orchis{suffix}-{variant}"
        target = out / name
        for gtk in ("3.0", "4.0"):
            source = orchis / "src" / "gtk" / gtk
            gtk_target = target / f"gtk-{gtk}"
            entry = "gtk-Light.scss" if variant == "Light" else "gtk-Dark.scss"
            sass(source / entry, gtk_target / "gtk.css")
            sass(source / "gtk-Dark.scss", gtk_target / "gtk-dark.css")
            copy_assets(orchis / "src" / "gtk", gtk_target)
        (target / "index.theme").write_text(index(name, "Orchis"))
        shutil.copy2(orchis / "COPYING", target / "COPYING")

for variant in ("Light", "Dark"):
    source = skeuos / "themes" / f"Skeuos-Blue-{variant}"
    for suffix in ("", "-Square"):
        name = f"Skeuos-Blue-{variant}{suffix}"
        target = out / name
        for gtk in ("gtk-3.0", "gtk-4.0"):
            shutil.copytree(source / gtk, target / gtk)
        (target / "index.theme").write_text(
            (source / "index.theme").read_text().replace(
                f"Skeuos-Blue-{variant}", name
            )
        )

radius = re.compile(r"border-radius:\s*([^;}]+)")
pixels = re.compile(r"^(\d+(?:\.\d+)?)px$")


def square_css(path):
    text = path.read_text()
    def replace(match):
        values = []
        for part in match.group(1).split():
            if part == "0":
                values.append(0.0)
                continue
            parsed = pixels.match(part)
            if not parsed:
                return match.group(0)
            values.append(float(parsed.group(1)))
        return "border-radius: 0" if values and max(values) <= 20 else match.group(0)
    path.write_text(radius.sub(replace, text))

for theme in out.iterdir():
    if theme.name.endswith("-Square"):
        for gtk in ("gtk-3.0", "gtk-4.0"):
            for css in ("gtk.css", "gtk-dark.css"):
                path = theme / gtk / css
                if path.is_file():
                    square_css(path)

sk = json.loads((skeuos_fork / "themes" / "skeuos-rounded" / "dark.json").read_text())["primary"]
or_dark = json.loads((orchis / "themes" / "orchis-rounded" / "dark.json").read_text())["primary"]
or_light = json.loads((orchis / "themes" / "orchis-rounded" / "light.json").read_text())["primary"]

def unify(path, raw, new):
    if path.is_symlink() or not path.is_file():
        return
    text = path.read_text()
    updated = re.sub(re.escape(raw), new, text, flags=re.IGNORECASE)
    if updated != text:
        path.write_text(updated)

for theme in out.iterdir():
    variant = "dark" if theme.name.endswith("-Dark") else "light"
    for gtk in ("gtk-3.0", "gtk-4.0"):
        for css in ("gtk.css", "gtk-dark.css"):
            path = theme / gtk / css
            file_variant = "dark" if css == "gtk-dark.css" else variant
            if theme.name.startswith("Skeuos-"):
                unify(path, "#2777ff", sk)
            elif theme.name.startswith("Orchis-"):
                unify(path, "#3281ea" if file_variant == "dark" else "#1a73e8", or_dark if file_variant == "dark" else or_light)
            elif theme.name.startswith("Jasper-") and file_variant == "light":
                unify(path, "#009688", "#00796b")
