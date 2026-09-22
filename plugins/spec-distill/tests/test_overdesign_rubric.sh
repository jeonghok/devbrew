#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# 설계자 시선 축(`overdesign`)이 두 문서 자리의 프로필 본문에 실제로 서 있는가.
# 축 «이름»만 layer1 에 넣으면 리뷰어는 그 축이 무엇을 묻는지 어디서도 못 읽는다 —
# 이름은 rubric 목록이, 내용은 본문 절이 진다.
#
# 이 락이 재는 것은 «문구의 실재»다. 리뷰어의 실제 판정이 그 절차를 따랐는지는 못 잰다
# (설계 §7 「상한의 무이빨」과 같은 종류의 한계 — 공시하고 닫지 않는다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'plugins/spec-distill/references/docreview-profiles/brief.md' \
                  'plugins/spec-distill/references/docreview-profiles/design-doc.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
B="plugins/spec-distill/references/docreview-profiles/brief.md"
D="plugins/spec-distill/references/docreview-profiles/design-doc.md"

# 본문만 본다 — frontmatter 가 문구를 만족시키면 본문을 지워도 GREEN 이 되는 함정을 막는다.
body_of() { awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "$1"; }
BB="$(body_of "$B")"; DB="$(body_of "$D")"
[ -n "$BB" ] && [ -n "$DB" ] \
  && ok "양의 짝: 두 프로필 본문을 읽었다 (아래 전부가 공허하지 않다)" \
  || { no "프로필 본문 추출 실패 — 아래 전부가 공허하다"; finish; exit; }

has() {   # has <본문> <문구> <설명>
  case "$1" in *"$2"*) ok "$3" ;; *) no "$3 — 문구 부재: $2" ;; esac
}
hasnt() { # hasnt <본문> <문구> <설명>
  case "$1" in *"$2"*) no "$3 — 있으면 안 되는 문구: $2" ;; *) ok "$3" ;; esac
}

# ── AC5 : layer1 에 축이 있고 한 줄이다 ───────────────────────────────────
for f in "$B" "$D"; do
  n="$(grep -c '^  layer1: .*overdesign' "$f" || true)"
  [ "${n:-0}" -eq 1 ] \
    && ok "AC5: $f 의 layer1 «한 줄»에 overdesign 이 있다" \
    || no "AC5: $f 의 layer1 한 줄에 overdesign 이 없다 (줄바꿈이면 codex 축이 죽고 lay_of 가 덜 잰다)"
done
grep -q '^  layer1: \[direction, overdesign\]$' "$B" \
  && ok "AC5: brief layer1 == [direction, overdesign]" \
  || no "AC5: brief layer1 이 [direction, overdesign] 이 아니다"
for a in goal_fit problem_definition scope architecture component_relations data_flow tradeoffs feasibility; do
  grep -q "^  layer1: .*\b$a\b" "$D" && ok "AC5: design layer1 에 기존 축 $a 가 남아 있다" \
                                     || no "AC5: design layer1 에서 기존 축 $a 가 사라졌다"
done

