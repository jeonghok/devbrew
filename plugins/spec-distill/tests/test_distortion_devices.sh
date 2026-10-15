#!/usr/bin/env bash
# R2 문면 락 — docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md 의 AC 가 문면에 남긴 리터럴.
# 줄바꿈을 공백 하나로 접은 본문(flat)에서 잰다. 부재 단언마다 같은 파일의 존재 단언(양성 짝)을 둔다 —
# 파일이 사라지면 부재 단언은 공허하게 통과하기 때문이다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
flat() { if [ -f "$1" ]; then tr '\n' ' ' < "$1" | tr -s ' '; else printf '__MISSING__ %s' "$1"; fi; }
has()   { assert_contains "$(flat "$1")" "$2" "$3"; }
hasnt() { assert_not_contains "$(flat "$1")" "$2" "$3"; }
fm_line() { awk -v k="$2" 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&index($0,k)==1{print;exit}' "$1"; }

# ── Task 2 — 압축 규약 · request-framing · seed 템플릿 · seed 프로필 ──
C="$SD/references/compression.md"; RF="$SD/skills/request-framing/SKILL.md"
ST="$SD/templates/interview-seed-template.md"; SP="$SD/references/docreview-profiles/seed.md"
# AC2 — 세 물음은 「빼면 표에 남긴다」, 고정점 문면은 그대로
has   "$C" '빼면 표에 남긴다' "AC2: 압축 규약의 세 물음이 「빼면 표에 남긴다」를 말한다"
hasnt "$C" '어차피 맞게 할 거면 뺀다.' "AC2(부재): 「어차피 맞게 할 거면 뺀다.」 단독 문장이 없다"
hasnt "$C" '있으면 뺀다.' "AC2(부재): 「있으면 뺀다.」 단독 문장이 없다"
has   "$C" '## 상한을 두지 않는다' "AC2(고정점): 「상한을 두지 않는다」 절이 그대로다"
has   "$C" '확인은 저자가 다시 쓸 수 없는 고정점이다' "AC2(고정점): 확정 표시 고정점 문장이 그대로다"
has   "$C" '링크를 근거로 세우지 말라' "AC2(고정점): URL 비권위화 문장이 그대로다"
has   "$C" '## seed 에서 덜어 낸 것' "§1-1: 압축 규약이 덜어 낸 것 표 자리를 이름으로 댄다"
# AC1 · AC4 — request-framing 게이트 앞 공시와 되살리기
has   "$RF" 'seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>' "AC1: seed 게이트 앞에 덜어 낸 것 공시 줄이 있다"
has   "$RF" '「되살리기」' "AC1: 되살리기 선택이 있다"
has   "$RF" '「되살림」 칸' "AC1: 되살린 항목이 표의 「되살림」 칸에 표시된다"
has   "$RF" '확인받지 못한 풀이 <N>개 — <seed 문장 위치>' "AC4: seed 게이트 앞에 확인받지 못한 풀이 공시 줄이 있다"
has   "$RF" '사용자가 적은 말' "§1-9: 확인 질문 기록이 사용자가 적은 말 칸을 말한다"
hasnt "$RF" 'seed 로 나가는 것은 깎은 것뿐' "RC31(부재): 「seed 로 나가는 것은 깎은 것뿐」이 없다"
# N9 — seed 템플릿 「쓰지 말 것」도 표를 거친다
has   "$ST" '## seed 에서 덜어 낸 것' "N9: seed 템플릿 「쓰지 말 것」이 덜어 낸 것 표를 가리킨다"
has   "$ST" '## 쓰지 말 것' "N9(양성 짝): 「쓰지 말 것」 절이 남아 있다"
# AC6(seed) — layer1 · must_catch 에 omission, ground_truth 에 사용자가 적은 말
assert_eq "$(fm_line "$SP" '  layer1:')" "  layer1: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]" "AC6: seed layer1 에 omission 이 있다"
assert_eq "$(fm_line "$SP" 'must_catch:')" "must_catch: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]" "AC6: seed must_catch 에 omission 이 있다(참고 축이 없는 프로필)"
assert_contains "$(fm_line "$SP" 'ground_truth:')" '사용자가 적은 말' "§1-9: seed ground_truth 가 사용자가 적은 말 칸을 정답으로 싣는다"
has   "$SP" '- `omission` —' "§2-4: seed 프로필 본문에 omission 범주 정의 줄이 있다"
has   "$SP" '덜어 낸 것 표' "§2-4: seed 층 1 머리 · 판정 관계가 덜어 낸 것 표를 대조 자리로 댄다"

finish
