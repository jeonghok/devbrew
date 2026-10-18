"""docreview_config.py — 엔진 값(탐지 수 · 재리뷰 상한 · 조언 줄 수 · 요약 폭)을 한 곳에서 푼다 (leaf 모듈).

순서는 기본 < 프로필 < 진입 < 환경 — 뒤가 이긴다. 진입 선언은 탐지 수에만 있다(`begin-round --detectors`).
값이 정수가 아니거나 최솟값보다 작으면 `ConfigInvalid` — 부르는 쪽이 라운드를 시작하지 않는다.
표준 라이브러리만 쓴다. 파일 · 환경을 직접 읽지 않고 인자로 받는다(테스트가 주입한다).
"""
from __future__ import annotations

DEFAULTS = {"detectors": 1, "rereview_cap": 2, "render_cap": 8, "summary_width": 60}
ENV = {"detectors": "DEVBREW_DOCREVIEW_DETECTORS", "rereview_cap": "DEVBREW_DOCREVIEW_REREVIEW_CAP",
       "render_cap": "DEVBREW_DOCREVIEW_RENDER_CAP", "summary_width": "DEVBREW_DOCREVIEW_SUMMARY_WIDTH"}
MINIMUM = {"detectors": 1, "rereview_cap": 0, "render_cap": 1, "summary_width": 1}
PROFILE_KEYS = ("rereview_cap", "render_cap", "summary_width")   # `detectors` 는 필수 필드라 따로 있다


class ConfigInvalid(Exception):
    def __init__(self, name, raw, where):
        super().__init__("%s=%r" % (name, raw))
        self.name, self.raw, self.where = name, raw, where


def _int(name, raw, where):
    if isinstance(raw, bool):
        raise ConfigInvalid(name, raw, where)
    try:
        v = int(str(raw).strip(), 10)
    except (TypeError, ValueError):
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


def config_line(cfg) -> str:
    """게이트 둘째 줄의 꼬리 — 탐지 수와 그 출처. 재리뷰 상한은 앞 마디가 직접 낸다."""
    d = cfg.get("detectors") or {"value": DEFAULTS["detectors"], "source": "기본"}
    return "탐지 리뷰어 %d명(%s)" % (d["value"], d["source"])