# ── AC5 파서 일치 : layer1 이 «정말» 한 줄인가 (grep -c 는 대리일 뿐이다) ─────
# grep -c '^  layer1: .*overdesign' == 1 은 "layer1 과 overdesign 이 같은 줄에 있다"만
# 잰다 — «그 줄이 층 전체다»는 못 잰다. 줄바꿈이 overdesign 뒤에서 일어나면 그 대리는
# 통과한 채로 통과한다. 위험 자체를 잰다: PyYAML(전체를 본다)과 줄 기반 읽기(러너의
# _parse_frontmatter 및 T13 의 lay_of 가 쓰는 것과 같은 방식 — 그 줄만 본다)가 같은
# 목록을 내는지 비교한다. 줄바꿈되면 PyYAML 은 축 전부를 보고 줄 기반은 접두만 봐서
# 갈라진다 — 그 갈라짐이 codex 러너를 rc 5 profile_parse_ambiguous 로 죽이고 lay_of 를
# 덜 재게 만드는 바로 그 메커니즘이다.
pyyaml_layer1() {  # pyyaml_layer1 <파일> — layer_rubric.layer1 전체(줄 수 무관)
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" <<'PY'
import sys, yaml
p = sys.argv[1]
fm = open(p, encoding="utf-8").read().split("---")[1]
lr = yaml.safe_load(fm)["layer_rubric"]
print(",".join(lr["layer1"]))
PY
}
lineparse_layer1() {  # lineparse_layer1 <파일> — lay_of/러너와 같은 방식: layer1: 줄 «하나»만
  sed -n 's/^[[:space:]]*layer1:[[:space:]]*//p' "$1" | head -1 \
    | sed -e 's/^\[//' -e 's/\]$//' | tr ',' '\n' | sed -e 's/^ *//' -e 's/ *$//' | paste -sd, -
}
for f in "$B" "$D"; do
  PY_L1="$(pyyaml_layer1 "$f")"
  LN_L1="$(lineparse_layer1 "$f")"
  [ "$PY_L1" = "$LN_L1" ] \
    && ok "AC5: $f 의 layer1 — PyYAML 과 줄 기반 읽기가 같은 목록을 낸다 ($LN_L1)" \
    || no "AC5: $f 의 layer1 — PyYAML($PY_L1) 과 줄 기반 읽기($LN_L1) 가 다르다 (layer1 이 줄바꿈됐다)"
done

# ── AC5 불릿 커버리지 : layer1 의 축 «전부»가 body 에 자기 불릿을 갖는다 (파생 ∀) ──
# 파일 머리말의 계약 — 「이름은 rubric 목록이, 내용은 본문 절이 진다」 — 을 overdesign
# 하나가 아니라 축 «전부»에 닫는다. ∀ 루프(check_axis_bullets)는 layer1 에서 파생한다
# (열거하지 않는다) — 열째 축이 추가되면 루프는 자동으로 그 축을 검사 대상에 넣는다.
# 아래 양의 짝(B_N==2 · D_N==9)은 의도적으로 하드코딩이다 — 축 개수가 바뀌면 사람이
# 이 락을 한 번 읽고 숫자를 올리게 만드는 것이 목적이다(자동 스케일이 아니라 fail-safe:
# layer1 이 줄바꿈돼 파생이 0개가 되는 사고도 이 숫자가 잡는다). 여덟 축의 불릿 «문구»
# 는 byte-pin 하지 않는다 — 그것은 이 PR 한 번의 사실이지 영구 불변식이 아니다(정본은
# git diff). 이 락이 고정하는 것은 «불릿의 존재»와 «이름 뒤 문구가 축마다 다름»뿐이다.
axes_of() {  # axes_of <파일> — layer1 이 한 줄일 때 그 원소들(한 줄이 아니면 공백)
  sed -n 's/^  layer1: \[\(.*\)\]$/\1/p' "$1" | tr ',' '\n' | sed -e 's/^ *//' -e 's/ *$//'
}
B_AXES="$(axes_of "$B")"; D_AXES="$(axes_of "$D")"
B_N="$(printf '%s\n' "$B_AXES" | grep -c '.' || true)"
D_N="$(printf '%s\n' "$D_AXES" | grep -c '.' || true)"
[ "${B_N:-0}" -eq 2 ] \
  && ok "양의 짝: brief layer1 에서 축 2개를 파생했다 (아래 ∀ 가 공허하지 않다)" \
  || no "양의 짝: brief layer1 파생이 2개가 아니다(실제 ${B_N:-0}개) — 아래 ∀ 가 공허할 수 있다"
[ "${D_N:-0}" -eq 9 ] \
  && ok "양의 짝: design layer1 에서 축 9개를 파생했다 (아래 ∀ 가 공허하지 않다)" \
  || no "양의 짝: design layer1 파생이 9개가 아니다(실제 ${D_N:-0}개) — 아래 ∀ 가 공허할 수 있다"

