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

# ── Task 3 — trivia 우회 앞 질문 (N11 · AC16a) ──
TE="$SD/references/trivia-escape.md"; SI="$SD/skills/spec-interview/SKILL.md"
has   "$TE" '사소한 일로 보고 게이트를 건너뛴다 — 그대로 / 전체 과정으로' "AC16a: 우회 전에 「그대로 / 전체 과정으로」 질문이 있다"
has   "$TE" '맞은 패턴: <해당 패턴 이름>' "AC16a: 질문에 맞은 패턴 이름이 보인다"
has   "$TE" 'label: "전체 과정으로"' "AC16a: 「전체 과정으로」 선택지가 있다"
has   "$TE" 'label: "그대로"' "AC16a: 「그대로」 선택지가 있다"
has   "$TE" '「풀린 입력」의 첫 토큰이 정확히 `force` 면 그 토큰을 떼고 이 판정을 건너뛴다 — 나머지가 「풀린 입력」이 된다' "AC16a: 첫 토큰 force 경로가 그대로다"
hasnt "$TE" '해당하면 다음 메시지를 출력하고 진행하지 않는다' "N11(부재): 묻지 않고 안내만 내고 끝내는 옛 문면이 없다"
for f in "$RF" "$SI"; do
  has "$f" '「전체 과정으로」' "N11: $(basename "$(dirname "$f")") 의 trivia 단계가 「전체 과정으로」 분기를 말한다"
done

# ── Task 4 — 리뷰 프로필 (AC5 · AC6 · AC7 · AC16b) ──
BP="$SD/references/docreview-profiles/brief.md"; DP="$SD/references/docreview-profiles/design-doc.md"
for P in "$BP" "$DP"; do
  N="$(basename "$P")"
  hasnt "$P" '번호가 작은 쪽' "AC5($N): 「번호가 작은 쪽」 사다리가 없다"
  hasnt "$P" '한 판정자가 한 라운드에' "AC5($N): 판정자당 라운드 상한이 없다"
  hasnt "$P" '2N+α' "AC5($N): 상한 총량 문구가 없다"
  hasnt "$P" '### 상한' "AC5($N): 「상한」 절이 없다"
  has   "$P" '자르지 않는 쪽' "AC5($N): 비기면 자르지 않는 쪽이다"
  has   "$P" '두 해석을 함께 `decide` 로' "AC5($N): 해석이 갈리면 두 해석을 함께 decide 로"
  has   "$P" '이 문서는 이미 최소다' "AC5($N)(양성 짝): 0건 출구 문구는 남는다"
  has   "$P" '근거를 한두 줄 붙일 수 있다' "AC5($N): 0건 출구에 근거를 허용한다"
  hasnt "$P" '**정당화**도 「찾아봤으나 없음」 서술도 붙이지 않는다' "AC5($N)(부재): 0건 근거 금지 문장이 없다"
  has   "$P" '인용으로 대조한다' "AC5($N): 자르라는 판정은 사용자 원문과 인용으로 대조한다"
  has   "$P" '네 개씩 여러 번 나눠 묻는다' "§2-3($N): 게이트 질문은 넷씩 여러 번"
  has   "$P" '대체안은 같은 항목 안에 필수다' "보안($N): 대체안 필수 규약이 남는다"
  has   "$P" '└ 천장' "보안($N): 천장 규약이 남는다"
  has   "$P" 'Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다' "보안($N): 자르지 않는 것 — Law 와 kill switch 줄이 남는다"
done
assert_eq "$(fm_line "$BP" 'fix_anchors:')" 'fix_anchors: ["^0\\.", "^2\\.", "^3\\.", "^4\\.", "^5\\."]' "AC6: brief fix_anchors 가 §0 · §2~§5 다"
assert_eq "$(fm_line "$BP" 'immutable:')" 'immutable: ["^6\\."]' "AC6: brief §6 immutable 은 그대로다"
assert_eq "$(fm_line "$BP" 'protected_headings:')" 'protected_headings: ["^1\\."]' "AC6: brief §1 protected 는 그대로다"
assert_eq "$(fm_line "$BP" 'must_catch:')" 'must_catch: [direction, distortion, omission, invention, provenance_mislabel, authority_syntax, evidence_unsupported]' "AC7: brief must_catch 에 direction 이 있다"
has   "$BP" '`fix` 는 §0 · §2~§5 에 낼 수 있다' "§2-4: brief 처분 안내의 fix 자리가 frontmatter 와 같다"
hasnt "$BP" '`fix` 는 §0·§2 에만 낼 수 있다' "§2-4(부재): 옛 fix 자리 문장이 없다"
has   "$BP" '§2~§5 가 §6 원문을 어떻게 옮겼는지' "§2-4: brief 층 2 가 §2~§5 를 본다"
hasnt "$BP" '§2 요약이 §6 원문을 어떻게 옮겼는지만 본다' "§2-4(부재): 층 2 가 §2 만 보는 문장이 없다"
has   "$DP" '사용자가 요청한 동작을 자르는 지적은 범주를 `scope` 로' "AC16b: 설계문서 프로필이 사용자 요청 자르기를 scope 로 낸다"
assert_eq "$(fm_line "$DP" 'must_catch:')" 'must_catch: [goal_fit, problem_definition, scope, architecture]' "AC16b: 설계문서 must_catch 는 바뀌지 않는다"

finish
