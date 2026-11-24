#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/skills/context-build/* plugins/spec-distill/skills/roadmap-draft/* plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/README.md plugins/spec-distill/dependencies.md docs/philosophy/devbrew-harness-philosophy.md
# 글 줄이기 — 앞단 글에 풀 수 없는 옛 설계 번호 · 옛 판 번호 · 날짜 실측 표기가 없고(AC30), 낡은 서술이 고쳐졌고(AC29),
# 이유 문장 안에만 있던 지시가 지시 문장으로 남았다(AC31). 철학 번호(P · AP · Law)와 결과물의 살아 있는 번호
# (S · K · OQ · RC · ST · 라운드 R)는 남는다 — 아래 자기 시험이 그것을 잰다(양의 짝).
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_prose_trim.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
NUM_FILES=(
  plugins/spec-distill/skills/context-build/SKILL.md
  plugins/spec-distill/skills/context-build/references/finishing.md
  plugins/spec-distill/skills/roadmap-draft/SKILL.md
  plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md
)
num_corpus() {   # 명시 목록 + 로드맵 잡기 아래에 새로 생긴 추적 파일
  { printf '%s\n' "${NUM_FILES[@]}"; git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/roadmap-draft/*'; } | sort -u
}
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: 번호 코퍼스 + 과제 2–7 의 절이 has · lacks 로 읽는 파일
  { num_corpus
  printf '%s\n' plugins/spec-distill/skills/context-build/references/finishing.md \
    plugins/spec-distill/skills/intent-sync/SKILL.md \
    plugins/spec-distill/skills/context-build/references/state-file.md \
    plugins/spec-distill/skills/context-build/references/state-migration.md \
    plugins/spec-distill/templates/interview-seed-audit-template.md \
    plugins/spec-distill/templates/interview-brief-template.md \
    plugins/spec-distill/skills/reviewing-brief/SKILL.md \
    plugins/spec-distill/references/proceed-gate.md \
    plugins/spec-distill/README.md plugins/spec-distill/dependencies.md \
    docs/philosophy/devbrew-harness-philosophy.md; } | sort -u
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/prose-trim.XXXXXX")" || exit 2
trap 'rm -rf -- "$TMPD"' EXIT

has()   { grep -qF -- "$2" "$ROOT/$1" && ok "$3" || no "$3 — 없다: «$2» ($1)"; }
lacks() { grep -qF -- "$2" "$ROOT/$1" && no "$3 — 남아 있다: «$2» ($1)" || ok "$3"; }

# ── AC30 — 옛 번호 스캐너(쉬운 말 규칙 블록만 빼고 코드 블록 안까지 본다) ──────────────────
scan_ids() {
  python3 - "$@" <<'PY'
import re
import sys

OLD = re.compile(
    r"(?<![A-Za-z0-9_./-])(?:C43|C4|C5|C8|G1|G2|N1a|N1b|N2|NG4|NG7|AC\d+|D6|OQ6|R2a)(?![A-Za-z0-9_])"
    r"|(?<![\w.])v?\d+\.\d+\.\d+(?![\w.])"
    r"|(?<!\d)20\d\d-[01]\d-[0-3]\d(?!\d)"
)
SELF_BAD = "C43 절 · (C4) · C5, · C8 — · G1 · G2 · N1a · N1b · N2 · NG4·P17 · NG7 · AC1 · AC12 · D6 · OQ6 · R2a 의 · v0.24.0 · [0.57.0] · 2026-09-10"
SELF_LIVE = "S1 S12 K1 RC3 OQ1 OQ4 R1 R5 P21 AP2 Law 1 C1 C2 D5 ST1 <YYYY-MM-DD> 3-path"

args = sys.argv[1:]
if args == ["--self"]:
    bad = [m.group(0) for m in OLD.finditer(SELF_BAD)]
    live = [m.group(0) for m in OLD.finditer(SELF_LIVE)]
    print("self-bad %d" % len(bad))
    print("self-live %d %s" % (len(live), " ".join(live)))
    sys.exit(0)
for path in args:
    inside = False
    with open(path, encoding="utf-8") as fh:
        for no, line in enumerate(fh, 1):
            if "<!-- plain-language:begin -->" in line:
                inside = True
            if inside:
                if "<!-- plain-language:end -->" in line:
                    inside = False
                continue
            for m in OLD.finditer(line):
                print("%s:%d: %s" % (path, no, m.group(0)))
PY
}

scan_ids --self > "$TMPD/self.txt"
assert_eq "$(sed -n 's/^self-bad //p' "$TMPD/self.txt")" "19" "AC30(양성 대조): 스캐너가 금지 글자 열아홉을 모두 잡는다"
assert_eq "$(sed -n 's/^self-live //p' "$TMPD/self.txt")" "0 " "AC30(양성 대조): 살아 있는 번호(S · K · RC · OQ · 라운드 R · P · AP · C1 · C2 · D5 · ST)는 잡지 않는다"

for f in "${NUM_FILES[@]}"; do
  [ -s "$ROOT/$f" ] && ok "AC30(양의 짝): 번호 코퍼스에 ${f} 가 있다" || no "AC30: 번호 코퍼스의 ${f} 가 없거나 비었다 — 부재 단언이 공허하다"
done
CORPUS="$(num_corpus)"
# shellcheck disable=SC2086
( cd "$ROOT" && scan_ids $CORPUS ) > "$TMPD/ids.txt"
n_hits="$(grep -c . "$TMPD/ids.txt" || true)"
if [ "$n_hits" -eq 0 ]; then ok "AC30: 앞단 글에 옛 설계 번호 · 옛 판 번호 · 날짜 실측 표기가 없다"
else no "AC30: 옛 번호 ${n_hits}곳"; sed 's/^/      /' "$TMPD/ids.txt"; fi
# shellcheck disable=SC2086
( cd "$ROOT" && grep -l -E '(^|[^A-Za-z0-9])P(17|21|23)([^0-9]|$)' $CORPUS ) > "$TMPD/phil.txt" || true
[ -s "$TMPD/phil.txt" ] && ok "AC30(양의 짝): 철학 번호(P17 · P21 · P23)가 남아 있다" || no "AC30: 철학 번호가 하나도 없다 — 지우기가 넘쳤다"
for f in $CORPUS; do lacks "$f" 'decompose_edits' "AC29 ②: 스키마에 없는 상태 키가 ${f##*/} 에 없다(계획 1 이 닫음 — 지킨다)"; done

# ── 컨텍스트 쌓기 본문과 그 reference (과제 2) ────────────────────────────────────────
CB=plugins/spec-distill/skills/context-build/SKILL.md
lacks "$CB" '§2.4' "AC29 ③: 없는 절 번호 「§2.4」 가 본문에 없다"
lacks plugins/spec-distill/skills/context-build/references/state-migration.md '§2.4' "AC29 ③: 없는 절 번호 「§2.4」 가 이전 reference 에 없다"
has   "$CB" 'State location` 의 스키마' "AC29 ③(양의 짝): 스키마를 절 이름으로 가리킨다"
lacks "$CB" '다음 결정 · 질문 하나' "AC29 ⑧: 라운드 꼴이 「질문 하나」 로 적히지 않는다"
has   "$CB" '질문을 여럿 묶을 수 있다' "AC29 ⑧(양의 짝): 여럿 묶기 허용 문장이 남아 있다"
has   "$CB" '모델 판단으로 건너뜀' "AC29 ⑦: 종료 조건이 건너뜀을 말한다(계획 1 이 닫음 — 지킨다)"
has   plugins/spec-distill/skills/context-build/references/state-file.md '## 위험 줄 대기' "AC29 ⑨: 상태 파일 본문 목록에 두 절이 있다(계획 1 이 닫음 — 지킨다)"
has   "$CB" '## 3-path routing' "AC30(양의 짝): 질문 경로 절 머리가 번호 없이 남아 있다"
has   "$CB" 'S1 은 원자료가 실렸을 때만 든다' "닫힘 규칙: 모델이 줄인 S1 은 사용자 원문 인용으로 세지 않는다"
has   "$CB" '해결돼도 목록에서 지우지 않는다' "AC31 ⑨: 해결된 결정을 목록에서 지우지 않는다"
has   "$CB" 'subagent 에 넘기는 플러그인 파일은 경로가 아니라 내용으로 싣는다' "AC31 ⑤: 플러그인 파일은 내용으로 싣는다"
has   "$CB" '웹 kill switch 는 dispatch 자리마다 따로 확인한다' "AC31 ⑦: 끄는 변수를 dispatch 자리마다 확인한다"
has   plugins/spec-distill/skills/context-build/references/state-file.md '리뷰 결정 문구는 그렇게 정했다는 사실과 뜻까지만 읽는다' "글 일곱 ⑦: 컨텍스트 쌓기의 원자료 읽기도 리뷰 결정 문구를 뜻까지만 읽는다"

# ── 끝맺음 절차 (과제 3) ──────────────────────────────────────────────────────────────
FIN=plugins/spec-distill/skills/context-build/references/finishing.md
lacks "$FIN" '5-section' "AC29 ①: audit 를 「5-section」 이라 부르지 않는다"
has   "$FIN" 'audit 템플릿의 절 구조를 확보' "AC29 ①(양의 짝): audit 구조를 템플릿으로 가리킨다"
has   "$FIN" '`advice-list` 는 읽기 전용이다' "AC29 ⑩(양의 짝): 끝난 일 문장을 걷고도 읽기 전용 문장은 남는다"
lacks "$FIN" '두 경우에 온다' "「두 경우」 머리: B-S 로 오는 자리를 수로 적지 않는다"
has   "$FIN" 'B-S 로 오는 자리' "「두 경우」 머리(양의 짝): B-S 로 오는 자리를 이름으로 든다"
has   "$FIN" '읽어 보기까지 돈 뒤 Step B 를 B-0 부터 다시 돈다' "「두 경우」: 나눈 일 갈래 뒤에 돌아갈 자리가 있다"
lacks "$FIN" 'brief terminal' "④: 정의 없는 「terminal advisory」 가 없다"
has   "$FIN" '설계(brainstorming)로 넘기지 않는다' "글 일곱 ②: ④ 가 넘기지 않는다는 것을 로드맵 잡기 줄과 가른다"
has   "$FIN" '작업 트리 루트: <루트 절대경로>' "글 일곱 ⑤: 공백 든 경로 안내에 루트 절대경로가 나간다"
has   "$FIN" '그 상대경로에도 공백이 있으면' "글 일곱 ⑤: 상대경로 쪽 공백의 갈래가 있다"
has   "$FIN" '🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론' "§6 범례: 끝맺음 글에 표시 규칙 범례가 있다"

finish