check_axis_bullets() {  # check_axis_bullets <본문> <라벨> <axes 개행 목록>
  # 불릿 텍스트는 흔히 "- `...`" 로 «-» 로 시작한다 — grep 의 패턴 인자로 그대로 넘기면
  # 옵션으로 오독된다. 그래서 중복 비교는 grep 을 거치지 않고 배열 원소 비교로 한다.
  #
  # 비교 대상은 «전체 줄»이 아니라 «이름 토큰(- `<axis>`) 뒤에 남는 본문»이다. 전체
  # 줄로 비교하면 서로 다른 두 축은 이름 자체가 달라 절대 같을 수 없다 — 그러면 이
  # 판정은 "복사-붙여넣기된 불릿"을 구조적으로 못 잡고 "같은 축 이름이 layer1 에
  # 중복됐다"만 우연히 잡는다(그 경우도 이름 뒤 본문이 같으므로 이 비교로 여전히 걸린다).
  local body="$1" label="$2" axes="$3" a pat line rest dup=0 prev
  local -a rests=()
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    pat='^- `'"$a"'`'
    line="$(printf '%s\n' "$body" | grep -- "$pat" | head -1)"
    if [ -n "$line" ]; then
      ok "AC5: $label 의 축 \`$a\` 가 body 에 불릿을 갖는다"
      rest="$(printf '%s' "$line" | sed 's/^- `[^`]*`//')"
      for prev in "${rests[@]:-}"; do
        [ -n "$prev" ] && [ "$prev" = "$rest" ] && dup=1
      done
      rests+=("$rest")
    else
      no "AC5: $label 의 축 \`$a\` 가 body 에 불릿이 없다"
    fi
  done <<EOF_AXES
$axes
EOF_AXES
  [ "$dup" -eq 0 ] \
    && ok "AC5: $label 의 layer1 불릿들이 이름 뒤 본문까지 서로 다르다 (복사-붙여넣기 없음)" \
    || no "AC5: $label 의 layer1 불릿 중 최소 두 축이 이름 뒤 본문을 그대로 공유한다 (복사-붙여넣기 의심)"
}
check_axis_bullets "$BB" "brief" "$B_AXES"
check_axis_bullets "$DB" "design" "$D_AXES"

# ── AC6 : 두 불릿이 서로 다르고 각자 자기 술어를 담는다 ───────────────────
BL="$(printf '%s\n' "$BB" | grep '^- `overdesign`' | head -1)"
DL="$(printf '%s\n' "$DB" | grep '^- `overdesign`' | head -1)"
[ -n "$BL" ] && [ -n "$DL" ] && [ "$BL" != "$DL" ] \
  && ok "AC6: 두 자리의 overdesign 불릿이 실재하고 서로 다르다" \
  || no "AC6: overdesign 불릿이 없거나 두 자리가 같다 (brief='$BL' design='$DL')"
has "$BL" '사용자 원문'   "AC6: brief 불릿이 자기 상류(사용자 원문)를 기준어로 담는다"
has "$DL" '브리프 §1 Goal' "AC6: design 불릿이 자기 상류(브리프 §1 Goal)를 기준어로 담는다"
hasnt "$BL" '왜곡'        "AC6: brief 불릿에 술어 ②(왜곡)가 없다 (그 대상이 구조·구현이라 brief 에 없다)"
has "$DL" '왜곡'          "AC6: design 불릿에 술어 ②(왜곡)가 있다"

# ── AC7 : 판정 한 줄의 형식 · 태그 · 대체안 · 천장 · 금지 어법 ────────────
# 태그는 표 «행»으로 서야 한다 — 바닥 occurrence(has "$BB" "\`delete:\`")는
# 본문 «어디에나» 그 문자열이 있으면 통과해서, 표가 비었거나 깨져도 다른
# 자리의 우연한 언급이 개별 태그 검사를 통과시킬 수 있다. 행 형태
# (`| \`<tag>\` |`)로 좁히고, 표 자체의 행 수에 양의 대조를 건다(design 5행 ·
# brief 4행 — bent: 행 하나만 brief 에서 빠진다). 대조가 없으면 빈 표나
# 행이 다 날아간 표도 개별 태그 검사를 우연히 통과시킬 수 있다.
#
# 행이 «있다»만으로는 부족하다 — 이름만 있고 정의(「언제」 칸)가 없으면 리뷰어가
# 그 태그의 경계를 모른다. test_docreview_profiles.sh:47-57 이 층 2 범주 불릿에
# 거는 것과 같은 원칙(`^- \`${c}\` — [^[:space:]]`, 이름 뒤 공백 아닌 것)을 표-행
# 형태로 옮긴다: 이름 칸의 구분자 뒤에 공백·파이프가 아닌 문자가 있어야 한다.
tag_row_defined() {  # tag_row_defined <본문> <태그(콜론 포함)> — 표 행이 있고 정의 칸이 비어있지 않다
  printf '%s\n' "$1" | grep -Eq -- '^\| `'"$2"'` \| [^|[:space:]]'
}
for tag in 'delete:' 'yagni:' 'shrink:' 'altitude:'; do
  tag_row_defined "$BB" "$tag" \
    && ok "AC7: brief 본문에 태그 $tag 가 표 «행»으로 있고 정의가 비어있지 않다" \
    || no "AC7: brief 본문에 태그 $tag 가 표 «행»이 없거나 정의가 비어있다"
  tag_row_defined "$DB" "$tag" \
    && ok "AC7: design 본문에 태그 $tag 가 표 «행»으로 있고 정의가 비어있지 않다" \
    || no "AC7: design 본문에 태그 $tag 가 표 «행»이 없거나 정의가 비어있다"
