# -*- coding: utf-8 -*-
"""L3 판정기 — agent 가 «선언한» 입력과 dispatch 가 «전달하는» 것의 일치,
그리고 선언된 종류가 금지 어휘가 아닌지.

(a) 만으로는 「적으면 통과」다. (b) 가 무엇을 선언해도 되는가의 어휘를 준다.

(b) 의 한계 — 선언값 판정이므로 저자가 kind 를 거짓으로 적으면 빠져나간다.
변수명 휴리스틱이 보조 축이지만 이름과 kind 를 함께 속이면 통과한다. 이 락은
그 구멍을 없앴다고 주장하지 않고 어디에 있는지 밝힌다.
"""
import re
from pathlib import Path

import yaml

from cite import uncited

ALLOWED_KINDS = ("task", "artifact", "same_origin_history", "repo_context")
FORBIDDEN_KINDS = ("prior_verdict", "score", "orchestrator_framing")

# 앞 판정을 반박하는 것이 과업인 agent 는 prior_verdict 를 «받아야» 한다.
# 각 값은 C6 조건을 인용한다 — 인용 없는 항목은 호출자가 RED 로 만든다.
#
# ── `orchestrator_framing` 축 전수 스윕 (최종 리뷰 K3) ────────────────────
# Task 14 의 스윕은 `prior_verdict` 축만 돌았고 이 축은 안 돌았다. 열거가
# 아니라 도출로 다시 훑는다 — 20 개 agent 의 선언 슬롯 «전부»에 대해 그
# dispatch 자리가 싣는 값의 «출처»를 읽고 다섯으로 나눈다:
#   ⓐ 경로·enum·기계 계산 리터럴 → `task`
#   ⓑ 리뷰 대상 원문 또는 스크립트가 만든 blob → `artifact`
#   ⓒ 같은 출처의 과거 findings·이력 → `same_origin_history`
#   ⓓ 리포 규약·설계 문서 → `repo_context`
#   ⓔ **오케스트레이터가 직접 쓴 산문 종합** → `orchestrator_framing`(금지)
# ⓔ 에 해당하는 것은 «둘»이다 — `blind-spot-prober.framing`, `steelman-builder.premises`
# (2026-09-06 재설계로 추가). 판정 근거:
#   · `steelman-builder.direction`/`trigger` — 지목됐으나 ⓔ 가 아니다.
#     `direction` 은 «사용자가 고른 방향»의 재진술(과업의 대상)이고,
#     `trigger` 는 게이트를 발동시킨 세 값 중 하나를 대는 enum 이다
#     (landscape 모순 / anti-pattern / 제약 충돌). 둘 다 이 agent 가
#     내야 할 «대안»에 대한 오케스트레이터의 기대가 아니다 → ⓐ.
#   · `steelman-builder.premises` — 2026-09-06 재설계로 이 agent 의 선언 슬롯이
#     다섯으로 늘었다. 그중 `goal`·`constraints` 는 사용자 발화 원문 → ⓑ.
#     `premises` 는 orchestrator 가 R1 에서 도출한 전제 목록 → **ⓔ, 위에서 이미
#     센 두 번째 항목**(면제 등재는 EXEMPT_SLOTS 참고, 이 bullet 은 새로 세지 않는다).
#   · `coverage-mapper.ledger_state` — 원장 «상태»의 요약이지 판단이 아니다 → ⓐ.
#   · `pr-understanding-builder.context` — `build-pr-context` 가 만든 blob → ⓑ.
#   · `transcript-reader.inventory` — `prepare_standup.py` 출력 → ⓐ.
#   · `plugin-auditor.axis_task`/`candidate_clues` — `audit-workflow.js` 의
#     CONTRACT 가 *"나는 이 단서들이 참인지 거짓인지 말하지 않는다"* 로
#     판단 배제를 명시한다 → ⓐ/ⓒ.
#   · `runtime-verifier.spec_acceptance_criteria` — spec 에서 뽑은 {ac_id,text} → ⓑ.
#   · brief/seed 계열 넷(`brief`/`document`/`draft`/`seed`) — 원문 인라인 → ⓑ.
# 남은 슬롯은 전부 경로·반복자·enum 이다.
EXEMPT_SLOTS = {
    ("quality-gates:adversarial", "phase1_findings"):
        "C6(1) Phase 1/2 리뷰어의 findings 를 verdict(confirm/downgrade/reject)하는 것이 "
        "이 agent 의 과업이다 — 대응물이 없다",
    ("quality-gates:artifact-adversarial", "merged_findings"):
        "C6(1) artifact-critic(+codex) 의 merged findings 를 verdict 하는 것이 이 agent 의 "
        "과업이다 — 대응물이 없다",
    # 최종 리뷰 A/m1 — 조인 인용 검사가 이 사유를 「너무 얇다」로 잡았다.
    # 이전 문구("감사 findings 를 반박하는 것이 과업이다")는 «어느 조건인가»만
    # 있고 «왜 그 조건에 해당하는가»가 없었다. 형제 둘과 같은 수준으로 적는다.
    ("plugin-audit:audit-refuter", "findings"):
        "C6(1) plugin-auditor 가 낸 감사 findings 를 반박(refute)해 살아남는 "
        "것만 남기는 것이 이 agent 의 유일한 과업이다 — 앞 판정을 안 받으면 "
        "반박할 대상 자체가 없어 대응물이 원리적으로 없다. 오염 위험은 "
        "audit-workflow.js 의 CONTRACT 가 「나는 이 단서들이 참인지 거짓인지 "
        "말하지 않는다」로 사전 판정을 빼서 낮춘다.",
    ("spec-distill:blind-spot-prober", "framing"):
        "C6(1) 이 agent 의 과업은 «지금의 framing 에 대한» 적대적 premortem "
        "이다 — 프로브의 대상이 정의상 오케스트레이터가 재구성한 그 framing "
        "이라 대응물이 없다. 다른 값(사용자 §6 원문)을 넣으면 프로버가 자기 "
        "framing 을 새로 세우고 그것을 치게 되어, 이 agent 가 존재하는 이유"
        "(인터뷰 턴이 «자기» 전제에 눈먼 자리를 찾는다)를 잃는다. 잔여 "
        "위험은 남는다 — 재구성이 이미 잃은 것은 프로버도 못 본다. 그 "
        "축은 이 락이 아니라 reviewing-brief 의 충실도 단계가 §6 원문 대비로 "
        "따로 잰다(brief-critic).",
    ("spec-distill:steelman-builder", "premises"):
        "C6(1) 이 agent 의 과업은 «그 전제 목록에 대한» 반증 판정과 목록 자체의 반박이다 — "
        "대상이 정의상 orchestrator 가 R1 에서 도출한 그 목록이라 대응물이 없다. 다른 값(사용자 "
        "원문)을 넣으면 builder 가 자기 전제를 세우고 그것을 치게 되어 C16 의 목적(전제 목록이 "
        "원안 저자의 상상력 경계를 물려받지 않게 한다)을 잃는다. 잔여 위험은 남는다 — 도출이 이미 "
        "잃은 전제는 builder 도 못 본다(brief OQ2). 면제 범위는 이 슬롯 하나로 좁혔다: goal 과 "
        "constraints 는 사용자 원문(artifact)으로 넘긴다. 설계 "
        "docs/superpowers/specs/2026-09-06-steelman-goal-fit-design.md §6.7.",
}

