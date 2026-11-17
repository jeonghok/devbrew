#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/templates/interview-seed-template.md plugins/spec-distill/skills/pm-interview/references/seed-input.md plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/build_seed_inline_blob.py
#
# 원문이 받은 글자 그대로 남는 규약(raw-source canon)의 문면 락 — 기록 파일(audit) 템플릿의 `## 1` ·
# `## 2` 설명, seed 템플릿 · seed 입력 규약의 «seed 는 모델이 줄인 글» 문장, seed 리뷰 프로필의 읽는 법.
# `framing_fails` 는 실패한 항목 이름을 한 줄씩 낸다(빈 출력 = 통과). 항목마다 한 검사다 — 뒤 Task 가
# 같은 함수에 항목을 더한다. 변이 검사는 임시 사본을 같은 함수에 먹여 그 이름으로 실패하는지 본다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SK="$ROOT/plugins/spec-distill/skills/request-framing/SKILL.md"
AT="$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md"
ST="$ROOT/plugins/spec-distill/templates/interview-seed-template.md"
SI="$ROOT/plugins/spec-distill/skills/pm-interview/references/seed-input.md"
PR="$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md"
SCRIPTS="$ROOT/plugins/spec-distill/scripts"
if [ "${1:-}" = "--emit-scanned" ]; then
  for f in plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/templates/interview-seed-template.md \
           plugins/spec-distill/skills/pm-interview/references/seed-input.md plugins/spec-distill/references/docreview-profiles/seed.md \
           plugins/spec-distill/scripts/build_seed_inline_blob.py; do
    echo "$f"
  done
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

# 절 추출 — 시작 제목 줄부터 다음 `## ` 제목 앞까지.
sec() { awk -v h="$2" 'index($0,h)==1{f=1; next} /^## /{f=0} f' "$1"; }
has() { printf '%s\n' "$1" | grep -qF -- "$2"; }
# 줄 이음 — 줄바꿈과 뒤따르는 들여쓰기를 공백 하나로 바꾼다(문구가 줄에 걸쳐 감겨도 맞추려고).
join() { python3 -I -c 'import re,sys; sys.stdout.write(re.sub(r"\n[ \t]*", " ", sys.stdin.read()))'; }
# 소절 추출 — 시작 제목 줄부터 다음 `#` 제목 앞까지(제목 줄은 뺀다).
subsec() { awk -v h="$2" 'index($0,h)==1{f=1; next} /^#+ /{f=0} f' "$1"; }
# 문단 추출 — 그 글자가 든 첫 줄부터 다음 빈 줄 앞까지.
para() { awk -v h="$2" '!f&&index($0,h){f=1} f&&/^$/{exit} f' "$1"; }
# 겹침 문단(AC6) — 기본 브랜치(f0a437c0)의 글자 그대로. 이 브랜치는 이 문단을 고치지 않는다.
read -r -d '' OVERLAP_PIN <<'PINEOF'
**audit 템플릿 절 제목이 중복되면** — stderr 가 템플릿 제목이 여러 번 나온다고 대면(조립기의 「… 가 N번(줄 …)
나온다」 · `marks` 의 `duplicate_heading`) 사용자가 붙여 넣은 원문에 그 제목과 같은 줄이 있는 것이고, 손대지
않으면 매 라운드 같은 자리에서 막힙니다. 단독 `AskUserQuestion` 으로 「그 줄만 인용 표시로 감싼다 (권장) / 멈춘다」를
묻습니다. 설명은 이렇게 쓴다 — 「감싼다」: 얻음: 겹친 줄만 표시하고 번들 단계부터 다시 돈다 · 내줌: 원문 칸에 `> ` 를 붙이는 유일한 예외라 한 줄이 원문과 달라진다 / 「멈춘다」: 얻음: 원문 줄을 한 글자도 건드리지 않는다 · 내줌: 겹친 줄이 그대로라 리뷰가 시작되지 않고 원문을 고쳐 다시 불러야 한다. 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다. 「감싼다」면 audit `## 1. 원문` 안의 그 줄(들) 맨 앞에 `> ` 만 붙이고 나머지 글자는 그대로 둡니다 —
`## 1` append-only 의 유일한 예외입니다. 그 선택과 사용자 문구를 audit `## 5. degrade` 에 한 줄로 남기고
`### 번들` 부터 다시 돕니다.
PINEOF