done
tag_row_defined "$DB" 'bent:' \
  && ok "AC7: design 본문에 태그 bent: 가 표 «행»으로 있고 정의가 비어있지 않다 (술어 ②)" \
  || no "AC7: design 본문에 태그 bent: 가 표 «행»이 없거나 정의가 비어있다 (술어 ②)"
hasnt "$BB" '`bent:`' "AC7: brief 본문에 태그 bent: 가 «없다» (술어 ② 는 design 자리의 것)"

tag_table_row_count() { # tag_table_row_count <본문> — 판정 표에서 "| `<태그>:` |" 형태의 행 수
  printf '%s\n' "$1" | grep -c '^| `[a-z]*:` |'
}
DB_ROWS="$(tag_table_row_count "$DB")"
BB_ROWS="$(tag_table_row_count "$BB")"
[ "${DB_ROWS:-0}" -eq 5 ] \
  && ok "양의 짝: design 판정 표가 행 5개다 (위 표-행 검사가 공허하지 않다)" \
  || no "양의 짝: design 판정 표 행 수가 5 가 아니다(실제 ${DB_ROWS:-0}) — 표가 비었거나 깨졌을 수 있다"
[ "${BB_ROWS:-0}" -eq 4 ] \
  && ok "양의 짝: brief 판정 표가 행 4개다 (위 표-행 검사가 공허하지 않다)" \
  || no "양의 짝: brief 판정 표 행 수가 4 가 아니다(실제 ${BB_ROWS:-0}) — 표가 비었거나 깨졌을 수 있다"

# 부분 문자열 락은 뒤집기를 약속 못 한다 — 리터럴 끝 뒤에 문자를 덧붙여도(예: 마침표)
# `has()` 의 *"$2"* 는 여전히 참이다. 부정을 추가로 얹는 건 같은 함정을 다른 모양으로
# 반복하는 것 — 대신 needle 에 프로필이 실제로 쓰는 감싸는 백틱을 넣는다. 두 프로필
# 모두 이 리터럴을 `대체안 없음 — 그냥 뺀다` 형태(백틱이 뺀다 바로 뒤에 닫힘)로 쓴다
# (grep 으로 확인 — 두 파일 다 예외 없음). 백틱까지 needle 에 넣으면 닫는 백틱이
# 뺀다 바로 뒤에 있어야만 매치해서, 끝에 아무 문자라도 끼면 더 이상 매치하지 않는다.
has "$BB" '`대체안 없음 — 그냥 뺀다`' "AC7: brief 본문에 삭제 제안의 명시 문구가 «백틱으로 닫혀» 있다"
has "$DB" '`대체안 없음 — 그냥 뺀다`' "AC7: design 본문에 삭제 제안의 명시 문구가 «백틱으로 닫혀» 있다"

