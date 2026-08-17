#!/usr/bin/env python3
"""codex_audit_to_json.py — codex JSONL을 plugin-audit이 소비하는 shape으로.

층④에 plugin-audit 몫이 비어 있었다: `assemble-audit-data.py`가 `--codex-side <json>`을
요구하는데 그것을 만드는 코드가 없어, 지금까지는 모델이 산문 지시를 읽고 손으로 만들었다.

형제 추출기(qg/sd `codex_findings_to_yaml.py`)의 기성 규약을 따른다:
  - 마지막 agent_message 채택
  - **마지막** fenced block 채택 — 감사 대상 파일이 앞선 fence를 심어도 이긴다
  - 스키마 검증은 성공 마커를 찍기 **전에** 한다 (indeterminate ≠ clean)
  - degrade는 `meta.codex_failed` + `meta.reason` (최상위 아님 — 새 코드의 규약)

소비자가 둘이다: `findings`는 `audit-workflow.js`의 `codexFindings`로,
나머지 셋은 `assemble-audit-data.py --codex-side`로 간다. 이 스크립트는 넷을 모두 내고
라우팅은 SKILL이 한다.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from typing import Any

# 이 파일은 심볼릭 링크가 아니라 실제 파일이므로 sys.path[0]이 이미
# plugins/plugin-audit/scripts/다 — sibling copy-of 사본(codex_jsonl.py)이 그대로
# 잡힌다. 그래도 .resolve()로 통일한다: 이 파일 자체가 나중에 다른 방식으로 실행되는
# 경우(symlink 경유 등)에도 항상 자기 디렉토리를 가리키게 하기 위함이다.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from codex_jsonl import extract_last_agent_message  # noqa: E402

COLLECTIONS = ("findings", "d_verdicts", "oq_answers", "new_open_questions")

AUTH_ERROR_RE = re.compile(
    r"(401|403|unauthorized|forbidden|not logged in|codex login|"
    r"authentication|invalid[_ ]api[_ ]key)", re.IGNORECASE)

FENCE_RE = re.compile(r"```(?:json)?\s*\n(.*?)\n```", re.DOTALL)


def parse_payload(msg: str) -> Any:
    """fenced JSON → raw JSON 순으로 시도. fence는 **마지막** 블록을 취한다."""
    blocks = FENCE_RE.findall(msg)
    if blocks:
        try:
            return json.loads(blocks[-1])
        except json.JSONDecodeError:
            pass
    try:
        return json.loads(msg.strip())
    except json.JSONDecodeError:
        return None


def validate_collections(payload: dict) -> tuple[dict[str, list], dict[str, Any]]:
    """구조 검증(컨테이너 타입 + 원소 타입)을 **성공 마커를 찍기 전에** 한다.

    필드 단위 완전성까지 올리지 않는 이유는 형제 추출기와 같다: 서술 필드 하나가 빠진
    정상 라운드를 degrade로 올리면 진짜 발견이 소실된다.

    E2 (/qg 2026-08-13 whole-branch 리뷰): **키 존재**는 컨테이너 타입과 같은 층이다.
    이전 코드는 `payload.get(key, [])` + `raw is None` 으로 키 부재와 명시적 null 을
    조용히 `[]` 로 만들고 `codex_failed: False` 를 찍었다 — 즉 `{}` 페이로드가 clean
    감사로 기록됐다. 이 프롬프트가 동봉하는 preamble 은 "어떤 키도 생략하지 말라"를
    계약하고(codex-prompt-preamble.md), 형제 `codex_findings_to_yaml.py:181,219` 는
    같은 입력을 malformed_json/schema_mismatch 로 거부한다. 원소 단위 관용은 그대로.
    """
    out: dict[str, list] = {}
    missing_keys: list[str] = []
    bad_container: list[str] = []
    bad_elements: dict[str, list[str]] = {}
    for key in COLLECTIONS:
        if key not in payload or payload[key] is None:
            missing_keys.append(key)
            out[key] = []
            continue
        raw = payload[key]
        if not isinstance(raw, list):
            # dict / str / int — 계약된 컨테이너가 아니다. 읽을 것이 없다.
            bad_container.append(f"{key}:{type(raw).__name__}")
            out[key] = []
            continue
        out[key] = [x for x in raw if isinstance(x, dict)]
        bad = sorted({type(x).__name__ for x in raw if not isinstance(x, dict)})
        if bad:
            bad_elements[key] = bad

    meta: dict[str, Any] = {}
    if missing_keys or bad_container or bad_elements:
        meta["codex_failed"] = True
        meta["reason"] = "schema_mismatch"
        if missing_keys:
            meta["missing_keys"] = ",".join(sorted(missing_keys))
        if bad_container:
            meta["bad_containers"] = ",".join(bad_container)
            # 형제 추출기와 같은 이름으로 findings 컨테이너 타입을 별도로 노출한다.
            raw_f = payload.get("findings", [])
            if not isinstance(raw_f, list):
                meta["raw_findings_type"] = type(raw_f).__name__
        if bad_elements:
            meta["bad_element_types"] = ",".join(
                sorted({t for ts in bad_elements.values() for t in ts}))
            meta["bad_element_keys"] = ",".join(sorted(bad_elements))
    else:
        meta["codex_failed"] = False
    return out, meta


def emit(collections: dict[str, list], meta: dict) -> str:
    doc: dict[str, Any] = {k: collections.get(k, []) for k in COLLECTIONS}
    doc["meta"] = meta
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stderr-file", default=None)
    ap.add_argument("--meta-override-exit-code", type=int, default=None)
    ap.add_argument("--meta-override-reason", default=None)
    args = ap.parse_args()

    stdin_text = sys.stdin.read()
    stderr_text = ""
    stderr_read_error: str | None = None
    if args.stderr_file:
        try:
            with open(args.stderr_file, "r", encoding="utf-8", errors="replace") as fh:
                stderr_text = fh.read()
        except OSError as e:
            stderr_read_error = str(e.errno) if e.errno else type(e).__name__

    def apply_overrides(meta: dict) -> dict:
        if args.meta_override_exit_code is not None:
            meta["exit_code"] = args.meta_override_exit_code
        # 빈 문자열은 셸에서 오는 "override 없음"이다 — 덮어쓰지 않는다.
        if args.meta_override_reason:
            meta["reason"] = args.meta_override_reason
            meta["codex_failed"] = True
        if stderr_read_error is not None:
            meta["stderr_read_error"] = stderr_read_error
        return meta

    empty = {k: [] for k in COLLECTIONS}
    has_auth_error = bool(stderr_text and AUTH_ERROR_RE.search(stderr_text))

    last_msg, any_parsed = extract_last_agent_message(stdin_text)
    if last_msg is None:
        if has_auth_error:
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        elif stdin_text.strip() and not any_parsed:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": stdin_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "missing_result", "exit_code": 0}
        sys.stdout.write(emit(empty, apply_overrides(meta)))
        return 0

    payload = parse_payload(last_msg)
    if not isinstance(payload, dict):
        if has_auth_error:
            meta = {"codex_failed": True, "reason": "auth_error_in_stderr",
                    "exit_code": 0, "stderr_preview": stderr_text[:200]}
        else:
            meta = {"codex_failed": True, "reason": "malformed_json",
                    "exit_code": 0, "raw_text_preview": last_msg[:200]}
        sys.stdout.write(emit(empty, apply_overrides(meta)))
        return 0

    collections, meta = validate_collections(payload)
    meta.setdefault("exit_code", 0)
    sys.stdout.write(emit(collections, apply_overrides(meta)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
