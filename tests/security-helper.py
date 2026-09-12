#!/usr/bin/python3
"""Behavioral filesystem/image checks for secure_io.py without touching $HOME."""

from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import tempfile
import zlib


ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("omasports_secure_io", ROOT / "secure_io.py")
assert SPEC and SPEC.loader
secure_io = importlib.util.module_from_spec(SPEC)
import sys
sys.modules[SPEC.name] = secure_io
SPEC.loader.exec_module(secure_io)


def use_home(path: pathlib.Path) -> None:
    secure_io.canonical_home = lambda: str(path)


def tiny_png() -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"

    def chunk(kind: bytes, payload: bytes) -> bytes:
        body = kind + payload
        return len(payload).to_bytes(4, "big") + body + (zlib.crc32(body) & 0xFFFFFFFF).to_bytes(4, "big")

    ihdr = (1).to_bytes(4, "big") + (1).to_bytes(4, "big") + bytes([8, 6, 0, 0, 0])
    return signature + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\x00")) + chunk(b"IEND", b"")


with tempfile.TemporaryDirectory(prefix="omasports-security-") as tmp:
    home = pathlib.Path(tmp)
    use_home(home)
    (home / ".config").mkdir(mode=0o700)
    (home / ".cache").mkdir(mode=0o700)

    initial = json.dumps({"sport": "football", "refreshMinutes": 15}) + "\n"
    assert secure_io.state_write(initial) == 0
    state_path = home / ".config" / "omarchy" / "sports-favorites.json"
    assert state_path.read_text() == initial

    outside = home / "outside-sentinel"
    outside.write_text("DO NOT TOUCH")
    state_path.unlink()
    state_path.symlink_to(outside)
    try:
        secure_io.state_write(json.dumps({"sport": "nba"}))
        raise AssertionError("state writer followed a symlink target")
    except secure_io.SecurityError:
        pass
    assert outside.read_text() == "DO NOT TOUCH"

with tempfile.TemporaryDirectory(prefix="omasports-cache-") as tmp:
    home = pathlib.Path(tmp)
    use_home(home)
    (home / ".cache").mkdir(mode=0o700)
    cache_parent = home / ".cache" / "omarchy-omasports"
    cache_parent.mkdir(mode=0o700)
    outside = home / "outside-cache"
    outside.mkdir(mode=0o700)
    (cache_parent / "logos").symlink_to(outside, target_is_directory=True)
    try:
        secure_io.cache_scan()
        raise AssertionError("cache scanner followed a symlink parent")
    except OSError:
        pass
    assert list(outside.iterdir()) == []

with tempfile.TemporaryDirectory(prefix="omasports-corrupt-") as tmp:
    home = pathlib.Path(tmp)
    use_home(home)
    (home / ".config").mkdir(mode=0o700)
    secure_io.state_write(json.dumps({"sport": "football"}))
    state_path = home / ".config" / "omarchy" / "sports-favorites.json"
    state_path.write_text("{not-json")
    # Reproduce the secure backup path without stdout coupling.
    fd = secure_io.state_dir()
    raw = secure_io.read_file_at(fd, "sports-favorites.json", secure_io.STATE_MAX_BYTES)
    secure_io.atomic_write_at(fd, "sports-favorites.json.corrupt", raw)
    os.close(fd)
    assert (state_path.parent / "sports-favorites.json.corrupt").read_text() == "{not-json"

with tempfile.TemporaryDirectory(prefix="omasports-png-") as tmp:
    home = pathlib.Path(tmp)
    use_home(home)
    (home / ".cache").mkdir(mode=0o700)
    good = tiny_png()
    width, height = secure_io.validate_png(good)
    assert (width, height) == (1, 1)
    for bad in (b"<html>200 but not image</html>", b"\x89PNG\r\n\x1a\njunk", good[:-8]):
        try:
            secure_io.validate_png(bad)
            raise AssertionError("invalid PNG was accepted")
        except secure_io.SecurityError:
            pass

print("secure_io behavioral checks passed")
