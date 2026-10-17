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
n_keep="$(flat "$C" | grep -o '빼면 표에 남긴다' | wc -l | tr -d ' ')"
[ "$n_keep" -ge 3 ] && ok "AC2: 세 물음 각각이 「빼면 표에 남긴다」를 말한다(셋 중 하나만 지워도 red) — $n_keep 회" \
  || no "AC2: 「빼면 표에 남긴다」가 $n_keep 회 — 셋보다 적다"
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
# 되살린 링크 · 문법 밖 글자는 말로 옮기고, 옮긴 문장은 원문이 아니라고 게이트 앞 줄이 밝힌다
has   "$RF" '`<` 는 「미만」, `[긴급]` 은 「긴급:」, 목록은 한 문장으로 옮깁니다' "I2: 되살린 항목의 문법 밖 글자를 말로 옮기는 규칙이 있다"
has   "$RF" '`되살림 — 말로 옮김 · 링크는 이 표에`' "I2: 되살린 링크 행의 「되살림」 칸이 링크가 표에 남는다고 적는다"
has   "$RF" '`말로 옮겨 되살림 — 원문 아님` 을 싣습니다' "I2: 다시 띄우는 공시 줄이 옮긴 문장을 원문 아님으로 밝힌다"
has   "$C"  '`말로 옮겨 되살림 — 원문 아님` 으로 밝힌다' "I2: 압축 규약의 덜어 낸 것 절이 같은 규칙을 한 줄로 비춘다"
hasnt "$RF" '링크를 seed 에 되살' "I2(부재): 되살린 링크를 seed 에 그대로 넣으라는 문면이 없다"
hasnt "$C"  '링크를 seed 에 되살' "I2(부재): 압축 규약도 링크를 seed 에 되살리라고 하지 않는다"
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
has   "$SI" '「전체 과정으로」면 3.5 로 갑니다' "ledger3: spec-interview 의 「전체 과정으로」는 3.5(seed 아닌 입력 조언)를 거친다"
hasnt "$SI" '「전체 과정으로」면 4 로 갑니다' "ledger3(부재): 3.5 를 건너뛰고 4 로 가는 문면이 없다"
has   "$TE" '진입 skill 이 정한 다음 단계(request-framing `### 4.` · spec-interview `### 3.5`)로 간다' "ledger3: trivia-escape 의 「전체 과정으로」는 진입 skill 별 다음 단계를 댄다"
hasnt "$TE" '(`### 4.`)로 간다' "ledger3(부재): trivia-escape 가 spec-interview 의 3.5 를 건너뛰는 단일 `### 4.` 를 말하지 않는다"

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
# 통합(R3 묶음 모드): 원문 대조의 자리는 brief 만이 아니라 source_interview 가 가리키는 파일 — 에픽 묶음이면 묶음의 사용자 원문 절
has   "$DP" '사용자 원문(frontmatter `source_interview` 가 가리키는 파일(brief · 에픽 묶음)의 §6)에 있는지 인용으로 대조한다' "AC5 통합: 설계문서 원문 대조가 brief · 에픽 묶음 둘 다의 §6 을 가리킨다"
hasnt "$DP" '`source_interview` 가 가리키는 brief 의 §6' "AC5 통합(부재): 원문 대조가 brief 의 §6 만 가리키는 옛 문면이 없다"