# 「└ 천장」은 두 프로필 각각에 두 번 나온다 — 판정 한 줄 «펜스 예시» 안(리뷰어가
# 실제로 베끼는 템플릿, run_docreview_codex_reviewer.sh:434 가 본문 전체를 그대로
# inline 한다)과, 그 아래 프로즈 헤딩(**`└ 천장`**, 설명일 뿐 템플릿이 아니다) 둘.
# 본문 전체에 대고 has 를 걸면 펜스 쪽이 지워져도 프로즈 헤딩이 대신 통과시킨다 —
# 「grep 락의 헤더-satisfiable 함정」과 같은 모양. 펜스 «안»만 추출해 그 안에서만 잰다
# (body-unique). 추출 자체가 빈 문자열이면 아래 has 가 공허하게 통과할 수 있으니
# body_of 와 같은 양의 짝을 건다.
judgment_fence_of() {  # judgment_fence_of <본문> — "### 판정 한 줄" 다음 첫 펜스(```) «안» 내용만
  printf '%s\n' "$1" | awk '
    /^### 판정 한 줄/ { want=1; next }
    want && /^```/ { if (infence) exit; infence=1; next }
    infence { print }
  '
}
BFENCE="$(judgment_fence_of "$BB")"
DFENCE="$(judgment_fence_of "$DB")"
[ -n "$BFENCE" ] && [ -n "$DFENCE" ] \
  && ok "양의 짝: 두 프로필의 «판정 한 줄» 펜스를 추출했다 (아래 천장 검사가 공허하지 않다)" \
  || no "양의 짝: «판정 한 줄» 펜스 추출 실패 — 아래 천장 검사가 공허할 수 있다 (brief='${BFENCE:-}' design='${DFENCE:-}')"
has "$BFENCE" '└ 천장' "AC7: brief 판정 한 줄 «펜스 안»에 천장 규약이 있다 (프로즈 헤딩이 아니라 템플릿 그 자체)"
has "$DFENCE" '└ 천장' "AC7: design 판정 한 줄 «펜스 안»에 천장 규약이 있다 (프로즈 헤딩이 아니라 템플릿 그 자체)"

# 필드 사상 — 「└ 천장」은 스키마 필드가 없다(shared/docreview/scripts, plugins/spec-distill/scripts,
# plugins/spec-distill/agents 전체에서 git grep 천장 로 확인 — 프로필·이 락 밖엔 0건). summary 는
# 렌더될 때 파이프-표 행 한 칸이 된다(docreview_state.py:861) — 천장 줄의 개행이 그리로 섞이면
# 그 행이 깨진다. 「필드 사상」한 줄 문단이 네 슬롯(anchor·summary·replacement·if_unfixed)을 전부
# 배정하고, 천장이 대체안과 함께 replacement 로 가며 개행 없는 한 줄이라는 것을 명시하는지를,
# 그 문단 «안»에서만 잰다(펜스 검사와 같은 discipline — 앵커를 좁혀 body-unique 하게 만든다).
field_mapping_line_of() {  # field_mapping_line_of <본문> — "**필드 사상**" 로 시작하는 한 줄 문단만
  printf '%s\n' "$1" | grep '^\*\*필드 사상\*\*' | head -1
}
BMAP="$(field_mapping_line_of "$BB")"
DMAP="$(field_mapping_line_of "$DB")"
[ -n "$BMAP" ] && [ -n "$DMAP" ] \
  && ok "양의 짝: 두 프로필의 «필드 사상» 문단을 추출했다 (아래 검사가 공허하지 않다)" \
  || no "양의 짝: «필드 사상» 문단 추출 실패 — 아래 검사가 공허할 수 있다"
has "$BMAP" '천장: <조건>` 은 함께 `replacement` 에 싣는다' \
  "AC7: brief «필드 사상» 이 천장의 목적지를 replacement 로 명시한다"
has "$DMAP" '천장: <조건>` 은 함께 `replacement` 에 싣는다' \
  "AC7: design «필드 사상» 이 천장의 목적지를 replacement 로 명시한다"
has "$BMAP" '개행 없이' "AC7: brief «필드 사상» 이 무개행 규칙을 명시한다"
has "$DMAP" '개행 없이' "AC7: design «필드 사상» 이 무개행 규칙을 명시한다"

has "$BB" 'no-trigger' "AC7: brief 본문에 되돌릴 길 없음의 공시가 있다"
has "$DB" 'no-trigger' "AC7: design 본문에 되돌릴 길 없음의 공시가 있다"
has "$BB" '헤지형' "AC7: brief 본문에 금지 어법이 있다"
has "$DB" '헤지형' "AC7: design 본문에 금지 어법이 있다"
# AC7' — brief 자리에만 있는 어법 공존 규약
has   "$BB" '사용자가 고를 두 상태를 사실로 제시해서 세워라' \
  "AC7': brief 본문에 두 어법 계약의 공존 규약이 있다"

# ── AC8~AC11 : 사다리 · 자르지 않는 것 · 0건 출구 · 상한 ──────────────────
# 이 needle 들은 짧다(「보안」·「정당화」·「접근성」은 한두 단어) — 전체 본문 $BB/$DB
# 에 대고 has 를 걸면 「└ 천장」이 겪은 것과 같은 함정에 걸린다: 어딘가 다른 프로즈가
# 우연히 같은 두 글자를 담고 있으면, 그 자리의 가드가 통째로 지워져도 GREEN 이 남는다.
# 이 자리는 이 PR 에서 가장 위험한 지점이다 — 「자르지 않는 것」은 보안·접근성·데이터
# 손실을 오탐으로부터 지키는 가드 목록이고, 그 목록이 조용히 새면 리뷰어가 보안 검사를
# 잘라내자고 제안하기 시작한다. 그래서 각 ### 절을 그 절만의 텍스트로 먼저 추출하고
# (judgment_fence_of · field_mapping_line_of 와 같은 discipline), 그 추출에 양의 짝을
# 건 뒤 그 절 «안»에서만 잰다. section_of 는 매치한 헤딩 줄 자체도 포함해 낸다 — 0건
# 출구 헤딩(「…이 축에만 걸린다」)처럼 헤딩 문구 자체가 계약의 일부인 자리가 있어서다.
section_of() {  # section_of <본문> <헤딩(ERE, 줄 전체 앵커)> — 그 헤딩 줄(포함)부터 다음 "##"+ 헤딩 전까지
  printf '%s\n' "$1" | awk -v pat="$2" '
    $0 ~ pat && !started { started=1; print; next }
    started && /^##+ / { exit }
    started { print }
  '
}
LADDER_B="$(section_of "$BB" '^### 판정 절차 — 사다리$')"
LADDER_D="$(section_of "$DB" '^### 판정 절차 — 사다리$')"
GUARD_B="$(section_of "$BB" '^### 자르지 않는 것$')"
GUARD_D="$(section_of "$DB" '^### 자르지 않는 것$')"
EXIT_B="$(section_of "$BB" '^### 0건 출구 — 이 축에만 걸린다$')"
EXIT_D="$(section_of "$DB" '^### 0건 출구 — 이 축에만 걸린다$')"
CAP_B="$(section_of "$BB" '^### 상한$')"
CAP_D="$(section_of "$DB" '^### 상한$')"
[ -n "$LADDER_B" ] && [ -n "$LADDER_D" ] \
  && ok "양의 짝: 두 프로필의 «판정 절차 — 사다리» 절을 추출했다 (아래 AC8 검사가 공허하지 않다)" \
  || no "양의 짝: «판정 절차 — 사다리» 절 추출 실패 — 아래 AC8 검사가 공허할 수 있다 (brief='${LADDER_B:-}' design='${LADDER_D:-}')"
[ -n "$GUARD_B" ] && [ -n "$GUARD_D" ] \
  && ok "양의 짝: 두 프로필의 «자르지 않는 것» 절을 추출했다 (아래 AC9 검사가 공허하지 않다)" \
  || no "양의 짝: «자르지 않는 것» 절 추출 실패 — 아래 AC9 검사가 공허할 수 있다 (brief='${GUARD_B:-}' design='${GUARD_D:-}')"
[ -n "$EXIT_B" ] && [ -n "$EXIT_D" ] \
  && ok "양의 짝: 두 프로필의 «0건 출구» 절을 추출했다 (아래 AC10 검사가 공허하지 않다)" \
  || no "양의 짝: «0건 출구» 절 추출 실패 — 아래 AC10 검사가 공허할 수 있다 (brief='${EXIT_B:-}' design='${EXIT_D:-}')"
[ -n "$CAP_B" ] && [ -n "$CAP_D" ] \
  && ok "양의 짝: 두 프로필의 «상한» 절을 추출했다 (아래 AC11 검사가 공허하지 않다)" \
  || no "양의 짝: «상한» 절 추출 실패 — 아래 AC11 검사가 공허할 수 있다 (brief='${CAP_B:-}' design='${CAP_D:-}')"

for v in b d; do
  if [ "$v" = "b" ]; then LT="$LADDER_B"; GT="$GUARD_B"; ET="$EXIT_B"; CT="$CAP_B"; N="brief"
  else LT="$LADDER_D"; GT="$GUARD_D"; ET="$EXIT_D"; CT="$CAP_D"; N="design"; fi
  has "$LT" '성립하는 첫 단에서 멈춘다' "AC8: $N 「사다리」절에 「첫 단에서 멈춘다」가 있다"
  has "$LT" '번호가 작은 쪽'           "AC8: $N 「사다리」절에 「두 단이 성립하면 번호가 작은 쪽」이 있다"
  has "$LT" '한 방향 압력'             "AC8: $N 「사다리」절에 그 선택의 대가가 적혀 있다"
  for rung in '이 구조가 있어야 하나' '이미 리포에 있는' '이미 있는 하니스 표면' '한 줄 규약으로 되나' '그제서야 새 메커니즘'; do
    has "$LT" "$rung" "AC8: $N 「사다리」절에 「${rung}」 단이 있다"
  done
  # ── AC9 : 자르지 않는 것 ────────────────────────────────────────────────
  for g in 'trust boundary' '데이터 손실' '보안' '접근성' '명시로 요청한' \
           '새 근거 없이 재논쟁' '읽기를 줄이지 않는다' '과함만' 'kill switch'; do
    has "$GT" "$g" "AC9: $N 「자르지 않는 것」절에 「${g}」가 있다"
  done
  has "$GT" 'Law 1·2·3' "AC9: $N 「자르지 않는 것」절에 devbrew 자리의 가드가 있다"
  # ── AC10 : 0건 출구 ─────────────────────────────────────────────────────
  has   "$ET" '이 문서는 이미 최소다' "AC10: $N 「0건 출구」절에 0건 출구 문구가 있다"
  has   "$ET" '정당화'                "AC10: $N 「0건 출구」절에 「정당화를 붙이지 않는다」가 있다"
  # AC10 의 실제 보장은 이 has 다 — doc-critic 이 두 sentinel 블록을 항상 낸다는 «긍정»
  # 서술이 critic_dead(docreview_route.py:156-168, 층 1 블록 부재 → 라운드 「미검증」)를
  # 막는다. 아래 hasnt 'and stop' 은 그 보장의 증거가 «아니다» — 영어 원문 리터럴이
  # 그대로 붙여넣어지지 않았다는 값싼 보험일 뿐, 한국어 프로필이 그 정지 의미론을
  # 실제로 들여오지 않았다는 것을 grep 으로 재지는 못한다(의미론은 문장으로만 잰다).
  has   "$ET" '두 sentinel 블록'      "AC10: $N 「0건 출구」절에 「두 블록은 그래도 낸다」가 있다"
  has   "$ET" '이 축에만'             "AC10: $N 「0건 출구」절 헤딩이 「overdesign 축에만 걸린다」를 명시한다"
  hasnt "$ET" 'and stop'              "AC10: $N 「0건 출구」절에 영어 리터럴 'and stop' 이 «없다» (의미 보장이 아니라 원문 그대로 붙여넣기 방지의 값싼 보험 — 실제 보장은 위 「두 sentinel 블록」 긍정 검사)"
  # ── AC11 : 상한 ─────────────────────────────────────────────────────────
  has   "$CT" '한 판정자가 한 라운드에' "AC11: $N 「상한」절이 «판정자별»임을 밝힌다"
  has   "$CT" '2N+α'                   "AC11: $N 「상한」절이 라운드 총량 2N+α 를 밝힌다"
  has   "$CT" '무엇을 잘랐는지'        "AC11: $N 「상한」절에 초과분 공시 규약이 있다"
  has   "$CT" '강제하는 기계는 없다'    "AC11: $N 「상한」절이 이 상한이 강제되지 않음을 밝힌다"
  hasnt "$CT" '한 호출을 통째로 먹지 않는다' "AC11: $N 「상한」절에 2N+α 로 반증되는 문구가 «없다»"
done

finish