# 면제 «크기»의 회귀 축 — L1 의 `EXEMPT_BASELINE` 과 같은 규율(최종 리뷰 A/m2
# 를 두 등록부에 대칭으로 적용한다. 한쪽에만 두면 다음 우회가 안 걸린 쪽으로
# 간다 — Task 11b Step 4b 가 고친 비대칭과 같은 모양이다). 전부 면제로 넣으면
# L3(b)가 장식이 되는 것이 설계 M8 이 이 수를 재는 이유다.
# 2026-09-06 4→5: steelman-builder.premises (위 항목의 사유). 전제 목록은 정의상 orchestrator 종합이다.
EXEMPT_SLOTS_BASELINE = 5

# 변수명이 판정·점수를 시사하면 kind 가 금지 셋 중 하나여야 한다.
# 그러면 면제 등재가 강제되고, 등재는 C6 인용을 요구한다.
_SUSPECT_VAR = re.compile(r'VERDICT|SCORE|RANK|SEVERITY|CONFIDENCE', re.I)

_FM_RE = re.compile(r'\A---\n(.*?)\n---\n', re.S)
_PAIR_RE = re.compile(
    r'<([a-zA-Z_][a-zA-Z0-9_]*)>\s*\$\{([A-Za-z_][A-Za-z0-9_]*)\}')