# ── Task 5 — payload §6 전량 · 추가만 (AC11) ──
RB="$SD/skills/reviewing-brief/SKILL.md"; BT="$SD/templates/interview-brief-template.md"; FN="$SD/skills/spec-interview/references/finishing.md"
hasnt "$RB" '**불변** — 어떤 처분도 닿지 못한다' "AC11(부재): 수정 권한 표에 payload §6 「불변」이 없다"
has   "$RB" '**추가만** — 이미 있는 원문 글자는 어떤 처분도 고치지 못한다' "AC11: 수정 권한 표에 payload §6 「추가만」이 있다"
has   "$RB" '결정 발화를 새 `S<N>` 으로 payload §6 끝 · audit §6 · state `user_statements` 에 **같은 write** 로 **추가**한다' "AC11: 결정 발화를 payload §6 · audit §6 · state 에 같은 write 로 더한다"
has   "$BT" '결정 발화는 새 `S<N>` 으로 이 절 끝 · audit §6 · state `user_statements` 에 같은 write 로 더한다' "AC11: brief 템플릿 §6 이 결정 발화를 세 자리에 같은 write 로 더한다고 말한다"
has   "$BT" '추가만 허용' "AC11: brief 템플릿 §6 이 추가만 허용을 말한다"
hasnt "$BT" '최초 요청 원문 하나만' "N7(부재): brief 템플릿 §6 의 「S1 하나만」이 없다"
hasnt "$FN" '§6 은 `S1` 만(N1b)' "N7(부재): finishing 머리 문단의 「§6 은 S1 만」이 없다"
hasnt "$C"  '§6 은 `S1` 만(N1b)' "N7(부재): 압축 규약의 「§6 은 S1 만」이 없다"
has   "$C"  'S1~Sn 전부(N1b)' "N7: 압축 규약이 §6 은 S1~Sn 전부라고 말한다"

# ── Task 7 — 인터뷰 끝내기 (AC8 · AC10 · AC12 · AC16c · AC16d) ──
SIN="$SD/skills/spec-interview/references/seed-input.md"
has   "$FN" '확정으로 올리지 않은 발화 <N>개 — S<n> · <한 줄 이유>' "AC10: B-0 에 안 올린 발화 줄이 있다"
has   "$FN" '위험으로 보낸 참고 <N>개 — <id> · <이유>' "AC10: B-0 에 위험으로 보낸 참고 줄이 있다"
has   "$FN" '§1 의 줄마다 출처' "AC16d(N21): B-0 이 §1 을 출처와 함께 보인다"
has   "$FN" '「계속 고친다(2번 더)」' "AC12: 재제시 상한에 「계속 고친다」 선택이 있다"
has   "$FN" '「지금 목록으로 확정」' "AC12: 재제시 상한에 「지금 목록으로 확정」 선택이 있다"
has   "$FN" '「brief 만 종료」' "AC12: 재제시 상한에 「brief 만 종료」 선택이 있다"
hasnt "$FN" '모든 항목을 잠정(provisional)으로 둔다' "AC12(부재): 자동 강등 고정 문자열이 없다"
hasnt "$FN" '전 항목을 `provisional`로 강등' "AC12(부재): 자동 강등 문면이 없다"
has   "$FN" '자동 강등은 없다' "AC12: 자동 강등이 없음을 말한다"
BA="$(awk '/^#### B-A/{f=1;print;next} /^#### /{f=0} f' "$FN" | tr '\n' ' ' | tr -s ' ')"
for lit in '접는 줄(`… 외 K건`)이 있으면' '「참고 전부 보기」' '「접은 채로 둔다」' 'python3 -I -X utf8 -c'; do
  assert_contains "$BA" "$lit" "AC8(brief): B-A 블록에 「${lit}」 가 있다"
done
has   "$FN" '이 폴더의 `seed-input.md`' "포인터: B-0 이 같은 폴더의 seed-input.md 를 가리킨다"
has   "$FN" '§5 `위험 — 리뷰 참고` 줄은 같은 write 에서 지운다' "B-0: 위험 참고를 §3 으로 올리면 §5 줄을 지운다"
hasnt "$FN" '방향 · overdesign(참고 축)은 라운드 게이트에 오지 않았습니다' "N1(부재): 방향이 참고 축이라는 B-2 문장이 없다"
hasnt "$FN" '리뷰가 payload를 수정할 수 있습니다(§0·§2' "§2-4(부재): Step A.5 의 §0·§2 문장이 없다"
has   "$SIN" '출처를 가르지 못한 seed 문장 <N>개 — 붙여넣기라 분류기를 못 돌림' "AC16c(N15): 붙여넣기 경로가 출처를 못 가른 문장 수를 공시한다"

# ── Task 8 — 비용 문장 · 냉독 · 참고 전부 보기 (AC8 · AC9 · AC13) ──
SR="$SD/skills/spec-review/SKILL.md"; RM="$SD/README.md"
for f in "$FN" "$RB" "$RM"; do
  hasnt "$f" '지출 통제는 엔진의 재리뷰 상한' "AC13(부재): $(basename "$f") 에 「지출 통제는 엔진의 재리뷰 상한」이 없다"
  has   "$f" '재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다' "AC13: $(basename "$f") 에 안전 정지 문장이 있다"
