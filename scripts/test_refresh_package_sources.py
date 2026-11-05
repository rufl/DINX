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
        self.hash_calls: list[tuple[str, str]] = []

    def fake_json(self, url: str, token: str) -> dict:
        self.lookup_calls.append((url, token))
        return {"tag_name": self.latest_tag}

    def fake_hash(self, url: str, algorithm: str) -> str:
        self.hash_calls.append((url, algorithm))
        return self.checksum

    def plan(self):
        return updater.plan_updates(
            self.root, self.manifest, token="offline-token", get_json=self.fake_json, hash_source=self.fake_hash
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
        with self.assertRaisesRegex(ValueError, "unsupported stable release version"), patch("builtins.print"):
            self.plan()
        self.assertEqual(self.source_path.read_bytes(), original)
if __name__ == "__main__":
    unittest.main()
