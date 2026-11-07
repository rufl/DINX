#!/usr/bin/env python3
"""Offline contract tests for reviewed upstream package source updates."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("refresh_package_sources.py")
SPEC = importlib.util.spec_from_file_location("refresh_package_sources", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


class RefreshPackageSourcesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "checkout"
        self.root.mkdir()
        self.source_path = self.root / "distro/packages/example/source.env"
        self.source_path.parent.mkdir(parents=True)
        self.source_path.write_text(
            "EXAMPLE_VERSION=1.2.0\n"
            "EXAMPLE_SOURCE_URL=https://example.invalid/v1.2.0.tar.gz\n"
            "EXAMPLE_SOURCE_SHA256=" + "a" * 64 + "\n",
            encoding="utf-8",
        )
        self.package_path = self.source_path.parent / "PKGBUILD"
        self.package_path.write_text('pkgver=1.0.0\npkgrel=4\nsource=("src.tar.gz")\n', encoding="utf-8")
        self.manifest = {
            "schema": "dinx-upstream-package-updates/v1",
            "packages": [
                {
                    "name": "example",
                    "provider": "github",
                    "repository": "owner/project",
                    "source_file": "distro/packages/example/source.env",
                    "version_key": "EXAMPLE_VERSION",
                    "source_url_key": "EXAMPLE_SOURCE_URL",
                    "checksum_key": "EXAMPLE_SOURCE_SHA256",
                    "checksum": "sha256",
                    "url_template": "https://example.invalid/archive/{tag}.tar.gz",
                    "bump_pkgrel_path": "distro/packages/example/PKGBUILD",
                }
            ],
        }
        self.latest_tag = "v1.3.0"
        self.checksum = "b" * 64
        self.lookup_calls: list[tuple[str, str]] = []
        self.body_calls: list[str] = []
        self.release_page = "Version: v2.0.0-alpha.7"
        self.hash_calls: list[tuple[str, str]] = []
        self.artifact_manifest_url = "https://updates.example.invalid/stable.json"
        self.artifact_manifest = {
            "Artifacts": [
                {
                    "Filename": "assets.zip",
                    "SHA256": self.checksum,
                    "URLs": ["https://updates.example.invalid/assets_v0-4-0.zip"],
                }
            ]
        }

    def fake_json(self, url: str, token: str) -> dict:
        self.lookup_calls.append((url, token))
        if url == self.artifact_manifest_url:
            return self.artifact_manifest
        return {"tag_name": self.latest_tag}

    def fake_body(self, url: str) -> str:
        self.body_calls.append(url)
        return self.release_page

    def fake_hash(self, url: str, algorithm: str) -> str:
        self.hash_calls.append((url, algorithm))
        return self.checksum

    def plan(self):
        return updater.plan_updates(
            self.root,
            self.manifest,
            token="offline-token",
            get_json=self.fake_json,
            hash_source=self.fake_hash,
            get_body=self.fake_body,
        )

    def test_newer_source_only_release_updates_pins_and_bumps_pkgrel(self) -> None:
        with patch("builtins.print"):
            changes, changed = self.plan()
        self.assertEqual(changed, ["example"])
        self.assertEqual(self.lookup_calls, [("https://api.github.com/repos/owner/project/releases/latest", "offline-token")])
        self.assertEqual(self.hash_calls, [("https://example.invalid/archive/v1.3.0.tar.gz", "sha256")])
        self.assertEqual(changes[self.source_path],
                         "EXAMPLE_VERSION=1.3.0\n"
                         "EXAMPLE_SOURCE_URL=https://example.invalid/archive/v1.3.0.tar.gz\n"
                         f"EXAMPLE_SOURCE_SHA256={self.checksum}\n")
        self.assertIn("pkgrel=5\n", changes[self.package_path])
        with patch("builtins.print"):
            updater.write_updates(changes, dry_run=False)
        self.assertIn("EXAMPLE_VERSION=1.3.0", self.source_path.read_text(encoding="utf-8"))
        self.assertIn("pkgrel=5", self.package_path.read_text(encoding="utf-8"))

    def test_codeberg_release_lookup_refreshes_calamares_pin(self) -> None:
        entry = self.manifest["packages"][0]
        entry["provider"] = "codeberg"
        entry["repository"] = "Calamares/calamares"
        entry["tag_prefix"] = "v"
        entry["url_template"] = (
            "https://codeberg.org/Calamares/calamares/releases/download/"
            "{tag}/calamares-{version}.tar.gz"
        )
        self.latest_tag = "v1.3.0"

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertEqual(
            self.lookup_calls,
            [("https://codeberg.org/api/v1/repos/Calamares/calamares/releases/latest", "")],
        )
        archive_url = (
            "https://codeberg.org/Calamares/calamares/releases/download/"
            "v1.3.0/calamares-1.3.0.tar.gz"
        )
        self.assertEqual(self.hash_calls, [(archive_url, "sha256")])
        updated = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated["EXAMPLE_VERSION"], "1.3.0")
        self.assertEqual(updated["EXAMPLE_SOURCE_URL"], archive_url)
        self.assertIn("pkgrel=5\n", changes[self.package_path])
    def test_dotted_release_version_can_render_hyphenated_binary_paths(self) -> None:
        entry = self.manifest["packages"][0]
        entry["tag_prefix"] = "v"
        entry["url_template"] = "https://example.invalid/releases/tool_v{version_dash}"
        self.latest_tag = "v1.3.0"

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertEqual(
            self.hash_calls,
            [("https://example.invalid/releases/tool_v1-3-0", "sha256")],
        )
        updated = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated["EXAMPLE_VERSION"], "1.3.0")
        self.assertEqual(
            updated["EXAMPLE_SOURCE_URL"],
            "https://example.invalid/releases/tool_v1-3-0",
        )


    def add_refreshable_asset_source(self) -> None:
        self.source_path.write_text(
            self.source_path.read_text(encoding="utf-8")
            + "EXAMPLE_ASSETS_URL=https://updates.example.invalid/assets_v0-3-9.zip\n"
            + "EXAMPLE_ASSETS_SHA256="
            + "a" * 64
            + "\n",
            encoding="utf-8",
        )
        self.manifest["packages"][0]["additional_sources"] = [
            {
                "source_url_key": "EXAMPLE_ASSETS_URL",
                "checksum_key": "EXAMPLE_ASSETS_SHA256",
                "manifest_url": self.artifact_manifest_url,
                "artifact_name": "assets.zip",
                "refresh_always": True,
            }
        ]

    def test_manifest_asset_refreshes_independently_and_is_idempotent(self) -> None:
        self.add_refreshable_asset_source()
        self.latest_tag = "v1.2.0"

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertIn((self.artifact_manifest_url, ""), self.lookup_calls)
        self.assertEqual(
            self.hash_calls,
            [("https://updates.example.invalid/assets_v0-4-0.zip", "sha256")],
        )
        updated_pins = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated_pins["EXAMPLE_VERSION"], "1.2.0")
        self.assertEqual(
            updated_pins["EXAMPLE_ASSETS_URL"],
            "https://updates.example.invalid/assets_v0-4-0.zip",
        )
        self.assertEqual(updated_pins["EXAMPLE_ASSETS_SHA256"], self.checksum)
        self.assertIn("pkgrel=5\n", changes[self.package_path])

        with patch("builtins.print"):
            updater.write_updates(changes, dry_run=False)
        self.hash_calls.clear()
        with patch("builtins.print"):
            unchanged, unchanged_packages = self.plan()
        self.assertEqual(unchanged, {})
        self.assertEqual(unchanged_packages, [])
        self.assertEqual(self.hash_calls, [])

    def test_manifest_checksum_mismatch_fails_without_changing_pins(self) -> None:
        self.add_refreshable_asset_source()
        self.latest_tag = "v1.2.0"
        self.artifact_manifest["Artifacts"][0]["SHA256"] = "c" * 64
        original = self.source_path.read_bytes()

        with self.assertRaisesRegex(ValueError, "artifact manifest SHA256 mismatch"), patch("builtins.print"):
            self.plan()

        self.assertEqual(self.source_path.read_bytes(), original)

    def test_prefixed_release_updates_all_additional_source_pins(self) -> None:
        source_keys = (
            ("BOLD", "bold.ttf"),
            ("ITALIC", "italic.ttf"),
            ("BOLD_ITALIC", "bold-italic.ttf"),
            ("MONO", "mono.ttf"),
        )
        pins = [
            "EXAMPLE_VERSION=1.2.0",
            "EXAMPLE_SOURCE_URL=https://example.invalid/noto-monthly-release-1.2.0/regular.ttf",
            "EXAMPLE_SOURCE_SHA256=" + "a" * 64,
        ]
        additional_sources = []
        for suffix, filename in source_keys:
            pins.extend(
                (
                    f"EXAMPLE_{suffix}_URL=https://example.invalid/noto-monthly-release-1.2.0/{filename}",
                    f"EXAMPLE_{suffix}_SHA256=" + "a" * 64,
                )
            )
            additional_sources.append(
                {
                    "source_url_key": f"EXAMPLE_{suffix}_URL",
                    "checksum_key": f"EXAMPLE_{suffix}_SHA256",
                    "url_template": f"https://example.invalid/{{tag}}/{filename}",
                }
            )
        self.source_path.write_text("\n".join(pins) + "\n", encoding="utf-8")
        entry = self.manifest["packages"][0]
        entry["tag_prefix"] = "noto-monthly-release-"
        entry["url_template"] = "https://example.invalid/{tag}/regular.ttf"
        entry["additional_sources"] = additional_sources
        self.latest_tag = "noto-monthly-release-1.3.0"

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertEqual(len(self.hash_calls), 5)
        self.assertEqual(
            self.hash_calls,
            [
                ("https://example.invalid/noto-monthly-release-1.3.0/regular.ttf", "sha256"),
                *[
                    (f"https://example.invalid/noto-monthly-release-1.3.0/{filename}", "sha256")
                    for _, filename in source_keys
                ],
            ],
        )
        updated_pins = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated_pins["EXAMPLE_VERSION"], "1.3.0")
        self.assertEqual(
            updated_pins["EXAMPLE_SOURCE_URL"],
            "https://example.invalid/noto-monthly-release-1.3.0/regular.ttf",
        )
        for suffix, filename in source_keys:
            self.assertEqual(
                updated_pins[f"EXAMPLE_{suffix}_URL"],
                f"https://example.invalid/noto-monthly-release-1.3.0/{filename}",
            )
            self.assertEqual(updated_pins[f"EXAMPLE_{suffix}_SHA256"], self.checksum)
        self.assertEqual(updated_pins["EXAMPLE_SOURCE_SHA256"], self.checksum)
        self.assertIn("pkgrel=5\n", changes[self.package_path])


    def test_release_prefix_mismatch_fails_before_hashing(self) -> None:
        original = self.source_path.read_bytes()
        self.manifest["packages"][0]["tag_prefix"] = "noto-monthly-release-"
        self.latest_tag = "v1.3.0"

        with self.assertRaisesRegex(ValueError, "unsupported release tag"), patch("builtins.print"):
            self.plan()

        self.assertEqual(self.hash_calls, [])
        self.assertEqual(self.source_path.read_bytes(), original)

    def test_same_and_older_releases_do_not_downgrade(self) -> None:
        original = self.source_path.read_bytes()
        for tag in ("v1.2.0", "v1.1.9"):
            with self.subTest(tag=tag):
                self.latest_tag = tag
                self.hash_calls.clear()
                with patch("builtins.print"):
                    changes, changed = self.plan()
                self.assertEqual(changes, {})
                self.assertEqual(changed, [])
                self.assertEqual(self.hash_calls, [])
                self.assertEqual(self.source_path.read_bytes(), original)

    def test_dry_run_preserves_files_byte_for_byte(self) -> None:
        before = {path: path.read_bytes() for path in (self.source_path, self.package_path)}
        with patch("builtins.print"):
            changes, _ = self.plan()
            updater.write_updates(changes, dry_run=True)
        self.assertEqual({path: path.read_bytes() for path in before}, before)

    def test_malformed_or_duplicate_version_pins_fail_safely(self) -> None:
        original = self.source_path.read_bytes()
        for text in (
            "EXAMPLE_VERSION=not-a-version\nEXAMPLE_SOURCE_URL=x\nEXAMPLE_SOURCE_SHA256=" + "a" * 64 + "\n",
            "EXAMPLE_VERSION=1.2.0\nEXAMPLE_VERSION=1.2.1\nEXAMPLE_SOURCE_URL=x\nEXAMPLE_SOURCE_SHA256=" + "a" * 64 + "\n",
        ):
            with self.subTest(text=text):
                self.source_path.write_text(text, encoding="utf-8")
                with self.assertRaises(ValueError), patch("builtins.print"):
                    self.plan()
                self.assertEqual(self.source_path.read_text(encoding="utf-8"), text)
        self.source_path.write_bytes(original)

    def test_path_traversal_fails_safely(self) -> None:
        outside = Path(self.temporary.name) / "outside.env"
        outside.write_text("EXAMPLE_VERSION=1.2.0\n", encoding="utf-8")
        original = outside.read_bytes()
        self.manifest["packages"][0]["source_file"] = "../outside.env"
        with self.assertRaisesRegex(ValueError, "escapes the checkout"), patch("builtins.print"):
            self.plan()
        self.assertEqual(outside.read_bytes(), original)

    def test_checksum_failure_and_unsupported_tag_fail_closed(self) -> None:
        original = self.source_path.read_bytes()

        def mismatched_hash(url: str, algorithm: str) -> str:
            raise ValueError(f"source checksum mismatch: {url}")

        with self.assertRaisesRegex(ValueError, "source checksum mismatch"), patch("builtins.print"):
            updater.plan_updates(
                self.root, self.manifest, get_json=self.fake_json, hash_source=mismatched_hash
            )
        self.assertEqual(self.source_path.read_bytes(), original)
        self.checksum = "not-a-sha256"
        with self.assertRaisesRegex(ValueError, "checksum has an invalid format"), patch("builtins.print"):
            self.plan()
        self.assertEqual(self.source_path.read_bytes(), original)
        self.checksum = "b" * 64
        self.latest_tag = "release-candidate"
        with self.assertRaisesRegex(ValueError, "unsupported release version"), patch("builtins.print"):
            self.plan()
        self.assertEqual(self.source_path.read_bytes(), original)

    def test_zrythm_official_page_refreshes_prerelease_appimage(self) -> None:
        self.source_path.write_text(
            "\n".join(
                [
                    "EXAMPLE_VERSION=2.0.0-alpha.6",
                    "EXAMPLE_SOURCE_URL=https://example.invalid/Zrythm-2.0.0-alpha.6-Linux-x86_64.AppImage",
                    f"EXAMPLE_SOURCE_SHA256={'a' * 64}",
                    "EXAMPLE_LICENSE_URL=https://example.invalid/license/v2.0.0-alpha.6.txt",
                    f"EXAMPLE_LICENSE_SHA256={'c' * 64}",
                    "EXAMPLE_TRADEMARKS_URL=https://example.invalid/trademarks/v2.0.0-alpha.6.md",
                    f"EXAMPLE_TRADEMARKS_SHA256={'d' * 64}",
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        entry = self.manifest["packages"][0]
        entry["provider"] = "zrythm"
        entry["repository"] = "zrythm/zrythm"
        entry["url_template"] = (
            "https://www.zrythm.org/downloads/Zrythm-{version}-Linux-x86_64.AppImage"
        )
        self.release_page = "Version: v2.0.0-alpha.7"
        entry["additional_sources"] = [
            {
                "source_url_key": "EXAMPLE_LICENSE_URL",
                "checksum_key": "EXAMPLE_LICENSE_SHA256",
                "url_template": "https://example.invalid/license/{tag}.txt",
            },
            {
                "source_url_key": "EXAMPLE_TRADEMARKS_URL",
                "checksum_key": "EXAMPLE_TRADEMARKS_SHA256",
                "url_template": "https://example.invalid/trademarks/{tag}.md",
            },
        ]

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertEqual(
            self.body_calls,
            ["https://www.zrythm.org/en/download-v2-alpha.html"],
        )
        self.assertEqual(
            self.hash_calls,
            [
                (
                    "https://www.zrythm.org/downloads/Zrythm-2.0.0-alpha.7-Linux-x86_64.AppImage",
                    "sha256",
                ),
                ("https://example.invalid/license/v2.0.0-alpha.7.txt", "sha256"),
                ("https://example.invalid/trademarks/v2.0.0-alpha.7.md", "sha256"),
            ],
        )
        updated = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated["EXAMPLE_VERSION"], "2.0.0-alpha.7")
        self.assertEqual(
            updated["EXAMPLE_SOURCE_URL"],
            "https://www.zrythm.org/downloads/Zrythm-2.0.0-alpha.7-Linux-x86_64.AppImage",
        )

        self.assertEqual(
            updated["EXAMPLE_LICENSE_URL"],
            "https://example.invalid/license/v2.0.0-alpha.7.txt",
        )
        self.assertEqual(
            updated["EXAMPLE_TRADEMARKS_URL"],
            "https://example.invalid/trademarks/v2.0.0-alpha.7.md",
        )

    def test_kde_stable_directory_selects_highest_numeric_release(self) -> None:
        entry = self.manifest["packages"][0]
        entry["provider"] = "kde"
        entry["repository"] = "multimedia/haruna"
        entry["url_template"] = (
            "https://download.kde.org/stable/haruna/{version}/haruna-{version}.tar.xz"
        )
        entry["bump_pkgrel_path"] = "distro/packages/example/PKGBUILD"
        self.release_page = (
            '<a href="../">Parent directory</a>'
            '<a href="1.9.0/">1.9.0/</a>'
            '<a href="1.10.0/">1.10.0/</a>'
            '<a href="2.0.0-rc.1/">2.0.0-rc.1/</a>'
        )

        with patch("builtins.print"):
            changes, changed = self.plan()

        self.assertEqual(changed, ["example"])
        self.assertEqual(
            self.body_calls,
            ["https://download.kde.org/stable/haruna/"],
        )
        self.assertEqual(self.lookup_calls, [])
        self.assertEqual(
            self.hash_calls,
            [("https://download.kde.org/stable/haruna/1.10.0/haruna-1.10.0.tar.xz", "sha256")],
        )
        updated = dict(line.split("=", 1) for line in changes[self.source_path].splitlines())
        self.assertEqual(updated["EXAMPLE_VERSION"], "1.10.0")
        self.assertEqual(
            updated["EXAMPLE_SOURCE_URL"],
            "https://download.kde.org/stable/haruna/1.10.0/haruna-1.10.0.tar.xz",
        )
        self.assertIn("pkgrel=5\n", changes[self.package_path])

    def test_prerelease_order_is_semver_compatible(self) -> None:
        self.assertLess(
            updater.version_tuple("2.0.0-alpha.7"),
            updater.version_tuple("2.0.0-beta.1"),
        )
        self.assertLess(
            updater.version_tuple("2.0.0-rc.1"),
            updater.version_tuple("2.0.0"),
        )


if __name__ == "__main__":
    unittest.main()