_SUBAGENT_RE = re.compile(r'subagent_type:\s*"([a-z0-9-]+:[a-z0-9-]+)"')


def agents(repo_root):
    """정의 집합(∀) — frontmatter 의 `name:` 에서. 선언 부재는 None 으로 «남긴다»."""
    repo = Path(repo_root)
    out = {}
    for f in sorted(repo.glob("plugins/*/agents/*.md")):
        text = f.read_text(encoding="utf-8")
        m = _FM_RE.match(text)
        if not m:
            continue
        try:
            fm = yaml.safe_load(m.group(1)) or {}
        except yaml.YAMLError:
            fm = {}
        name = str(fm.get("name", "")).split(":")[-1]
        if not name:
            continue
        plugin = f.parent.parent.name
        slots = fm.get("input_slots")
        out["%s:%s" % (plugin, name)] = {
            "path": str(f.relative_to(repo)),
            "slots": slots if isinstance(slots, list) else None,
        }
    return out


# dispatch 자리를 찾는 코퍼스 — skill·command 의 md 전부. 특정 SKILL 하나로
# 좁히지 않는다(좁히면 다른 파일의 dispatch 가 영원히 안 보인다). `scanned_paths()`
# 가 같은 튜플을 재사용한다 — `--emit-scanned` 가 이 함수와 다른 글롭을 내면
# 낸 것과 읽은 것이 갈린다.
_DISPATCH_GLOBS = ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md")


def dispatch_pairs(repo_root):
    """dispatch 자리가 실제로 전달하는 (태그, 변수) 쌍 + 다중-agent 펜스 목록.

    코퍼스는 skill·command 의 md 전부다. 특정 SKILL 하나로 좁히지 않는다 —
    좁히면 다른 파일의 dispatch 가 영원히 안 보인다.

    반환은 `(pairs, multi)` 2-tuple — `multi` 는 subagent_type 이 둘 이상인
    펜스의 `(rel, start_line, count)` 목록(수정 라운드 1, 코디네이터 판정 ⒞).
    """
    repo = Path(repo_root)
    out = {}
    multi = []
    for pat in _DISPATCH_GLOBS:
        for f in sorted(repo.glob(pat)):
            if not f.is_file():
                continue
            rel = str(f.relative_to(repo))
            lines = f.read_text(encoding="utf-8").splitlines()
            # 펜스 단위로 자른다 — 펜스마다 독립 dispatch 다. 합치면 죽은
            # 펜스가 살아 있는 펜스의 결손을 가린다.
            #
            # `^\s*```` — 들여쓴 펜스(번호 목록 continuation 등)도 열고 닫는다.
            # 이 방향(들여쓰기 허용)이 안전한 이유: 펜스 *안* 콘텐츠에 줄 시작
            # 들여쓴 백틱 세 개가 우연히 있으면 그 펜스가 "쪼개질" 수 있다(안쪽
            # 줄이 닫힘으로 오인됨) — 하지만 쪼개짐은 각 조각이 독립 dispatch 로
            # 재해석될 뿐이라 문제가 있으면 undeclared/undelivered/no_declaration
            # 으로 *드러난다*. 반대 방향(들여쓴 펜스를 계속 무시)은 펜스 전체가
            # 통째로 사라져 dispatch 자리가 아예 없는 것처럼 보인다 — 이 파일의
            # 기존 주석("합치면 죽은 펜스가 산 펜스의 결손을 가린다")과 같은
            # 방향의 판단: 쪼개짐(과다 관측) > 실종(과소 관측, 침묵).
            buf, start, inside = [], 0, False
            for i, line in enumerate(lines, 1):
                if re.match(r'^\s*```', line):
                    if inside:
                        _harvest("\n".join(buf), rel, start, out, multi)
                        buf, inside = [], False
                    else:
                        inside, start = True, i
                    continue
                if inside:
                    buf.append(line)
    return out, multi