done
hasnt "$RB" '이 자리의 지출 통제가 그것이다' "AC13(부재): reviewing-brief 의 「이 자리의 지출 통제」가 없다"
hasnt "$RM" '지출 상한은 엔진의 재리뷰 상한이 맡는다' "AC13(부재): README P22 의 옛 문장이 없다"
has   "$RB" '| G7 | **그 밖** —' "AC9: 냉독 분류에 「그 밖」이 있다"
hasnt "$RB" '**닫힌 여섯 클래스**다' "N10(부재): 냉독 분류가 닫힌 여섯이 아니다"
has   "$RB" '`fix_anchors` §0 · §2~§5' "§3-2: reviewing-brief 가 넓힌 fix_anchors 를 댄다"
hasnt "$RB" '`fix_anchors` §0·§2' "§3-2(부재): 옛 fix_anchors 문장이 없다"
hasnt "$RB" '방향 · overdesign 항목은' "§3-2(부재): 방향을 참고로 부르는 문장이 없다"
has   "$SR" '「참고 전부 보기」' "AC8(spec-review): 설계문서 승인 게이트 앞에 참고 전부 보기가 있다"
has   "$SR" '<!-- advice-display:end -->' "AC8(양성 짝): advice 표시 펜스 표지가 그대로다"
# 「참고 전부 보기」 펜스 — 원장이 없으면 「목록 없음」 한 줄로 끝나고, 있으면 전부를 내되 원장 폴더에는 아무것도 쓰지 않는다.
# 스텁은 R7 의 실제 계약을 흉내 낸다: state-dir-for 는 `--session` 을 받으면 rc 2, advice 는 정확히 `--state-dir <x>` 가 아니면 rc 3,
# path-inside 는 ADV_OUTSIDE=1 이면 rc 1(관문이 STATE_DIR 을 비워야 한다).
ALLF="$(awk -v b='<!-- advice-all:begin -->' -v e='<!-- advice-all:end -->' 'index($0,b){f=1;next} index($0,e){f=0} f&&/^```bash$/{c=1;next} f&&c&&/^```$/{c=0;next} f&&c' "$SR")"
[ -n "$ALLF" ] && ok "전제(ledger1): advice-all 펜스를 뽑았다" || no "전제(ledger1): advice-all 펜스가 비었다 — 아래 칸이 공허하다"
assert_contains "$ALLF" '[ -z "${STATE_DIR:-}" ] || [ ! -f "$STATE_DIR/docreview-state.md" ]' "ledger1: 참고 전부 보기 펜스가 빈 STATE_DIR · 원장 부재를 가린다"
AT="$(mktemp -d -t sd-advall-XXXXXX)" || exit 1
mkdir -p "$AT/root/scripts" "$AT/sd" "$AT/tmp"
printf '%s\n' 'import sys, os' 'a = sys.argv[1:]' \
  'sys.exit(1 if a[0] == "path-inside" and os.environ.get("ADV_OUTSIDE") == "1" else 0) if a[0] == "path-inside" else print("stub")' > "$AT/root/scripts/state_path.py"
printf '%s\n' 'import sys, os' 'a = sys.argv[1:]' \
  'if a[0] == "state-dir-for" and "--session" in a: sys.exit(2)' \
  'if a[0] == "advice" and (len(a) != 3 or a[1] != "--state-dir"): sys.exit(3)' \
  'print(os.environ["ADV_SD"]) if a[0] == "state-dir-for" else print("{\"items\": [{\"category\": \"overdesign\", \"anchor\": \"x\", \"summary\": \"y\"}, {\"category\": \"overdesign\", \"anchor\": \"z\", \"summary\": \"w\"}]}")' > "$AT/root/scripts/docreview_state.py"
