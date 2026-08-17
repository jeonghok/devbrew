#!/usr/bin/env python3
"""codex_findings_to_yaml.py — Convert Codex JSONL stream to finding YAML.

Spec AC3. Three-stage fallback chain on the last agent_message text:
  1. Fenced JSON code block
  2. Raw JSON parse
  3. Fallback: empty findings + meta.reason: malformed_json

Auth-error detection: if stderr contains an auth-failure pattern AND no
findings extracted, emit meta.reason: auth_error_in_stderr.

Event shape (Codex 0.130+, discovered in Task 0 spike):
  {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
Legacy shape (still supported as fallback):
  {"type":"agent_message","text":"..."} or {"type":"agent_message","message":"..."}

정본화 이전 이력(2026-08 무게 감축이 닫는 결함의 근거): quality-gates·spec-distill
두 사본은 2026-05-14 이후 갈라져 있었다. "ONLY adaptation"(emit keyset 하나뿐)이라는
옛 주장은 거짓이었다 — 2026-07-29 CR-2 스키마 검증이 spec-distill 사본에만 들어가
판정이 갈라졌다: qg 사본은 그때까지 `{"findings": {}}`에 `codex_failed: false`를
내고 있었다 — 실행되지 못한 검사가 통과한 검사로 기록되는 결함이었다. 두 사본의
행동 동일성은 그 이후 `quality-gates/tests/test_codex_copies_agree.sh`가 재고
있었다. 이 파일로 정본화된 뒤로는 emit keyset(`--emit-keys`)만 호출자가 정하는
유일한 의도된 차이다.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from typing import Any

# .resolve() 를 쓰지 않는다(bare .parent) — 2026-08-17 fix round 1, CRIT-1.
# `claude plugin install` 은 플러그인 서브트리를 벗어나는 심볼릭 링크를 설치 시점에
# 실제 파일로 역참조한다(설계 §16.1). 그러면 설치본의
# plugins/<p>/scripts/codex_findings_to_yaml.py 는 심볼릭 링크가 아니라 **일반
# 파일**이고, `.resolve()`는 자기 자신을 가리켜 아무것도 바뀌지 않는다 — 즉
# `sys.path[0]`은 그 파일 자신의 디렉토리(plugins/<p>/scripts/)가 된다. 그래서
# sibling `codex_jsonl.py`의 **copy-of 물리 사본**을 세 배포 디렉토리
# (plugin-audit·quality-gates·spec-distill의 scripts/) 전부에 둔다.
#
# 리포 안에서 실측(macOS python 3.9.6): `python3 <경로>`로 실행하면 `__file__`은
# 심볼릭 링크를 따라가지 않은 **그대로의 경로**다 — bare `.parent`는 배포
# 지점(plugins/<p>/scripts/)을 낸다. `.resolve()`를 쓰면 링크를 따라가 이 정본
# 파일의 실제 디렉토리(shared/codex/)를 내므로, 리포에서 심볼릭 링크를 태우는 테스트가
# 정본 옆의 codex_jsonl.py만 읽고 **배포 지점 옆의 copy-of 사본은 한 번도 실행하지
# 않는다** — 그 사본이 곧 설치본에 실제로 배포되는 파일인데도. bare `.parent`를
# 쓰면 리포 실행이 배포 지점 옆 사본을 읽으므로 리포 테스트가 곧 배포본 테스트가
# 된다(설치본에는 애초에 링크가 없으므로 두 표기가 같아진다).
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from codex_jsonl import extract_last_agent_message  # noqa: E402

AUTH_ERROR_RE = re.compile(
    r"(authentication|auth\s+(failed|error)|invalid\s+(api[\s_]?key|token)"
    r"|401|403|forbidden|unauthor|credential|quota|billing|subscription|expired)",
    re.IGNORECASE,
)
FENCED_JSON_RE = re.compile(r"```json\s*\n(.*?)\n?```", re.DOTALL)

# emit keyset 은 호출자가 정한다. 이 스크립트는 호출자만 실행하므로 인자 방식이 맞다
# (형제 설정 파일이 필요한 detect_codex.sh 와 다른 이유는 설계 §6.1① 표 참조 —
# 그쪽은 기존 락이 **인자 없이** 태우며 kill switch 반응을 검사한다).
DEFAULT_KEYS = ("file", "line", "severity", "confidence", "summary", "proposed_fix")
DESIGN_KEYS = ("file", "line", "category", "target_section",
               "severity", "confidence", "summary", "proposed_fix")


def parse_fenced_json(text: str) -> dict | None:
    matches = re.findall(FENCED_JSON_RE, text)
    if not matches:
        return None
    # AC9(b): pick LAST block to defeat adversarial diff-injected earlier blocks.
    try:
        return json.loads(matches[-1])
    except json.JSONDecodeError:
        return None


def parse_raw_json(text: str) -> dict | None:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def yaml_emit(findings: list[dict], meta: dict, keys: tuple[str, ...] = DEFAULT_KEYS) -> str:
    out: list[str] = []
    if not findings:
        out.append("findings: []")
    else:
        out.append("findings:")
        for f in findings:
            out.append("  - agent: codex-reviewer")
            for k in keys:
                if k in f:
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    out.append("meta:")
    for k, v in meta.items():
        out.append(f"  {k}: {_yaml_scalar(v)}")
    return "\n".join(out) + "\n"


def _yaml_scalar(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s)
    return s


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--stderr-file", default=None)
    p.add_argument("--meta-override-exit-code", type=int, default=None)
    p.add_argument("--meta-override-reason", default=None)
    p.add_argument("--emit-keys", default="default", choices=("default", "design"),
                    help="emit keyset. design = category/target_section 추가 (design-doc 리뷰 어휘)")
    args = p.parse_args()
    keys = DESIGN_KEYS if args.emit_keys == "design" else DEFAULT_KEYS

    stdin_text = sys.stdin.read()
    stderr_text = ""
    _stderr_read_error: str | None = None
    if args.stderr_file:
        try:
            with open(args.stderr_file, "r", encoding="utf-8", errors="replace") as fh:
                stderr_text = fh.read()
        except OSError as e:
            stderr_text = ""
            _stderr_read_error = str(e.errno) if e.errno else type(e).__name__

    def has_auth_error() -> bool:
        return bool(stderr_text and AUTH_ERROR_RE.search(stderr_text))

    def apply_overrides(meta: dict) -> dict:
        # Apply exit-code override unconditionally if supplied (caller knows the real exit code).
        if args.meta_override_exit_code is not None:
            meta["exit_code"] = args.meta_override_exit_code
        # Apply reason override only if non-empty (empty string from shell = no override).
        if args.meta_override_reason:
            meta["reason"] = args.meta_override_reason
            meta["codex_failed"] = True
        # AC9(d): surface stderr file read errors for caller visibility.
        if _stderr_read_error is not None:
            meta["stderr_read_error"] = _stderr_read_error
        return meta

    last_msg, any_jsonl_parsed = extract_last_agent_message(stdin_text)

    if last_msg is None:
        if has_auth_error():
            meta = {
                "codex_failed": True,
                "reason": "auth_error_in_stderr",
                "exit_code": 0,
                "stderr_preview": stderr_text[:200],
            }
        elif stdin_text.strip() and not any_jsonl_parsed:
            # Non-empty stdin with zero parseable JSONL lines → Stage 3 fallback.
            meta = {
                "codex_failed": True,
                "reason": "malformed_json",
                "exit_code": 0,
                "raw_text_preview": stdin_text[:200],
            }
        else:
            meta = {"codex_failed": True, "reason": "missing_result", "exit_code": 0}
        sys.stdout.write(yaml_emit([], apply_overrides(meta), keys))
        return 0

    parsed = parse_fenced_json(last_msg)
    if parsed is None:
        parsed = parse_raw_json(last_msg.strip())

    if parsed is None or not isinstance(parsed, dict) or "findings" not in parsed:
        if has_auth_error():
            meta = {
                "codex_failed": True,
                "reason": "auth_error_in_stderr",
                "exit_code": 0,
                "stderr_preview": stderr_text[:200],
            }
        else:
            meta = {
                "codex_failed": True,
                "reason": "malformed_json",
                "exit_code": 0,
                "raw_text_preview": last_msg[:200],
            }
        sys.stdout.write(yaml_emit([], apply_overrides(meta), keys))
        return 0

    raw_findings = parsed.get("findings", [])

    # --- CR-2: 스키마 검증은 성공 마커를 찍기 **전에** 한다 -------------------
    # 이전 구현은 non-list `findings`를 조용히 `[]`로 강등하면서 `codex_failed:
    # false`를 함께 찍었다. 소비자는 그 마커를 성공으로 읽으므로, 스키마가 깨진
    # codex 실행이 **findings 0건 + degradation record 0건**으로 흡수됐다 —
    # 실행되지 못한 검사를 통과한 검사로 기록하는 경로다(indeterminate ≠ clean).
    # 실측: `{"findings": {}}` → `findings: []` / `codex_failed: false` /
    # `reason: schema_mismatch`. 그리고 이 러너는 자기가 선언한 계약을 어겼다
    # (`tests/test_codex_runner_degrade_contract.sh:43`).
    #
    # 검증 범위는 **구조**다(컨테이너 타입 + 원소 타입). 필드 단위 완전성까지
    # 올리지 않는 이유: (a) verdict를 실제로 움직이는 severity는 소비자가 이미
    # 미상/off-vocab에 fail-closed고, (b) 서술 필드 하나가 빠진 정상 라운드를
    # degrade로 올리면 진짜 findings가 소실된다. 레포 자신의 valid 픽스처도
    # confidence/summary/proposed_fix 없이 통과한다.
    #
    # 두 소비 경로(qg-review 어휘, spec-distill design-doc 어휘)와 **행동이
    # 같아야 한다** — test_codex_copies_agree.sh가 meta 판정을 잰다. 이 결함이
    # 정확히 그 락의 부재로 생겼다(Law 3).
    schema_mismatch = False
    findings: list[dict] = []
    if not isinstance(raw_findings, list):
        # dict / str / int / null — 계약된 컨테이너가 아니다. 읽을 findings가 없다.
        schema_mismatch = True
        meta_type = type(raw_findings).__name__
        bad_elements: list[str] = []
    else:
        meta_type = "list"
        findings = [f for f in raw_findings if isinstance(f, dict)]
        # non-dict 원소는 렌더 불가다: str이면 `if k in f`가 부분문자열 검사가 되어
        # 키 없는 빈 finding을 내고, int면 TypeError로 변환기가 죽는다(실측).
        bad_elements = sorted({type(f).__name__
                               for f in raw_findings if not isinstance(f, dict)})
        if bad_elements:
            schema_mismatch = True

    # `dict[str, object]` 명시 — 리터럴만 두면 추론이 `dict[str, bool]`이 되어 아래
    # 문자열 대입 3건이 전부 타입 오류로 잡힌다(런타임 영향은 없다).
    meta: dict[str, object] = {"codex_failed": schema_mismatch}
    if schema_mismatch:
        meta["reason"] = "schema_mismatch"
        meta["raw_findings_type"] = meta_type
        if bad_elements:
            meta["bad_element_types"] = ",".join(bad_elements)
    sys.stdout.write(yaml_emit(findings, apply_overrides(meta), keys))
    return 0


if __name__ == "__main__":
    sys.exit(main())
