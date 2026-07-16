#!/usr/bin/env python3
"""classify_artifact_target.py — E1 code/non-code/ambiguous classifier (§6 E1, AC15/AC22).

Deterministic, path-string based (+ os.path.isdir for real directories).
Exit 0 always. Emits:
    classification: code | non_code | ambiguous
    reason: <str>
Fail-safe: any extension not in either fixed list -> ambiguous, so code never
auto-enters the write loop without an explicit confirmation upstream.
"""
import os
import sys

# UX 편의용 코드 확장자 (완전할 필요 없음 — 미포함은 fail-safe ambiguous 분기로).
CODE_EXTS = {
    "py", "js", "ts", "tsx", "jsx", "mjs", "cjs", "go", "rs", "java", "kt", "kts",
    "c", "h", "cpp", "cc", "cxx", "hpp", "hh", "cs", "rb", "php", "swift", "scala",
    "sh", "bash", "zsh", "pl", "pm", "lua", "dart", "m", "mm", "sql", "r",
    "groovy", "gradle",
}
# 비-코드는 고정 목록 (개방형 절 없음 — 스펙 §6 E1).
NONCODE_EXTS = {"md", "markdown", "txt", "rst", "adoc", "org"}


def classify(path):
    # 디렉터리(실존) 또는 trailing slash -> 모호.
    if path.endswith("/") or os.path.isdir(path):
        return "ambiguous", "directory"
    base = os.path.basename(path.rstrip("/"))
    if "." not in base:
        return "ambiguous", "no_extension"
    ext = base.rsplit(".", 1)[1].lower()  # 복합 확장자 -> 마지막 세그먼트 (.tar.gz -> gz)
    if ext in CODE_EXTS:
        return "code", f"code_extension:{ext}"
    if ext in NONCODE_EXTS:
        return "non_code", f"noncode_extension:{ext}"
    return "ambiguous", f"unlisted_extension:{ext}"


def main():
    if len(sys.argv) != 2:
        print("classification: ambiguous")
        print("reason: missing_arg")
        return 0
    c, r = classify(sys.argv[1])
    print(f"classification: {c}")
    print(f"reason: {r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