adv_run() { (cd "$AT" && CLAUDE_PLUGIN_ROOT="$AT/root" ADV_SD="$AT/sd" TMPDIR="$AT/tmp" spec_path="$AT/doc.md" bash -c "$ALLF" 2>&1); }
adv_out="$(adv_run)"; adv_rc=$?
{ [ "$adv_rc" -eq 0 ] && [ -z "$(ls -A "$AT/sd")" ] && printf '%s' "$adv_out" | grep -qF '참고(advisory) 목록 없음'; } \
  && ok "ledger1: 원장 없는 STATE_DIR 에서 「목록 없음」 한 줄로 끝나고 원장 폴더에 쓰지 않는다" \
  || no "ledger1: rc=$adv_rc out=$(printf '%s' "$adv_out" | head -c 200)"
: > "$AT/sd/docreview-state.md"
chmod a-w "$AT/sd"   # 원장 폴더에 쓰려 하면(잠깐 쓰고 지워도) 실패해 양성 짝이 RED 가 된다
adv_out="$(adv_run)"; adv_rc=$?
chmod u+w "$AT/sd"
{ [ "$adv_rc" -eq 0 ] && printf '%s' "$adv_out" | grep -qF '참고 전부 2건' && printf '%s' "$adv_out" | grep -qF -- '- [overdesign] x — y' \
    && printf '%s' "$adv_out" | grep -qF -- '- [overdesign] z — w' && ! printf '%s' "$adv_out" | grep -qF '목록 없음' && ! printf '%s' "$adv_out" | grep -qF '실패'; } \
  && ok "ledger1(양성 짝): 원장이 있으면 「목록 없음」 없이 목록 전부를 낸다" || no "ledger1(양성 짝): rc=$adv_rc out=$(printf '%s' "$adv_out" | head -c 300)"
[ "$(ls -A "$AT/sd")" = "docreview-state.md" ] && ok "ledger1: 표지를 푼 뒤라 원장 폴더에 아무것도 쓰지 않는다" || no "ledger1: 원장 폴더에 새 파일: $(ls -A "$AT/sd" | tr '\n' ' ')"
[ -z "$(ls -A "$AT/tmp")" ] && ok "ledger1: 임시 파일을 지우고 끝난다" || no "ledger1: 임시 파일이 남았다: $(ls -A "$AT/tmp" | tr '\n' ' ')"
adv_out="$(ADV_OUTSIDE=1 adv_run)"
{ printf '%s' "$adv_out" | grep -qF '참고(advisory) 목록 없음' && ! printf '%s' "$adv_out" | grep -qF '참고 전부'; } \
  && ok "ledger1: path-inside 관문이 거부하면 STATE_DIR 을 비우고 「목록 없음」으로 끝난다" || no "ledger1: 관문 거부 뒤에도 원장을 읽었다: $(printf '%s' "$adv_out" | head -c 200)"
rm -rf "$AT"

# ── Task 9 — 라운드 공시 (AC15 · AC16c) ──
has "$SI" '사실로 보고 직접 답한 질문 <N>개' "AC15: 라운드 요약에 사실로 보고 직접 답한 질문 수가 있다"
has "$SI" '밀린 질문 <N>개' "AC15: 우선순위에 밀린 질문 목록이 있다"
has "$SI" '줄인 사실 <N>개' "AC16c(N16): «지금 이해»에 줄인 사실 수가 있다"
has "$SI" '「전부 보기」' "AC16c(N16): 줄인 사실을 「전부 보기」로 펼친다"
has "$SI" '### 지금 이해' "AC15(양성 짝): 라운드 규약 템플릿이 그대로 있다"

# ── Task 10 — 릴리스 표면 (AC18) ──
PJ="$SD/.claude-plugin/plugin.json"; CL="$SD/CHANGELOG.md"
PJ_MAJOR="$(sed -n 's/.*"version": *"\([0-9][0-9]*\)\..*/\1/p' "$PJ" | head -1)"
[ -n "$PJ_MAJOR" ] && [ "$PJ_MAJOR" -ge 7 ] && ok "AC18: spec-distill 버전의 major 가 7 이상이다" || no "AC18: spec-distill 버전의 major 가 7 이상이다: '${PJ_MAJOR}'"
assert_grep "$(grep -A2 -F '## [7.0.0] — 2026-10-17' "$CL")" '그래서 major\.$' "AC18: CHANGELOG 에 7.0.0 릴리스 항목과 그래서 major 줄이 있다"
has "$RM" '덜어 낸 것' "Law 3: README 가 덜어 낸 것 공시를 말한다"

finish
