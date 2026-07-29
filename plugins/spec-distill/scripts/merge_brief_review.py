#!/usr/bin/env python3
"""spec-distill — 충실도 축 병합 (Spec B AC7/AC8/AC9).

`brief-critic`(격리, Claude)과 codex #2(비격리, 별-모델)의 충실도 findings를 **결정론**으로
합친다. 방향성 축은 병합 대상이 아니다 — verdict가 없고 산출물이 *사용자에게 낼 질문*이라
합칠 대상이 없다(spec §5.2).

권위 계약(spec §5.1):
  - **fail-closed 합집합** — critic 또는 codex 중 어느 쪽이든 Issues를 내면 needs_revise.
    codex는 advisory가 아니라 **binding**이며 단독으로 verdict를 만든다. codex를 advisory로
    두는 것은 리포가 반복 학습한 것(별-모델이 유일 backstop)의 정반대 회귀다.
  - **`codex_isolated: false` 는 항상 출력되며 verdict 입력이 아니다** — 저자가 findings를
    읽을 때 붙는 라벨(프레이밍을 흡수한 리뷰어일 수 있다는 뜻)이고 등급을 낮추는 근거가 아니다.
  - **disagreement는 verdict를 흔들지 않는다** — 합집합이므로 한쪽만 올린 finding도
    그대로 verdict를 만든다.
  - **양쪽 판정 불가 → approved 금지.** critic verdict 파싱 실패 + codex degraded면
    needs_revise + advisory로 사람에게 올린다. (round-4 실측: 리뷰어가 `**Status:**` 대신
    `## Status:`로 내 verdict가 소실됐고, codex가 살아 있어 fail-safe로 흡수됐다.)

이 verdict가 파이프라인을 **차단**하는 것은 zero-tool probe 통과 분기에서만이다. 실패
분기에서는 같은 needs_revise가 advisory로 Step B 게이트에 올라간다(AC2b) — 그 분기 판정은
`reviewing-brief`가 하고 이 스크립트는 하지 않는다.

Usage: merge_brief_review.py --critic-output <file> [--codex-yaml <file>]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    # 같은 producer(codex_findings_to_yaml.py)의 스키마를 이미 fail-closed로 다루는
    # 검증된 파서를 재사용한다. 복제하면 한쪽만 고치는 drift가 생긴다(E11).
    from merge_review import derive_codex_verdict, parse_codex_yaml
    _REUSE_OK = True
except Exception:  # noqa: BLE001 — import 실패는 codex 축 degrade로 흡수
    _REUSE_OK = False

# 줄 앵커 + 인정 토큰. `**Status:**` 와 `## Status:` 둘 다 받는다(round-4 실측 결함).
# 산문 속 "Status:"는 잡지 않는다 — 줄 시작 + 열거된 verdict 토큰이 필수다.
#
# 감사(Task 4, fix round 1): 이 패턴 안의 두 `\s` 자리 모두 개행을 건너뛸 수 없도록
# 수평 공백 전용 클래스(`[ \t]`)로 좁혔다 — Task 3에서 실측된 "\s가 ^ 인접 또는 capture
# group 직전에서 개행을 삼켜 다음 줄 내용을 오매치"하는 결함군의 두 인스턴스였다:
#   1) capture group 바로 앞: `Status:\**[ \t]*(...)` — `\s*`였다면 "Status:" 줄과
#      검증 토큰이 다음 줄에 있어도(예: "## Status:\n\n어떤 서술") 매치돼 verdict가
#      없는 구조에서 오탐이 난다.
#   2) heading-hash separator: `#{1,6}[ \t]+` — `\s+`였다면 "##"만 있는 content-free
#      줄 다음, 들여쓰기된 "  Status: Approved" 줄까지 개행+공백을 건너뛰어 매치한다.
#      이건 "bare Status:" 분기(마킹 없는 3번째 허용 형태, 그대로 유지)로 수렴하지
#      **않는다** — bare 분기는 `^Status:`가 줄 시작에 앞선 공백 없이 와야 하므로
#      들여쓰기된 "  Status:"는 그 분기로도 잡히지 않는, `\s+`만이 만들 수 있는
#      별도의 오탐 경로였다(실측: `"##\n  Status: Approved"`).
# 이 두 자리를 모두 좁힌 뒤 패턴 전체를 다시 확인함 — `\**`(문자 그대로의 `*`), 캡처
# 그룹 안의 리터럴 공백(`Issues Found`의 한 칸), `\b` 중 어느 것도 `\n`과 매치하지
# 않는다. 개행을 삼킬 수 있는 `\s` 메타문자는 이 패턴에 더 이상 남아 있지 않다.
STATUS_RE = re.compile(
    r"^(?:\*\*|#{1,6}[ \t]+)?Status:\**[ \t]*(Approved|Issues Found)\b",
    re.MULTILINE | re.IGNORECASE)
SENTINEL_RE = re.compile(r"```brief-critic-issues[ \t]*\n(.*?)\n?```", re.DOTALL)

CRITIC_CATEGORIES = ("distortion", "omission", "insertion", "provenance_mislabel",
                     "authority_syntax", "evidence_unsupported")

# `agents/brief-critic.md`가 선언한 record 스키마 그대로. 이 넷은 전부 **비어 있지 않은
# 문자열**이어야 한다 — 하나라도 없거나 타입이 다르면 그 record는 판독 불가다.
CRITIC_REQUIRED_FIELDS = ("category", "target_section", "severity", "message")


def extract_critic_verdict(text: str) -> tuple[str | None, str | None]:
    """반환 (verdict, conflict_reason).

    `search()`(첫 매치)를 쓰지 않는다. `agents/brief-critic.md`의 출력 형식 절에는
    리터럴 `**Status:** Approved` / `**Status:** Issues Found`가 **디코이로** 들어
    있고, brief 본문(§6 사용자 원문 = 비신뢰 verbatim)이 critic 프롬프트에 그대로
    inline되므로 원문에 심긴 문자열도 같은 표면이다. 첫 매치를 취하면 복창·주입이
    실제 판정보다 앞서 잡힌다.

    형제 규칙과 정렬한다 — `codex_findings_to_yaml.py`는 `matches[-1]`을 쓰며
    "last block defeats injected earlier blocks"를 주석으로 명시한다. 다만 여기서는
    한 걸음 더 간다: **값이 서로 다른 Status가 공존하면 판정 불가로 fail-closed**
    (`needs_revise`)하고 그 사실을 reason으로 올린다. 값이 모두 같으면 그 값을 쓴다
    (같은 값의 중복은 충돌이 아니므로 과잉 차단하지 않는다).
    """
    ms = STATUS_RE.findall(text)
    if not ms:
        return None, None
    verdicts = ["approved" if m.strip().lower() == "approved" else "needs_revise"
                for m in ms]
    last = verdicts[-1]
    if len(set(verdicts)) > 1:
        # **마지막을 취하고, 충돌은 advisory로만 올린다.** 값이 갈리면 무조건
        # needs_revise로 밀면 `approved`가 사실상 **도달 불가**가 된다 — agent 파일의
        # 출력 형식 절에 리터럴 Status 두 줄이 있어서, critic이 자기 형식을 복창하는
        # (매 라운드 동일하게 일어날 수 있는) 순간 모든 라운드가 강제 escalate로 타버린다.
        # 형제 규칙(`codex_findings_to_yaml.py`: "last block defeats injected earlier
        # blocks")과 정렬하되, 충돌 사실 자체는 사람에게 반드시 도달시킨다.
        return last, (
            f"Status 줄 {len(ms)}개의 판정이 서로 다르다(마지막 값 '{last}'를 채택) — "
            "복창이나 주입이 섞였을 수 있으니 critic 원문을 직접 확인하라")
    return last, None


def extract_critic_issues(text: str) -> tuple[list[dict], bool, list[str]]:
    """반환 (issues, malformed, reasons). sentinel 블록 부재/깨짐은 malformed=True.

    **원소 단위로도 malformed다** (CR-1). 이전 구현은 non-dict 원소를 조용히
    버리면서 `malformed=False`를 반환했다 — 그 결과 잘리거나 깨진 critic 출력이
    control(`{"issues": []}`)과 **바이트 동일**한 병합 출력을 냈고, *"리뷰어가
    아무것도 찾지 못했다"* 로 읽혔다. 실행 못 한 검사를 통과한 검사로 기록하는
    것이 정확히 이 spec이 금지하는 것이다(indeterminate ≠ clean).

    판정 규칙:
      - 원소가 dict가 아니다 → malformed. 그 원소는 findings로 승격할 수 없으므로
        버리되, **버렸다는 사실이 reason으로 남는다.**
      - dict인데 `CRITIC_REQUIRED_FIELDS` 중 하나라도 부재/non-string/공백뿐이다
        → malformed. 단 **record 자체는 findings에 그대로 싣는다** — 부분적으로라도
        읽히는 지적을 버리면 정보 손실이고, malformed 플래그가 이미 escalate를
        만들기 때문에 버려서 얻는 안전은 없다. (공백뿐인 값을 포함하는 이유:
        `emit()`이 빈 값을 아예 출력하지 않아, 빈 `message`는 내용 없는 finding으로
        렌더돼 같은 "판독 불가를 clean으로" 클래스가 된다.)
    """
    # 첫 블록이 아니라 **마지막** 블록을 취한다 — 형제 규칙
    # (`codex_findings_to_yaml.py`: "last block defeats injected earlier blocks")과
    # 같은 이유다. brief 본문이 프롬프트에 inline되므로 앞선 디코이 블록이 진짜
    # 지적을 덮을 수 있다.
    matches = list(SENTINEL_RE.finditer(text))
    if not matches:
        return [], True, []
    m = matches[-1]
    if len(matches) > 1:
        # 마지막을 채택하되(형제 규칙) **조용히 넘어가지 않는다.** brief 본문(§6 = 비신뢰
        # verbatim)이 critic 프롬프트에 inline되므로, 뒤에 붙은 블록이 권위를 갖는다는 사실
        # 자체가 주입 표면이다. 다중 블록은 판독 불가로 표시해 escalate를 만든다.
        extra_reason = (f"sentinel 블록 {len(matches)}개 — 어느 것이 리뷰어의 실제 출력인지 "
                        "확정 불가(마지막 블록을 채택했으나 그대로 신뢰하지 않는다)")
    else:
        extra_reason = None
    try:
        payload = json.loads(m.group(1))
    except json.JSONDecodeError:
        return [], True, []
    issues = payload.get("issues")
    if not isinstance(issues, list):
        return [], True, []
    kept: list[dict] = []
    reasons: list[str] = []
    malformed = False
    if extra_reason:
        malformed = True
        reasons.append(extra_reason)
    for idx, it in enumerate(issues):
        if not isinstance(it, dict):
            malformed = True
            reasons.append(
                f"critic issues 원소 #{idx}가 record(JSON object)가 아니다 "
                f"(type: {type(it).__name__}, finding으로 승격 불가)")
            continue
        bad = [k for k in CRITIC_REQUIRED_FIELDS
               if not isinstance(it.get(k), str) or not it.get(k, "").strip()]
        if bad:
            malformed = True
            reasons.append(
                f"critic issues 원소 #{idx}의 필수 필드가 부재/비문자열/공백: "
                f"{', '.join(bad)}")
        kept.append(it)
    return kept, malformed, reasons


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if s == "" or any(c in s for c in ":#\"'\n") or s.strip() != s:
        return json.dumps(s, ensure_ascii=False)
    return s


def emit(result: dict) -> str:
    out: list[str] = []
    for k in ("fidelity_verdict", "critic_verdict", "codex_verdict",
              "critic_verdict_unrecoverable", "codex_isolated", "codex_degraded"):
        out.append(f"{k}: {_yaml_scalar(result[k])}")
    if not result["fidelity_findings"]:
        out.append("fidelity_findings: []")
    else:
        out.append("fidelity_findings:")
        for f in result["fidelity_findings"]:
            out.append(f"  - source: {_yaml_scalar(f.get('source'))}")
            for k in ("category", "target_section", "severity", "confidence",
                      "message", "summary", "proposed_fix"):
                if k in f and f[k] not in (None, ""):
                    out.append(f"    {k}: {_yaml_scalar(f[k])}")
    if not result["advisory"]:
        out.append("advisory: []")
    else:
        out.append("advisory:")
        for a in result["advisory"]:
            out.append(f"  - {_yaml_scalar(a)}")
    return "\n".join(out) + "\n"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--critic-output", required=True)
    p.add_argument("--codex-yaml", default="")
    args = p.parse_args()

    advisory: list[str] = []

    # --- critic 측 ---------------------------------------------------------
    try:
        with open(args.critic_output, "r", encoding="utf-8", errors="replace") as fh:
            critic_text = fh.read()
    except OSError as exc:
        critic_text = ""
        advisory.append(f"[spec-distill v0.24.0] critic 출력 읽기 실패: {exc}")
    critic_verdict, critic_verdict_conflict = extract_critic_verdict(critic_text)
    critic_issues, critic_malformed, critic_malformed_reasons = \
        extract_critic_issues(critic_text)
    if critic_verdict_conflict:
        advisory.append(
            f"[spec-distill v0.24.0] {critic_verdict_conflict}. "
            "복창·주입된 Status 줄이 실제 판정을 덮지 않도록 fail-closed 처리한다.")
    if critic_verdict is None:
        advisory.append(
            "[spec-distill v0.24.0] critic verdict 파싱 불가 (Status 줄 부재) — "
            "findings는 sentinel에서 별 경로로 파싱했다. 이 라운드의 충실도 판정은 "
            "codex 단독이거나(codex 가용) 판정 불가다(codex degraded).")
    if critic_malformed:
        if critic_malformed_reasons:
            # 원소 단위 파손 — 어느 원소가 왜 판독 불가였는지를 그대로 올린다.
            for r in critic_malformed_reasons:
                advisory.append(
                    f"[spec-distill v0.24.0] {r}. 이 라운드를 정상 0건으로 읽지 "
                    "않는다(indeterminate ≠ clean).")
        else:
            advisory.append(
                "[spec-distill v0.24.0] critic sentinel 블록(`brief-critic-issues`) 부재/깨짐 "
                "— issues 0건으로 읽지 않는다(indeterminate ≠ clean).")
    for i in critic_issues:
        cat = str(i.get("category", ""))
        if cat not in CRITIC_CATEGORIES:
            advisory.append(
                f"[spec-distill v0.24.0] critic finding의 category가 닫힌 열거 밖: {cat!r} "
                "— 그대로 verdict에 반영한다(fail-closed).")

    # --- codex 측 ----------------------------------------------------------
    if not _REUSE_OK:
        codex_findings, codex_failed, codex_reason = [], True, "merge_review_import_failed"
        advisory.append("[spec-distill v0.24.0] merge_review.py 재사용 import 실패 — "
                        "codex 축을 degraded로 처리한다.")
    else:
        codex_findings, codex_failed, codex_reason = parse_codex_yaml(args.codex_yaml)
    codex_verdict = None
    if not codex_failed:
        codex_verdict = derive_codex_verdict(codex_findings) if _REUSE_OK else None
    else:
        advisory.append(
            "[spec-distill v0.24.0] codex 충실도 co-review SKIPPED/FAILED "
            f"(reason: {codex_reason or 'unavailable'}) — Claude-only, 모델 다양성 없음 (degraded).")

    # --- fail-closed 합집합 -------------------------------------------------
    findings: list[dict] = []
    for i in critic_issues:
        rec = dict(i)
        rec["source"] = "critic"
        findings.append(rec)
    for f in codex_findings:
        rec = dict(f)
        rec["source"] = "codex"
        findings.append(rec)

    escalates = bool(findings) or critic_malformed
    if critic_verdict == "needs_revise" or codex_verdict == "needs_revise":
        escalates = True
    if critic_verdict is None and codex_failed:
        # 양쪽 판정 불가 → 절대 approved로 해소하지 않는다.
        escalates = True
        advisory.append(
            "[spec-distill v0.24.0] 충실도 판정 불가 (critic verdict unrecoverable AND "
            "codex degraded) — approved로 해소하지 않고 Step B 게이트에서 사람이 판정한다.")
    fidelity_verdict = "needs_revise" if escalates else "approved"

    if (critic_verdict == "approved" and fidelity_verdict == "needs_revise"
            and codex_verdict == "needs_revise"):
        advisory.append(
            "[spec-distill v0.24.0] codex가 critic의 approved를 overturn했다 "
            "(binding — 합집합). codex_isolated: false 라벨을 함께 읽어라.")

    sys.stdout.write(emit({
        "fidelity_verdict": fidelity_verdict,
        "critic_verdict": critic_verdict,
        "codex_verdict": codex_verdict,
        "critic_verdict_unrecoverable": critic_verdict is None,
        "codex_isolated": False,          # AC8 — 항상. verdict 입력이 아니다.
        "codex_degraded": bool(codex_failed),
        "fidelity_findings": findings,
        "advisory": advisory,
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
