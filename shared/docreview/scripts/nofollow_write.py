#!/usr/bin/env python3
"""마지막 경로 성분의 링크를 따라가지 않고 파일을 쓴다.

모드:
  run --out P -- <명령...>   명령의 stdout 을 P 옆 임시 파일에 받아 P 로 놓는다. 명령 rc 를 그대로 낸다.
  empty --out P              P 를 빈 일반 파일로 만든다.
  append --out P             stdin 을 P 끝에 덧붙인다(없으면 만든다).

writer 자신의 실패는 rc 73 과 stderr 한 줄 `[nofollow_write] <사유> — <P>` 로 낸다. 그때 P 는 그대로다.
"""
import os
import stat
import subprocess
import sys
import tempfile

EXIT_SELF = 73
EXIT_NOT_FOUND = 127


class WriterError(Exception):
    """writer 자신의 실패(인자 오류 포함)."""


def _umask():
    mask = os.umask(0)
    os.umask(mask)
    return mask


def _new_temp(path):
    """P 옆에 O_EXCL · O_NOFOLLOW 임시 파일을 만든다. (fd, 경로) 를 낸다."""
    folder = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(
        dir=folder, prefix="." + os.path.basename(path) + ".", suffix=".tmp"
    )
    try:
        os.fchmod(fd, 0o666 & ~_umask())
    except OSError:
        os.close(fd)
        _drop(tmp)
        raise
    return fd, tmp


def _drop(tmp):
    try:
        os.unlink(tmp)
    except OSError:
        pass


def replace_bytes(path, data):
    """data 를 임시 파일에 쓰고 os.replace 로 path 에 놓는다. 실패하면 OSError."""
    fd, tmp = _new_temp(path)
    try:
        try:
            view = memoryview(data)
            while len(view):
                view = view[os.write(fd, view):]
        finally:
            os.close(fd)
        os.replace(tmp, path)
    except BaseException:
        _drop(tmp)
        raise


def _run(path, argv):
    fd, tmp = _new_temp(path)
    try:
        try:
            try:
                rc = subprocess.run(argv, stdout=fd).returncode
            except (FileNotFoundError, PermissionError):
                rc = EXIT_NOT_FOUND
        finally:
            os.close(fd)
        os.replace(tmp, path)
    except BaseException:
        _drop(tmp)
        raise
    return rc if rc >= 0 else 128 - rc


def _truncate_in_place(path):
    fd = os.open(path, os.O_WRONLY | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise WriterError("링크라서 자르지 않는다")
        os.ftruncate(fd, 0)
    finally:
        os.close(fd)


def _empty(path):
    try:
        replace_bytes(path, b"")
    except OSError:
        _truncate_in_place(path)


def _append(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o666)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise WriterError("링크라서 덧붙이지 않는다")
        view = memoryview(data)
        while len(view):
            view = view[os.write(fd, view):]
    finally:
        os.close(fd)


def _parse(args):
    if not args:
        raise WriterError("모드가 없다")
    mode = args[0]
    if mode not in ("run", "empty", "append"):
        raise WriterError("모르는 모드 " + mode)
    rest = args[1:]
    if len(rest) < 2 or rest[0] != "--out":
        raise WriterError("--out 경로가 없다")
    out = rest[1]
    rest = rest[2:]
    if mode == "run":
        if not rest or rest[0] != "--" or len(rest) < 2:
            raise WriterError("run 에는 -- 와 명령이 필요하다")
        return mode, out, rest[1:]
    if rest:
        raise WriterError("남는 인자가 있다")
    return mode, out, []


def main(args):
    out = "-"
    try:
        mode, out, argv = _parse(args)
        if mode == "run":
            return _run(out, argv)
        if mode == "empty":
            _empty(out)
        else:
            _append(out, sys.stdin.buffer.read())
        return 0
    except Exception as exc:  # 자기 실패는 전부 한 rc 로 낸다
        reason = str(exc) or exc.__class__.__name__
        try:
            sys.stderr.write("[nofollow_write] %s — %s\n" % (reason, out))
        except Exception:
            pass
        return EXIT_SELF


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
