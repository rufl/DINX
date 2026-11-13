#!/usr/bin/env python3
"""Validate all DINX-BSD FreeBSD port Makefiles for correctness and completeness."""

from __future__ import annotations

import sys
from pathlib import Path


def validate_ports() -> int:
    root = Path(__file__).resolve().parent.parent
    ports_dir = root / "distro" / "bsd" / "ports"
    if not ports_dir.is_dir():
        print(f"Error: ports directory not found at {ports_dir}", file=sys.stderr)
        return 1

    makefiles = sorted(ports_dir.glob("Makefile.*"))
    if not makefiles:
        print(f"Error: no port Makefiles found in {ports_dir}", file=sys.stderr)
        return 1

    errors = 0
    print(f"Validating {len(makefiles)} DINX-BSD port Makefiles...")

    for mf in makefiles:
        expected_suffix = mf.name.removeprefix("Makefile.")
        content = mf.read_text(encoding="utf-8")
        lines = content.splitlines()

        variables: dict[str, str] = {}
        for line in lines:
            if "=" in line and not line.strip().startswith("#"):
                parts = line.split("=", 1)
                key = parts[0].strip()
                val = parts[1].strip()
                variables[key] = val

        portname = variables.get("PORTNAME", "").strip('"\'')
        portversion = variables.get("PORTVERSION", "").strip('"\'')
        categories = variables.get("CATEGORIES", "")
        comment = variables.get("COMMENT", "")
        license_var = variables.get("LICENSE", "")

        mf_errors = []
        if not portname:
            mf_errors.append("missing PORTNAME")
        elif portname != expected_suffix and expected_suffix not in portname:
            mf_errors.append(f"PORTNAME '{portname}' does not match filename suffix '{expected_suffix}'")

        if not portversion:
            mf_errors.append("missing PORTVERSION")
        if not categories:
            mf_errors.append("missing CATEGORIES")
        if not comment:
            mf_errors.append("missing COMMENT")
        if not license_var:
            mf_errors.append("missing LICENSE")
        if ".include <bsd.port.mk>" not in content:
            mf_errors.append("missing .include <bsd.port.mk>")

        if mf_errors:
            errors += len(mf_errors)
            print(f"  [FAIL] {mf.name}: {', '.join(mf_errors)}")
        else:
            pass

    if errors > 0:
        print(f"\nPort validation failed with {errors} error(s).", file=sys.stderr)
        return 1

    print(f"All {len(makefiles)} DINX-BSD port Makefiles successfully validated.")
    return 0


if __name__ == "__main__":
    sys.exit(validate_ports())
