"""docreview_config.py — 엔진 값(탐지 수 · 재리뷰 상한 · 조언 줄 수 · 요약 폭)을 한 곳에서 푼다 (leaf 모듈).

순서는 기본 < 프로필 < 진입 < 환경 — 뒤가 이긴다. 진입 선언은 탐지 수에만 있다(`begin-round --detectors`).
값이 정수가 아니거나 최솟값보다 작으면 `ConfigInvalid` — 부르는 쪽이 라운드를 시작하지 않는다.
표준 라이브러리만 쓴다. 파일 · 환경을 직접 읽지 않고 인자로 받는다(테스트가 주입한다).
엔진이 쓰는 줄의 글 도우미(`one_line_field` · `table_cell`)도 여기 있다.
"""
from __future__ import annotations

import re
import unicodedata

DEFAULTS = {"detectors": 1, "rereview_cap": 2, "render_cap": 8, "summary_width": 60}
ENV = {"detectors": "DEVBREW_DOCREVIEW_DETECTORS", "rereview_cap": "DEVBREW_DOCREVIEW_REREVIEW_CAP",
       "render_cap": "DEVBREW_DOCREVIEW_RENDER_CAP", "summary_width": "DEVBREW_DOCREVIEW_SUMMARY_WIDTH"}
MINIMUM = {"detectors": 1, "rereview_cap": 0, "render_cap": 1, "summary_width": 1}
PROFILE_KEYS = ("rereview_cap", "render_cap", "summary_width")   # `detectors` 는 필수 필드라 따로 있다


class ConfigInvalid(Exception):
    def __init__(self, name, raw, where):
        super().__init__("%s=%r" % (name, raw))
        self.name, self.raw, self.where = name, raw, where


_ENV_INT = re.compile(r"[0-9]+")   # ASCII 숫자만 — 「1_0」 · 유니코드 숫자 · 부호 · 공백은 거부한다


def _int(name, raw, where):
    """환경 값은 글자 그대로 ASCII 숫자만(앞뒤 공백도 거부), 프로필 · 진입 값은 정수형(bool · 문자열 거부)."""
    if isinstance(raw, bool):
        raise ConfigInvalid(name, raw, where)
    if where.startswith("환경"):
        if not isinstance(raw, str) or not _ENV_INT.fullmatch(raw):
            raise ConfigInvalid(name, raw, where)
        v = int(raw, 10)
    elif isinstance(raw, int):
        v = raw
    else:
        raise ConfigInvalid(name, raw, where)
    if v < MINIMUM[name]:
        raise ConfigInvalid(name, raw, where)
    return v


def resolve(prof, entry, env) -> dict:
    out = {}
    for k, dv in DEFAULTS.items():
        val, src = dv, "기본"
        if k in prof and prof[k] is not None:
            val, src = _int(k, prof[k], "프로필"), "프로필"
        if k in (entry or {}) and entry[k] is not None:
            val, src = _int(k, entry[k], "진입"), "진입"
        raw = env.get(ENV[k])
        if raw is not None and raw != "":
            val, src = _int(k, raw, "환경 " + ENV[k]), "환경"
        out[k] = {"value": val, "source": src}
    return out


def _pick(cfg, k):
    return (cfg or {}).get(k) or {"value": DEFAULTS[k], "source": "기본"}   # 옛 원장은 config 가 없다 — 기본값으로 읽는다


def config_line(cfg) -> str:
    """게이트 둘째 줄의 꼬리 — 탐지 수 · 조언 줄 수 · 요약 폭과 각 출처. 재리뷰 상한은 앞 마디가 직접 낸다."""
    d, r, w = _pick(cfg, "detectors"), _pick(cfg, "render_cap"), _pick(cfg, "summary_width")
    return "탐지 리뷰어 %d명(%s) · 참고 목록 %d줄(%s) · 요약 %d자(%s)" % (
        d["value"], d["source"], r["value"], r["source"], w["value"], w["source"])

def advice_note(cap, cap_src, width, width_src) -> str:
    """조언 표시 머리 줄의 꼬리 — 실제로 쓴 줄 수 · 요약 폭과 출처."""
    return "참고 목록 %d줄(%s) · 요약 %d자(%s)" % (cap, cap_src, width, width_src)


_BREAKS = re.compile("[\\n\\r\\x0b\\x0c\\x1c\\x1d\\x1e\\x85\\u2028\\u2029]")


def one_line_field(s) -> str:
    """엔진이 쓰는 줄의 한 칸 — 줄 구분자 · 제어 · 서식 문자를 공백으로, 공백 연속을 하나로, 앞뒤 공백을 걷는다.
    칸 값은 줄 머리에 올 수 없다(엔진이 늘 자기 머리로 줄을 연다) — 칸 안의 목록 · 제목 · 인용 표지는 그 줄 안의
    글자일 뿐이다(AC15)."""
    t = _BREAKS.sub(" ", str(s if s is not None else ""))
    t = "".join(" " if unicodedata.category(ch) in ("Cc", "Cf", "Zl", "Zp") else ch for ch in t)
    return " ".join(t.split())


def table_cell(s) -> str:
    """표 행의 한 칸 — `one_line_field` 에 `|` 이스케이프(칸 · 행을 늘리지 못하게)."""
    return one_line_field(s).replace("|", "\\|")