# framing_fails <SKILL> <감사 템플릿> <seed 템플릿> <seed-input> <seed 프로필> — 실패한 항목 이름을 한 줄씩.
framing_fails() {
  local skill="$1" at="$2" st="$3" si="$4" pr="$5" s1 s2 body
  local T0; T0="$(mktemp -d)"
  s1="$(sec "$at" '## 1. 원문')"; s2="$(sec "$at" '## 2. 질문 전체')"
  has "$s1" 'token · key · credential 로 보이는 값은 쓰기 전에 가림 표시' || echo tpl_redaction
  has "$(printf '%s\n' "$s1" | join)" '라벨은 공백 없이 글자 · 숫자 · `.` · `_` · `-` 로 64자까지' || echo tpl_label_form
  {
    has "$s1" '`### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`' &&
    has "$s1" '설명 문장을 따로 두지 않는다' &&
    has "$s1" '그 밖의 줄은 전부 받은 글자 그대로다' &&
    has "$s1" '`### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다'
  } || echo tpl_separator
  # 템플릿의 구분 줄 머리(`### 받은 글 — ` 까지)가 호스트가 아는 패턴에 맞는가 — 패턴은 모듈에서 가져온다.
  local head
  head="$(printf '%s\n' "$s1" | grep -F '`### 받은 글 — <갈래>' | head -1 | sed 's/.*`\(### 받은 글 — \)<갈래>.*/\1/')"
  PYTHONDONTWRITEBYTECODE=1 python3 -I -c '
import sys
sys.path.insert(0, sys.argv[1])
import build_seed_inline_blob as m
sys.exit(0 if m.RECEIVED_SEPARATOR_RE.match(sys.argv[2] + "직접 친 글") else 1)
' "$SCRIPTS" "$head" 2>/dev/null || echo tpl_separator_regex
  {
    has "$s2" '  - 당신이 답한 것 (<라벨 | 적음 | 라벨 · 적음>): <고른 라벨 또는 적은 말 — one-line 을 거친 그대로, 답이 없으면 표시 없이 «(답 없음)»>' &&
    has "$s2" '`(라벨)`' && has "$s2" '`(적음)`' && has "$s2" '`(라벨 · 적음)`' &&
    has "$s2" '  - 내가 읽은 것: 「<풀이 문장>」 — <고름 | 고르지 않음>'
  } || echo tpl_answer_mark
  {
    has "$(cat "$st")" 'seed 는 다음 세션의 첫 턴에 넘기는, 모델이 줄인 글이다. 사용자의 말은 기록 파일(audit)의 원자료다.' &&
    has "$(cat "$si")" '다음 세션의 첫 턴에 넘기는, 모델이 줄인 글**이다. 사용자의 말은 seed 옆 기록 파일(audit)의 원자료다.' &&
    ! has "$(join < "$si")" '사용자가 확정한 메시지' &&
    ! has "$(join < "$si")" '그것이 이 세션의 최초 사용자 발화다'
  } || echo seed_role
  body="$(cat "$pr")"
  has "$body" '`### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다.' || echo profile_sep
  has "$body" '고른 사실과 그 뜻은 정답이지만, 라벨의 낱말 하나하나는 사용자가 쓴 글이 아니다.' || echo profile_label
  has "$body" '「라벨 · 적음」 이 붙은 답에서는 고른 라벨이 모델 문장이고 그 뒤의 적은 말은 사용자의 글이다' || echo profile_mixed

  # --- request-framing SKILL (Task 6) ---
  local sk sec_s sj p ex1 rec ext shl pin_s ptr
  sk="$(join < "$skill")"
  sec_s="$(subsec "$skill" '### 비밀값 가리기 — 사용자의 말을 쓰기 전에')"
  [ -n "$sec_s" ] || echo secret_section
  sj="$(printf '%s\n' "$sec_s" | join)"
  # 여덟 줄마다 그 줄에만 있는 글자를 든다 — 한 줄을 지우면 그 줄의 항목이 실패한다.
  for p in '받은 글(주제 질문의 답 포함)' '직접 적은 답' '«당신이 답한 것»' '«사용자가 적은 말»' '`said-r<n>.txt`' '결정 답과 거부 줄의 사용자 문구' \
           '막지 않는 질문의 답' '`said-hunk-<k>.txt`' '`said-extra-r<n>.txt`' '`## 5. degrade`'; do
    has "$sj" "$p" || echo "secret_path:$p"
  done
  has "$sj" '어느 길이든 쓰기 **전에**' || echo secret_before_write
  has "$sj" '가린 값 자체는 보이지 않는다' || echo secret_value_hidden
  has "$sj" '`:` 뒤의 라벨은 공백 없이 글자 · 숫자 · `.` · `_` · `-` 로 64자까지다' || echo secret_label_form
  { has "$sj" '`비밀값으로 보여 가린 곳 <N>개 — <라벨들>`' && has "$sj" '가린 것이 없으면 그 줄을 내지 않는다'; } || echo secret_report_line
  # 토큰 모양 집합 — 새 절 == 인터뷰 본문 「Secret 기록 금지」 문단, 각 토큰이 호스트의 P21 정규식에 맞는다.
  printf '%s\n' "$sec_s" > "$T0/sec.txt"
  para "$ROOT/plugins/spec-distill/skills/pm-interview/SKILL.md" '**Secret 기록 금지**' > "$T0/iv.txt"
  python3 -I -c '
import re, sys
sys.path.insert(0, sys.argv[1])
import brief_body
pat = re.compile(r"<[A-Z]{2,}(:[^>]*)?>")
def toks(path):
    return set(m.group(0) for m in pat.finditer(open(path, encoding="utf-8").read()))
a, b = toks(sys.argv[2]), toks(sys.argv[3])
ok = bool(a) and a == b and all(brief_body.P21_PLACEHOLDER_RE.fullmatch(x.replace("...", "x")) for x in a)
sys.exit(0 if ok else 1)
' "$SCRIPTS" "$T0/sec.txt" "$T0/iv.txt" 2>/dev/null || echo secret_tokens
  ex1="$(awk 'index($0,"1. **원문 보존**")==1{f=1} /^2\. \*\*레포 읽기\*\*/{f=0} f' "$skill" | join)"
  rec="$(para "$skill" '**기록** — 질문 · 선택지 · 답' | join)"
  ext="$(para "$skill" '- 추가 라운드를 여는 1단계는' | join)"
  shl="$(para "$skill" '**사용자 문구 · 리뷰어 요약은 셸 인자에 직접 쓰지 않는다.**' | join)"
  ptr='쓰기 전에 `### 비밀값 가리기` 대로 가린다'
  has "$ex1" "$ptr" || echo 'secret_pointer:확산 1'
  has "$rec" "$ptr" || echo 'secret_pointer:기록'
  has "$ext" "$ptr" || echo 'secret_pointer:추가 라운드'
  has "$shl" "$ptr" || echo 'secret_pointer:셸 인자'
  {
    has "$rec" '`(라벨)`' && has "$rec" '`(적음)`' && has "$rec" '`(라벨 · 적음)`' &&
    has "$rec" '추가 라운드 승인의 `label` · `typed` 와 같은 뜻이다'
  } || echo answer_mark
  {
    has "$ex1" '**질문 라운드에서 직접 적은 답도 이 절에 남긴다**' &&
    has "$ex1" '줄 나눔을 접지 않은 글자 그대로' &&
    has "$ex1" '구분 줄 말고는 저자의 줄을 더하지 않는다' &&
    has "$ex1" '고른 라벨만 있는 답은 덧붙이지 않는다'
  } || echo typed_append
  {
    has "$ex1" '`### 받은 글 — <갈래> · <준 이> · <날짜>[ · 라운드 <n> 의 답]`' &&
    has "$ex1" '설명 문장을 따로 두지 않고' &&
    has "$ex1" '그 밖의 줄은 전부 받은 글자 그대로다'
  } || echo separator_rule
  {
    has "$ex1" '「audit 템플릿 절 제목이 중복되면」 의 물음과 같은 물음' &&
    has "$ex1" '앞 공백을 뗀 머리가 `### ` 인 줄'
  } || echo overlap_same_question
  pin_s="$(awk 'index($0,"**audit 템플릿 절 제목이 중복되면**")==1{f=1} f{print} f&&index($0,"`### 번들` 부터 다시 돕니다.")==1{exit}' "$skill")"
  [ "$pin_s" = "$OVERLAP_PIN" ] || echo overlap_unchanged
  has "$sj" 'seed 에도 가린 글만 간다' || echo seed_redacted_only
  has "$sj" '저자가 쓰는 줄 — `## 2` 의 풀이 줄(「내가 읽은 것」) · `## 3. 긴 초안` · `## seed 에서 덜어 낸 것` 표의 항목 · 재결정 세 칸 — 에 사용자의 말을 옮길 때도 가린 글로 옮긴다(가리기 전 값을 옮겨 적지 않는다).' || echo secret_author_lines
  { has "$sj" 'seed 는 긴 초안을 깎아 만들고 긴 초안도 가린 글로 쓰므로 seed 에도 가린 글만 간다' && ! has "$sj" 'seed 는 가린 audit 에서 압축하므로'; } || echo secret_seed_rationale
  has "$(sec "$at" '## 3. 긴 초안' | join)" '사용자의 말을 옮길 때는 가린 글로 옮긴다(`## 1. 원문` 과 같은 가림 표시).' || echo tpl_long_draft_redaction
  has "$sk" '답이 없으면 표시 없이 «(답 없음)» 이다' || echo answer_none_mark
  has "$ex1" '그 줄 앞에 `> ` 만 붙여 쓴다' || echo wrap_prefix_only
  { ! has "$sk" '스스로 고쳐 쓴다' && has "$sk" '저자가 그 줄을 스스로 고쳐 쓰지 않는다'; } || echo self_rewrite
  rm -rf "$T0"
}

