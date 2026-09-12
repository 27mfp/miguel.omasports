#!/usr/bin/python3
"""Hardened I/O boundary for OmaSports.

The QML layer deliberately delegates filesystem mutation and public network
reads here because Python exposes the descriptor-relative/openat primitives
needed to reject symlink parents and publish files atomically.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import pwd
import re
import secrets
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request
import zlib
from dataclasses import dataclass
from typing import Iterable


STATE_MAX_BYTES = 256 * 1024
FETCH_HARD_MAX_BYTES = 8 * 1024 * 1024
CREST_MAX_BYTES = 512 * 1024
CREST_MAX_DIMENSION = 2048
MAX_CACHE_ENTRIES = 4096

DATA_HOSTS = frozenset({"www.fotmob.com", "site.api.espn.com", "api.jolpi.ca"})
CREST_HOSTS = frozenset({"images.fotmob.com", "a.espncdn.com"})
ALLOWED_TOOLS = {
    "notify-send": "/usr/bin/notify-send",
    "xdg-open": "/usr/bin/xdg-open",
}
KEY_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,127}$")


class SecurityError(RuntimeError):
    pass


def become_process_group_leader() -> None:
    try:
        os.setsid()
    except PermissionError:
        # A caller that already made us a session leader still has the desired
        # process-group property. Verify it instead of silently weakening it.
        if os.getpgrp() != os.getpid():
            raise SecurityError("could not create isolated process group")


def _validate_component(name: str) -> None:
    if not name or name in {".", ".."} or "/" in name or "\x00" in name:
        raise SecurityError("unsafe path component")


def _verify_owned_directory(fd: int) -> None:
    st = os.fstat(fd)
    if not stat.S_ISDIR(st.st_mode):
        raise SecurityError("path component is not a directory")
    if st.st_uid != os.getuid():
        raise SecurityError("directory is not owned by current user")
    if st.st_mode & 0o022:
        raise SecurityError("directory is writable by group or others")


def canonical_home() -> str:
    entry = pwd.getpwuid(os.geteuid())
    path = os.path.abspath(entry.pw_dir)
    if not path or path == "/":
        raise SecurityError("invalid home directory")
    return path


def open_home() -> int:
    path = canonical_home()
    before = os.lstat(path)
    if stat.S_ISLNK(before.st_mode):
        raise SecurityError("home directory must not be a symlink")
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        _verify_owned_directory(fd)
    except Exception:
        os.close(fd)
        raise
    return fd


def open_dir_chain(components: Iterable[str], *, create: bool) -> int:
    current = open_home()
    try:
        for component in components:
            _validate_component(component)
            flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
            try:
                child = os.open(component, flags, dir_fd=current)
            except FileNotFoundError:
                if not create:
                    raise
                os.mkdir(component, 0o700, dir_fd=current)
                child = os.open(component, flags, dir_fd=current)
            try:
                _verify_owned_directory(child)
            except Exception:
                os.close(child)
                raise
            os.close(current)
            current = child
        return current
    except Exception:
        os.close(current)
        raise


def _existing_regular_file(dir_fd: int, name: str) -> os.stat_result | None:
    try:
        st = os.stat(name, dir_fd=dir_fd, follow_symlinks=False)
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(st.st_mode):
        raise SecurityError(f"refusing non-regular file: {name}")
    if st.st_uid != os.getuid():
        raise SecurityError(f"refusing file not owned by current user: {name}")
    return st


def read_file_at(dir_fd: int, name: str, max_bytes: int) -> bytes:
    st = _existing_regular_file(dir_fd, name)
    if st is None:
        raise FileNotFoundError(name)
    if st.st_size > max_bytes:
        raise SecurityError(f"file exceeds {max_bytes} byte limit")
    fd = os.open(name, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW, dir_fd=dir_fd)
    try:
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = os.read(fd, min(65536, max_bytes + 1 - total))
            if not chunk:
                break
            total += len(chunk)
            if total > max_bytes:
                raise SecurityError(f"file exceeds {max_bytes} byte limit")
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(fd)


def atomic_write_at(dir_fd: int, name: str, data: bytes, mode: int = 0o600) -> None:
    _validate_component(name)
    _existing_regular_file(dir_fd, name)
    temp = f".{name}.{os.getpid()}.{secrets.token_hex(8)}.tmp"
    fd = os.open(
        temp,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
        mode,
        dir_fd=dir_fd,
    )
    try:
        view = memoryview(data)
        offset = 0
        while offset < len(view):
            offset += os.write(fd, view[offset:])
        os.fsync(fd)
    except Exception:
        try:
            os.unlink(temp, dir_fd=dir_fd)
        except OSError:
            pass
        raise
    finally:
        os.close(fd)
    try:
        os.replace(temp, name, src_dir_fd=dir_fd, dst_dir_fd=dir_fd)
        os.fsync(dir_fd)
    except Exception:
        try:
            os.unlink(temp, dir_fd=dir_fd)
        except OSError:
            pass
        raise


def state_dir() -> int:
    return open_dir_chain((".config", "omarchy"), create=True)


def cache_dir() -> int:
    return open_dir_chain((".cache", "omarchy-omasports", "logos"), create=True)


def state_read() -> int:
    fd = state_dir()
    try:
        try:
            raw = read_file_at(fd, "sports-favorites.json", STATE_MAX_BYTES)
        except FileNotFoundError:
            raw = b""

        backed_up = False
        decoded = raw.decode("utf-8", errors="replace")
        if raw.strip():
            try:
                parsed = json.loads(decoded)
                if not isinstance(parsed, dict):
                    raise ValueError("state root must be an object")
            except (ValueError, json.JSONDecodeError):
                atomic_write_at(fd, "sports-favorites.json.corrupt", raw)
                backed_up = True

        envelope = {"data": decoded, "backedUp": backed_up, "home": canonical_home()}
        sys.stdout.write(json.dumps(envelope, ensure_ascii=False, separators=(",", ":")))
        return 0
    finally:
        os.close(fd)


def state_write(payload: str) -> int:
    raw = payload.encode("utf-8")
    if len(raw) > STATE_MAX_BYTES:
        raise SecurityError("state payload too large")
    parsed = json.loads(payload)
    if not isinstance(parsed, dict):
        raise SecurityError("state root must be a JSON object")
    fd = state_dir()
    try:
        atomic_write_at(fd, "sports-favorites.json", raw)
        return 0
    finally:
        os.close(fd)


class RestrictedRedirectHandler(urllib.request.HTTPRedirectHandler):
    def __init__(self, allowed_hosts: frozenset[str]):
        super().__init__()
        self.allowed_hosts = allowed_hosts

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: ANN001
        validate_https_url(newurl, self.allowed_hosts)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def validate_https_url(url: str, allowed_hosts: frozenset[str]) -> urllib.parse.SplitResult:
    if any(ord(ch) < 32 for ch in url):
        raise SecurityError("URL contains control characters")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.hostname.lower() not in allowed_hosts:
        raise SecurityError("URL host or scheme is not allowlisted")
    if parsed.username is not None or parsed.password is not None or parsed.port not in (None, 443):
        raise SecurityError("URL credentials or port are not allowed")
    return parsed


def fetch_bytes(
    url: str,
    *,
    allowed_hosts: frozenset[str],
    max_bytes: int,
    timeout: float,
    user_agent: str = "",
    no_cache: bool = False,
) -> bytes:
    if max_bytes <= 0 or max_bytes > FETCH_HARD_MAX_BYTES:
        raise SecurityError("invalid response byte limit")
    validate_https_url(url, allowed_hosts)
    headers = {"Accept": "*/*", "Connection": "close"}
    if user_agent:
        headers["User-Agent"] = user_agent
    if no_cache:
        headers["Cache-Control"] = "no-cache"
    request = urllib.request.Request(url, headers=headers, method="GET")
    opener = urllib.request.build_opener(RestrictedRedirectHandler(allowed_hosts))
    with opener.open(request, timeout=timeout) as response:
        final_url = response.geturl()
        validate_https_url(final_url, allowed_hosts)
        length = response.headers.get("Content-Length")
        if length:
            try:
                if int(length) > max_bytes:
                    raise SecurityError("response Content-Length exceeds byte limit")
            except ValueError:
                raise SecurityError("invalid response Content-Length") from None
        chunks: list[bytes] = []
        total = 0
        while True:
            chunk = response.read(min(65536, max_bytes + 1 - total))
            if not chunk:
                break
            total += len(chunk)
            if total > max_bytes:
                raise SecurityError("response exceeded byte limit")
            chunks.append(chunk)
        return b"".join(chunks)


def fetch_command(args: argparse.Namespace) -> int:
    raw = fetch_bytes(
        args.url,
        allowed_hosts=DATA_HOSTS,
        max_bytes=args.max_bytes,
        timeout=args.timeout,
        user_agent=args.user_agent or "",
        no_cache=args.no_cache,
    )
    sys.stdout.buffer.write(raw)
    return 0


def validate_png(data: bytes) -> tuple[int, int]:
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SecurityError("crest is not a PNG")
    offset = 8
    width = height = 0
    saw_ihdr = False
    saw_iend = False
    while offset + 12 <= len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        chunk_type = data[offset + 4 : offset + 8]
        chunk_end = offset + 12 + length
        if length > CREST_MAX_BYTES or chunk_end > len(data):
            raise SecurityError("invalid PNG chunk length")
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = int.from_bytes(data[offset + 8 + length : chunk_end], "big")
        actual_crc = zlib.crc32(chunk_type)
        actual_crc = zlib.crc32(payload, actual_crc) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise SecurityError("invalid PNG CRC")
        if not saw_ihdr:
            if chunk_type != b"IHDR" or length != 13:
                raise SecurityError("PNG must begin with IHDR")
            width = int.from_bytes(payload[0:4], "big")
            height = int.from_bytes(payload[4:8], "big")
            if not (1 <= width <= CREST_MAX_DIMENSION and 1 <= height <= CREST_MAX_DIMENSION):
                raise SecurityError("PNG dimensions exceed limit")
            if payload[10] != 0 or payload[11] != 0 or payload[12] not in (0, 1):
                raise SecurityError("unsupported PNG encoding")
            saw_ihdr = True
        if chunk_type == b"IEND":
            if length != 0 or chunk_end != len(data):
                raise SecurityError("invalid PNG terminator")
            saw_iend = True
            break
        offset = chunk_end
    if not saw_ihdr or not saw_iend:
        raise SecurityError("truncated PNG")
    return width, height


def _cache_metadata(url: str, data: bytes, width: int, height: int) -> bytes:
    meta = {
        "sha256": hashlib.sha256(data).hexdigest(),
        "source": url,
        "width": width,
        "height": height,
    }
    return (json.dumps(meta, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def validate_cached_entry(dir_fd: int, key: str) -> bool:
    if not KEY_RE.fullmatch(key):
        return False
    try:
        data = read_file_at(dir_fd, key + ".png", CREST_MAX_BYTES)
        width, height = validate_png(data)
        meta_raw = read_file_at(dir_fd, key + ".meta", 4096)
        meta = json.loads(meta_raw.decode("utf-8"))
        if not isinstance(meta, dict):
            return False
        if meta.get("sha256") != hashlib.sha256(data).hexdigest():
            return False
        if int(meta.get("width", 0)) != width or int(meta.get("height", 0)) != height:
            return False
        validate_https_url(str(meta.get("source", "")), CREST_HOSTS)
        return True
    except (OSError, ValueError, TypeError, json.JSONDecodeError, SecurityError):
        return False


def remove_cache_entry(dir_fd: int, key: str) -> None:
    for suffix in (".png", ".meta"):
        try:
            os.unlink(key + suffix, dir_fd=dir_fd)
        except FileNotFoundError:
            pass


def cache_scan() -> int:
    fd = cache_dir()
    try:
        valid: list[str] = []
        names = os.listdir(fd)[: MAX_CACHE_ENTRIES * 3]
        for name in names:
            if not name.endswith(".png"):
                continue
            key = name[:-4]
            if validate_cached_entry(fd, key):
                valid.append(key)
            else:
                remove_cache_entry(fd, key)
        sys.stdout.write("\n".join(sorted(valid)))
        if valid:
            sys.stdout.write("\n")
        return 0
    finally:
        os.close(fd)


def cache_evict(days: int) -> int:
    cutoff = max(1, days) * 86400
    now = __import__("time").time()
    fd = cache_dir()
    try:
        for name in os.listdir(fd)[: MAX_CACHE_ENTRIES * 3]:
            if not name.endswith(".png"):
                continue
            key = name[:-4]
            if not KEY_RE.fullmatch(key):
                continue
            try:
                st = os.stat(name, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                continue
            if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
                remove_cache_entry(fd, key)
                continue
            if now - st.st_mtime > cutoff:
                remove_cache_entry(fd, key)
        os.fsync(fd)
        return 0
    finally:
        os.close(fd)


@dataclass(frozen=True)
class CrestRequest:
    key: str
    url: str


def fetch_and_publish_crest(item: CrestRequest) -> str | None:
    if not KEY_RE.fullmatch(item.key):
        return None
    validate_https_url(item.url, CREST_HOSTS)
    raw = fetch_bytes(
        item.url,
        allowed_hosts=CREST_HOSTS,
        max_bytes=CREST_MAX_BYTES,
        timeout=15.0,
        user_agent="OmaSports/1.4",
    )
    width, height = validate_png(raw)
    meta = _cache_metadata(item.url, raw, width, height)
    fd = cache_dir()
    try:
        atomic_write_at(fd, item.key + ".png", raw)
        atomic_write_at(fd, item.key + ".meta", meta)
        return item.key
    finally:
        os.close(fd)


def crest_batch(values: list[str]) -> int:
    if len(values) % 2 != 0:
        raise SecurityError("crest batch requires key/url pairs")
    pairs = [CrestRequest(values[i], values[i + 1]) for i in range(0, min(len(values), 128), 2)]
    succeeded: list[str] = []
    failed: list[str] = []

    def run(item: CrestRequest) -> tuple[str, bool]:
        try:
            return item.key, fetch_and_publish_crest(item) is not None
        except Exception:
            return item.key, False

    with concurrent.futures.ThreadPoolExecutor(max_workers=8, thread_name_prefix="crest") as pool:
        for key, ok in pool.map(run, pairs):
            (succeeded if ok else failed).append(key)

    sys.stdout.write(json.dumps({"ok": succeeded, "failed": failed}, separators=(",", ":")))
    return 0


def exec_tool(tool: str, args: list[str]) -> int:
    executable = ALLOWED_TOOLS.get(tool)
    if executable is None:
        raise SecurityError("tool is not allowlisted")
    st = os.stat(executable, follow_symlinks=True)
    if not stat.S_ISREG(st.st_mode) or st.st_uid != 0 or not (st.st_mode & stat.S_IXUSR):
        raise SecurityError("tool executable failed trust check")
    os.execve(executable, [executable, *args], dict(os.environ))
    return 127


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    sub = parser.add_subparsers(dest="command", required=True)

    fetch = sub.add_parser("fetch", add_help=False)
    fetch.add_argument("--url", required=True)
    fetch.add_argument("--max-bytes", type=int, required=True)
    fetch.add_argument("--timeout", type=float, default=12.0)
    fetch.add_argument("--user-agent", default="")
    fetch.add_argument("--no-cache", action="store_true")

    sub.add_parser("state-read", add_help=False)

    write = sub.add_parser("state-write", add_help=False)
    write.add_argument("payload")

    sub.add_parser("cache-scan", add_help=False)

    evict = sub.add_parser("cache-evict", add_help=False)
    evict.add_argument("days", type=int)

    crests = sub.add_parser("crest-batch", add_help=False)
    crests.add_argument("pairs", nargs="*")

    tool = sub.add_parser("exec-tool", add_help=False)
    tool.add_argument("tool", choices=sorted(ALLOWED_TOOLS))
    tool.add_argument("args", nargs=argparse.REMAINDER)
    return parser


def main(argv: list[str]) -> int:
    become_process_group_leader()
    args = build_parser().parse_args(argv)
    if args.command == "fetch":
        return fetch_command(args)
    if args.command == "state-read":
        return state_read()
    if args.command == "state-write":
        return state_write(args.payload)
    if args.command == "cache-scan":
        return cache_scan()
    if args.command == "cache-evict":
        return cache_evict(args.days)
    if args.command == "crest-batch":
        return crest_batch(args.pairs)
    if args.command == "exec-tool":
        return exec_tool(args.tool, args.args)
    raise SecurityError("unsupported command")


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (SecurityError, OSError, urllib.error.URLError, json.JSONDecodeError, ValueError) as exc:
        sys.stderr.write(f"omasports secure I/O: {exc}\n")
        raise SystemExit(1)