def _harvest(block, rel, line, out, multi):
    matches = _SUBAGENT_RE.findall(block)
    if not matches:
        return
    if len(matches) > 1:
        # 조용히 첫 번째로 귀속하지 않는다 — 세어서 이름을 대고, 어느 쪽에도
        # 태그를 붙이지 않는다(잘못된 단일 귀속보다 미귀속이 정직하다).
        multi.append((rel, line, len(matches)))
        return
    key = matches[0]
    out.setdefault(key, [])
    for p in _PAIR_RE.finditer(block):
        out[key].append((p.group(1), p.group(2), rel, line))


def check(repo_root):
    """(a) 일치 · (b) 금지 종류. 위반 목록을 낸다."""
    defs = agents(repo_root)
    pairs, _multi = dispatch_pairs(repo_root)
    problems = []

    for key, info in sorted(defs.items()):
        delivered = pairs.get(key, [])
        if info["slots"] is None:
            problems.append(("no_declaration", key, info["path"], ""))
            continue
        declared = {}
        for s in info["slots"]:
            if not isinstance(s, dict) or "tag" not in s:
                problems.append(("bad_slot", key, info["path"], repr(s)))
                continue
            declared[str(s["tag"])] = s

        # (a) 선언 ↔ 전달
        for (tag, var, path, ln) in delivered:
            if tag not in declared:
                problems.append(("undeclared", key, "%s:%d" % (path, ln),
                                 "<%s>${%s}" % (tag, var)))
            elif str(declared[tag].get("var", var)) != var:
                problems.append(("var_mismatch", key, "%s:%d" % (path, ln),
                                 "<%s> 선언=%s 전달=%s"
                                 % (tag, declared[tag].get("var"), var)))
        got = {t for (t, _v, _p, _l) in delivered}
        for tag, s in declared.items():
            if tag not in got and not s.get("optional"):
                problems.append(("undelivered", key, info["path"],
                                 "<%s> 를 선언했으나 전달하는 dispatch 가 없다" % tag))

        # (b) 금지 종류
        for tag, s in declared.items():
            kind = str(s.get("kind", ""))
            var = str(s.get("var", ""))
            if not kind:
                problems.append(("no_kind", key, info["path"], tag))
            elif kind in FORBIDDEN_KINDS:
                if (key, tag) not in EXEMPT_SLOTS:
                    problems.append(("forbidden_kind", key, info["path"],
                                     "<%s> kind=%s" % (tag, kind)))
            elif kind not in ALLOWED_KINDS:
                problems.append(("unknown_kind", key, info["path"],
                                 "<%s> kind=%s" % (tag, kind)))
            if _SUSPECT_VAR.search(var) and kind not in FORBIDDEN_KINDS:
                problems.append(("suspect_var", key, info["path"],
                                 "<%s> var=%s 인데 kind=%s — 판정·점수를 시사하는 "
                                 "이름은 금지 종류로 선언하고 면제에 등재하라"
                                 % (tag, var, kind)))
    return problems


def uncited_exemptions():
    """사유가 실질을 갖추지 못한 면제 항목 — 호출자가 RED 로 만든다.

    판정은 `cite.uncited()` 하나가 진다(L1 과 공용) — 리터럴 `"C6"` 두 글자면
    만족하던 이 자리의 규율이 L1 과 갈리는 것을 막는다(최종 리뷰 A/m1).
    """
    return uncited(EXEMPT_SLOTS)


def multi_agent_fences(repo_root):
    """펜스 하나에 `subagent_type` 이 둘 이상인 자리 — `(rel, start_line, count)`
    목록. 조용히 첫 매치로 귀속하지 않기 위해 존재한다(수정 라운드 1) — 셀 수
    없으면 셀 수 없음을 내고, 셀 수 있으면 이름(file:line)을 댄다."""
    _pairs, multi = dispatch_pairs(repo_root)
    return multi


def scanned_paths(repo_root):
    """`--emit-scanned` 코퍼스 — `agents()` 와 `dispatch_pairs()` 가 실제로
    도는 파일 전부의 합집합(참조가 0건이어도 글롭에 매칭돼 읽힌 파일은
    포함한다). 같은 글롭 소스를 재사용한다(재도출 아님)."""
    repo = Path(repo_root)
    out = set()
    for f in repo.glob("plugins/*/agents/*.md"):
        if f.is_file():
            out.add(str(f.relative_to(repo)))
    for pat in _DISPATCH_GLOBS:
        for f in repo.glob(pat):
            if f.is_file():
                out.add(str(f.relative_to(repo)))
    return sorted(out)