# 실제 파일 — 빈 출력이면 통과.
FF="$(framing_fails "$SK" "$AT" "$ST" "$SI" "$PR")"
[ -z "$FF" ] && ok "framing_fails: 실제 파일 전 항목 통과" || no "framing_fails 실패 항목: $(printf '%s' "$FF" | tr '\n' ' ')"

# 변이 — 임시 사본에서 첫 출현만 바꿔 그 이름으로 실패하는지 본다(통과가 정답인 락의 이빨).
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mutate() { # <원본> <사본> <옛> <새> — 첫 출현만(새가 비면 삭제). 안 바뀌면 rc 1.
  python3 -I - "$1" "$2" "$3" "$4" <<'PY'
import sys
src, dst, old, new = sys.argv[1:5]
t = open(src, encoding="utf-8").read()
if old not in t:
    sys.exit(1)
open(dst, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
}
expect_fail() { # <항목> <at> <st> <si> <pr>
  local want="$1" out; shift
  out="$(framing_fails "$SK" "$1" "$2" "$3" "$4")"
  if printf '%s\n' "$out" | grep -qxF "$want"; then ok "변이 → $want 로 실패"; else no "변이가 $want 로 실패하지 않았다(출력: $(printf '%s' "$out" | tr '\n' ' '))"; fi
}
mutate "$AT" "$T/at1.md" '쓰기 전에 가림 표시' '쓴 뒤 가림 표시' && expect_fail tpl_redaction "$T/at1.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_redaction"
mutate "$AT" "$T/at2.md" '### 받은 글 — ' '### 받은글 — ' && expect_fail tpl_separator "$T/at2.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_separator"
mutate "$AT" "$T/at3.md" '`(라벨 · 적음)`' '' && expect_fail tpl_answer_mark "$T/at3.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_answer_mark"
mutate "$SI" "$T/si1.md" '다음 세션의 첫 턴에 넘기는, 모델이 줄인 글' '**Phase 0 에서 사용자가 확정한 메시지' && expect_fail seed_role "$AT" "$ST" "$T/si1.md" "$PR" || no "변이 준비 실패: seed_role"
mutate "$PR" "$T/pr1.md" '라벨의 낱말 하나하나는 사용자가 쓴 글이 아니다.' '' && expect_fail profile_label "$AT" "$ST" "$SI" "$T/pr1.md" || no "변이 준비 실패: profile_label"

# 옛 문구를 줄 둘에 걸쳐 되살리면 seed_role 이 잡아야 한다(줄 이음 — 줄 나눔으로 빠져나가지 못한다).
cp "$SI" "$T/si2.md" && printf '\n그것이 이 세션의\n최초 사용자 발화다\n' >> "$T/si2.md" && expect_fail seed_role "$AT" "$ST" "$T/si2.md" "$PR"

# SKILL 변이 — 사본을 SKILL 자리에 먹인다.
expect_fail_sk() { # <항목> <SKILL 사본>
  local want="$1" out
  out="$(framing_fails "$2" "$AT" "$ST" "$SI" "$PR")"
  if printf '%s\n' "$out" | grep -qxF "$want"; then ok "변이 → $want 로 실패"; else no "변이가 $want 로 실패하지 않았다(출력: $(printf '%s' "$out" | tr '\n' ' '))"; fi
}
mutate "$SK" "$T/sk1.md" '사용자 문구는 쓰기 전에 `### 비밀값 가리기` 대로 가린다' '사용자 문구는' && expect_fail_sk 'secret_pointer:셸 인자' "$T/sk1.md" || no "변이 준비 실패: secret_pointer:셸 인자"
mutate "$SK" "$T/sk2.md" '`<KEY:...>`' '`<KEYS:...>`' && expect_fail_sk secret_tokens "$T/sk2.md" || no "변이 준비 실패: secret_tokens"
mutate "$SK" "$T/sk3.md" '- 제목 줄 겹침 물음의 선택과 문구 — `## 5. degrade` 한 줄' '- 제목 줄 겹침 물음의 선택과 문구' && expect_fail_sk 'secret_path:`## 5. degrade`' "$T/sk3.md" || no "변이 준비 실패: secret_path"
mutate "$SK" "$T/sk4.md" $'고른 라벨만\n   있는 답은 덧붙이지 않는다. ' '' && expect_fail_sk typed_append "$T/sk4.md" || no "변이 준비 실패: typed_append"
mutate "$SK" "$T/sk5.md" '(권장) / 멈춘다」를' '/ 멈춘다」를' && expect_fail_sk overlap_unchanged "$T/sk5.md" || no "변이 준비 실패: overlap_unchanged"
mutate "$AT" "$T/at4.md" '라벨은 공백 없이 글자 · 숫자 · `.` · `_` · `-` 로 64자까지' '라벨은 아무 글자나' && expect_fail tpl_label_form "$T/at4.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_label_form"
mutate "$SK" "$T/sk6.md" '저자가 그 줄을 스스로 고쳐 쓰지 않는다' '저자가 그 줄을 스스로 고쳐 쓴다' && expect_fail_sk self_rewrite "$T/sk6.md" || no "변이 준비 실패: self_rewrite"
mutate "$SK" "$T/sk7.md" '`:` 뒤의 라벨은 공백 없이' '`:` 뒤의 라벨은 공백도 넣어' && expect_fail_sk secret_label_form "$T/sk7.md" || no "변이 준비 실패: secret_label_form"
mutate "$SK" "$T/sk8.md" $'- `## 1. 원문` 의 받은 글(주제 질문의 답 포함)\n' '' && expect_fail_sk 'secret_path:받은 글(주제 질문의 답 포함)' "$T/sk8.md" || no "변이 준비 실패: secret_path 첫 줄"
mutate "$SK" "$T/sk9.md" $'- 결정 답과 거부 줄의 사용자 문구(`said-<id>.txt`)\n' '' && expect_fail_sk 'secret_path:결정 답과 거부 줄의 사용자 문구' "$T/sk9.md" || no "변이 준비 실패: secret_path 넷째 줄"
mutate "$SK" "$T/sk10.md" '어느 길이든 쓰기 **전에**' '어느 길이든 쓴 **뒤에**' && expect_fail_sk secret_before_write "$T/sk10.md" || no "변이 준비 실패: secret_before_write"
mutate "$SK" "$T/sk11.md" '가린 값 자체는 보이지 않는다' '가린 값도 함께 보인다' && expect_fail_sk secret_value_hidden "$T/sk11.md" || no "변이 준비 실패: secret_value_hidden"
mutate "$SK" "$T/sk12.md" 'seed 에도 가린 글만 간다' 'seed 에는 그대로 간다' && expect_fail_sk seed_redacted_only "$T/sk12.md" || no "변이 준비 실패: seed_redacted_only"
mutate "$SK" "$T/sk13.md" '답이 없으면 표시 없이 «(답 없음)» 이다' '답이 없으면 비워 둔다' && expect_fail_sk answer_none_mark "$T/sk13.md" || no "변이 준비 실패: answer_none_mark"
mutate "$SK" "$T/sk14.md" '그 줄 앞에 `> ` 만 붙여 쓴다' '그 줄을 알맞게 다듬어 쓴다' && expect_fail_sk wrap_prefix_only "$T/sk14.md" || no "변이 준비 실패: wrap_prefix_only"
mutate "$SK" "$T/sk15.md" $'저자가 쓰는 줄 — `## 2` 의 풀이 줄' '저자 줄 — `## 2` 의 풀이 줄' && expect_fail_sk secret_author_lines "$T/sk15.md" || no "변이 준비 실패: secret_author_lines"
mutate "$SK" "$T/sk16.md" 'seed 는 긴 초안을 깎아 만들고 긴 초안도 가린 글로 쓰므로 seed 에도' 'seed 는 가린 audit 에서 압축하므로 seed 에도' && expect_fail_sk secret_seed_rationale "$T/sk16.md" || no "변이 준비 실패: secret_seed_rationale"
mutate "$AT" "$T/at5.md" '사용자의 말을 옮길 때는 가린 글로 옮긴다' '' && expect_fail tpl_long_draft_redaction "$T/at5.md" "$ST" "$SI" "$PR" || no "변이 준비 실패: tpl_long_draft_redaction"

finish
