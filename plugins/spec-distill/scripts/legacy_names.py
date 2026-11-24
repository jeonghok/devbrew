"""새 글자와 옛 글자의 대응. 표준 라이브러리만 쓴다.

쓰는 쪽은 새 글자만, 읽는 쪽은 `kind_matches` · `source_of` · `seed_topic` 같은
함수로 옛 글자도 받는다.
"""
from __future__ import annotations

import re

INTENT_SEED = "intent-seed"
INTENT_SEED_AUDIT = "intent-seed-audit"
CONTEXT_STATE = "context-state"
CONTEXT_BRIEF = "context-brief"
CONTEXT_AUDIT = "context-audit"
HEAD_KEY = "source_intent"
SETTING_KEY = "intent_dir"
DEFAULT_DIR = "docs/superpowers/intent/"
SEED_TAIL = "-intent"
CONTEXT_TAIL = "-context"

OLD_KIND: dict[str, str] = {
    INTENT_SEED: "interview-seed",
    INTENT_SEED_AUDIT: "interview-seed-audit",
    CONTEXT_STATE: "interview-state",
    CONTEXT_BRIEF: "interview-brief",
    CONTEXT_AUDIT: "interview-audit",
}
OLD_HEAD_KEY = "source_interview"
OLD_SETTING_KEY = "interview_dir"
OLD_DEFAULT_DIR = "docs/superpowers/interview/"
OLD_TAIL = "-interview"

_DATE = r"\d{4}-\d{2}-\d{2}"
_OLD_NAME = re.compile(r".*" + re.escape(OLD_TAIL) + r"(?:\.state|\.audit)?\.md", re.DOTALL)
_SEED = re.compile(
    _DATE + r"-([a-z0-9]+(?:-[a-z0-9]+)*)(?:" + re.escape(SEED_TAIL) + "|" + re.escape(OLD_TAIL) + r")\.md"
)
_SEED_AUDIT = re.compile(
    _DATE + r"-(.+)(?:" + re.escape(SEED_TAIL) + "|" + re.escape(OLD_TAIL) + r")\.audit\.md"
)


def kind_matches(have: str | None, new_kind: str) -> bool:
    return bool(have) and have in kinds(new_kind)


def kinds(new_kind: str) -> tuple[str, str]:
    return (new_kind, OLD_KIND[new_kind])


def source_of(fm: dict) -> str:
    return fm.get(HEAD_KEY) or fm.get(OLD_HEAD_KEY) or ""


def head_keys() -> tuple[str, str]:
    return (HEAD_KEY, OLD_HEAD_KEY)


def state_suffixes() -> tuple[str, str]:
    return (CONTEXT_TAIL + ".state.md", OLD_TAIL + ".state.md")


def is_old_name(name: str) -> bool:
    return _OLD_NAME.fullmatch(name) is not None


def seed_topic(name: str) -> str | None:
    m = _SEED.fullmatch(name)
    return m.group(1) if m else None


def seed_audit_topic(name: str) -> str | None:
    m = _SEED_AUDIT.fullmatch(name)
    return m.group(1) if m else None


def roadmap_folder_name(brief_name: str) -> str | None:
    for tail in (CONTEXT_TAIL, OLD_TAIL):
        if brief_name.endswith(tail + ".md"):
            return brief_name[: -len(".md") - len(tail)]
    return None


def siblings(brief: str) -> tuple[str, str]:
    if not brief.endswith(".md"):
        raise ValueError(f"not a .md path: {brief}")
    return (brief[:-3] + ".audit.md", brief[:-3] + ".state.md")


def setting_notice(old_value: str, new_value: str | None) -> str:
    if new_value is None:
        return (f"레포 설정의 {OLD_SETTING_KEY} 는 이름이 {SETTING_KEY} 로 바뀌었다 — "
                f"값({old_value})을 그대로 읽는다. 키 이름을 {SETTING_KEY} 로 바꾼다")
    return (f"레포 설정에 {SETTING_KEY} 와 옛 키 {OLD_SETTING_KEY} 가 함께 있다 — "
            f"{SETTING_KEY}({new_value})에 새 기록을 쓰고 "
            f"{OLD_SETTING_KEY}({old_value})는 옛 기록을 읽는 폴더로만 쓴다")
