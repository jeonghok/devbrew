#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md plugins/*/skills/*/references/*.md plugins/*/references/*.md
#
# 모든 `plugins/*/skills/*/SKILL.md` 가 `references/<file>.md` 형태로 가리키는
# 경로가 실제로 존재하는가(정방향) — 그리고 그 역방향: 모든 git-tracked
# `references/*.md` 가 어떤 SKILL.md 로부터든 가리켜지는가(고아 없음).
#
# 왜 필요한가 (Task 31, 무게 감축): quality-pipeline SKILL.md 의 `## Runtime gate`
# 절차를 조건부 로드를 위해 `references/runtime-gate.md` 로 쪼갰다. 이 분리가
# 만드는 새 fail-open을 지금까지 아무 테스트도 안 지킨다 — 나중에 그 참조 파일이
# 삭제되거나 이름이 바뀌면 SKILL.md 는 존재하지 않는 파일을 가리키게 되고,
# Runtime 게이트를 실제로 돌 때 모델이 Read 할 대상이 없어 절차 전문이 조용히
# 사라진다. 정적 문자열이 어딘가에 있다는 것과 그 문자열이 **가리키는 파일이
# 실재한다**는 것은 다른 사실이다 — 이 락은 후자만 잰다.
#
# 왜 역방향도 필요한가 (Task 31 fix round 1, F6): 정방향만 재면 **고아**
# (아무 SKILL.md 도 안 가리키는 references/*.md)는 안 잡힌다 — 이 branch 의
# 근본 요청("중복된 공통 부분이 stale 되지 않게 통합 관리")이 정확히 막으려는
# 회귀는, 나중에 누군가 references/*.md 절차를 SKILL.md 본문으로 되접으면서
# 참조 파일 삭제를 잊는 것이다. 그러면 죽은 산문 복제본이 모든 설치본에
# 영구히 실리고, 20줄 중복 락(별건 태스크)의 코퍼스는 `plugins/**` 라서 두
# 사본 다 "정당하게 있다"로 보여 그 락도 못 잡는다.
#
# ── 플러그인 레벨 `references/` (Task 33) ────────────────────────────────────
# 두 skill 이 공유하는 참조 파일은 어느 skill 밑에도 두지 않는다 — 그 자리가
# `plugins/<p>/references/<f>.md` 다. 앞 판본은 이 모양을 **양방향 모두** 다루지
# 못했다:
#   - 정방향: 매치된 문자열에서 `references/...` **접미사만** 취해 그 포인터를
#     담은 SKILL.md 의 디렉터리 기준으로 해석했다. 그래서 플러그인 레벨 파일을
#     가리키는 포인터는 `skills/<s>/references/<f>.md` 를 찾다가 **false-RED**.
#   - 역방향: 코퍼스가 `plugins/*/skills/*/references/*.md` 뿐이라 플러그인 레벨
#     파일은 고아 검사에 **아예 보이지 않았다**.
#
# 수리 방향은 "접미사를 재해석"이 아니라 **쓰여 있는 그대로 해석**이다. 매치에
# **앵커 접두사**를 함께 캡처해, 접두사마다 해석 루트가 **정확히 하나**가 되게 한다:
#
#   ① `${CLAUDE_PLUGIN_ROOT…}/…`  → 그 SKILL.md 로부터 도출한 플러그인 루트
#   ② `plugins/<p>/…`              → 리포 루트 (쓰인 그대로)
#      〔2026-08-21 실측〕 이 갈래는 오늘 **살아 있는 인스턴스가 0** 이다 — 분기로만 존재하며
#      합성 케이스로 검증했다. 코퍼스가 아니라 리졸버의 갈래이므로 vacuity FAIL 대상이 아니다.
#   ③ `(../)*references/…`(맨몸 포함) → 그 SKILL.md 자신의 디렉터리 (쓰인 그대로)
#   ④ 그 밖의 모든 접두사           → **거부(loud FAIL)**. 재해석하지 않는다.
#
# **"skill 밑을 먼저 보고 없으면 플러그인 루트를 본다" 식의 폴백은 쓰지 않는다.**
# 그러면 같은 이름의 파일이 플러그인 레벨에 우연히 있을 때 *진짜로 없는* skill
# 레벨 대상이 통과한다 — fail-open 이다. 접두사 → 루트가 1:1 이면 그 창이 없다.
# ④ 가 없으면 그 1:1 주장이 반쪽이 된다(F6) — 열거 밖 접두사가 거부 대신 **절단**돼
# 조용히 ③ 으로 떨어지기 때문이다.
#
# **역방향도 같은 해석기를 쓴다(F5).** 앞 판본의 역방향은 포인터를 `references/…`
# 접미사로 잘라 비교했다. 그래서 `${CLAUDE_PLUGIN_ROOT}/references/notes.md` 를 가리키는
# 포인터가 `skills/<s>/references/notes.md` 의 소유 증거로도 인정됐다 — 정방향은 엄격한데
# 역방향만 느슨한 상태였고, 둘 다 실재하면 skill 레벨 파일이 **아무도 안 가리키는데도**
# 고아로 안 잡혔다. 지금은 정방향이 만든 `(SKILL.md, 해석된 대상)` **쌍**을 그대로 되쓴다.
#
# 대상은 열거가 아니라 git 이 추적하는 SKILL.md 전부에서 **도출**한다 — 새
# 스킬이나 새 참조 파일이 생겨도 자동으로 대상이 된다. 포인터는 마크다운 링크
# (`[text](references/x.md#anchor)`) · 백틱 코드 스팬(`` `references/x.md` ``) ·
# 코드블록 안의 전체 경로(`plugins/<p>/.../references/x.md`) ·
# `${CLAUDE_PLUGIN_ROOT}/.../references/x.md` 설치-경로 표기까지 전부 같은 정규식
# 하나로 잡는다 — 문자 클래스가 `` ` ``·`)`·`#`·공백을 포함하지 않으므로 그
# 문자들에서 자연히 끊긴다.
#
# `0 checked / 0 missing` 은 "소실 없음"이 아니라 "추출이 아무것도 못 봤다"다 —
# 코퍼스가 비어있지 않은데 포인터를 하나도 못 찾으면 이 락 자체가 무의미해지므로
# 큰 소리로 FAIL 한다(정규식이 조용히 깨지는 것과 "정말 포인터가 없다"를 구별
# 못 하면, 이 락은 늘 GREEN인 이빨 없는 락이 된다).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# 토큰을 **통째로** 잡는다 — 접두사를 열거해 골라 받지 않는다.
#
# 〔fix round 1 / F6〕 앞 판본은 알아보는 접두사만 선택적 그룹으로 열거했다. 그러면
# 알아보지 못하는 접두사는 **거부되는 게 아니라 잘린다**: 정규식이 `$`/`docs`/`shared`
# 위치에서 실패하고 문자열 **중간**의 맨몸 `references/…` 로 매치가 시작돼, 그 표기가
# 조용히 form ③(스킬 디렉터리 상대)으로 재해석된다. `$CLAUDE_PLUGIN_ROOT/references/x.md`
# (중괄호 없음) · `some/deep/path/references/y.md` 가 전부 그 경로였다. 이 락과 그 설계
# 노트가 "폴백 없음"이라고 주장하는 바로 그 자리에 **절단형 폴백**이 있었던 셈이다.
#
# 그래서 앞쪽 경로 문자를 전부 삼키는 넓은 클래스로 토큰을 통째 잡고, 그 다음
# **알아보는 형태인지**를 판정한다. 못 알아보면 조용히 재해석하지 않고 loud FAIL 한다.
# 클래스에서 빼는 문자: 공백 · 백틱 · 괄호 · 부등호 · 따옴표 · `*` · `;` · `,`.
# 앞의 넷은 마크다운/코드 문맥의 자연 경계이고, `*` 는 `**path**` 볼드 표기가 인식
# 불가 토큰으로 오인되는 것을 막는다(실측: 그 표기도 맨몸 형태로 정상 추출된다).
_Q="'"
REF_RE="[^[:space:]\`()<>\"${_Q}*;,]*references/[A-Za-z0-9_./-]+\\.md"

# `a/b/../c` → `a/c`. 존재하지 않는 경로도 접어야 하므로 `realpath`/`pwd -P` 를
# 쓰지 않는다. 선두의 `..` 는 접지 않고 남긴다(리포 밖을 가리키는 포인터는 그대로
# 존재 검사에서 떨어져야 한다 — 조용히 리포 안으로 끌어오지 않는다).
norm_path() {
  printf '%s\n' "$1" | awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) {
      s = $i
      if (s == "" || s == ".") continue
      if (s == "..") { if (n > 0 && st[n] != "..") { n--; continue } }
      st[++n] = s
    }
    out = ""
    for (i = 1; i <= n; i++) out = (i == 1 ? st[i] : out "/" st[i])
    print out
  }'
}

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 이 락이
# 실제로 훑는 두 코퍼스(git 추적 SKILL.md 전부 + git 추적 references/*.md 전부 —
# skill 레벨과 플러그인 레벨 **둘 다**)를 낸다. 선언(guards: 세 글롭)과 실측이
# 여기서 같이 맞아야 한다.
#
# git pathspec 의 `*` 는 `/` 를 넘으므로 `plugins/*/references/*.md` 하나로도 두
# 모양이 다 잡힌다(실측). 그럼에도 두 pathspec 을 나란히 적는 것은 **의도를
# 문서화**하기 위해서다 — 그 subtlety 에 조용히 기대지 않는다. `git ls-files` 는
# 겹치는 pathspec 의 결과를 중복 없이 낸다(실측).
CORPUS="$(git ls-files -- 'plugins/*/skills/*/SKILL.md')"
REF_CORPUS="$(git ls-files -- 'plugins/*/skills/*/references/*.md' 'plugins/*/references/*.md')"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  printf '%s\n' "$REF_CORPUS"
  exit 0
fi

corpus_n=0
while IFS= read -r f; do
  [ -n "$f" ] && corpus_n=$((corpus_n + 1))
done < <(printf '%s\n' "$CORPUS")
if [ "$corpus_n" -lt 1 ]; then
  no "pointer: git ls-files 가 SKILL.md 를 0개 도출했다 — 이 검사 자체가 vacuous 하다"
  finish
  exit $?
fi
ok "pointer: SKILL.md 코퍼스 ${corpus_n}개 도출 (vacuous 아님)"

checked=0
missing=0
unknown_form=0
# 정방향이 실제로 **해석해 낸 대상**의 집합. 역방향(플러그인 레벨 고아 검사)이
# 이 집합을 그대로 되쓴다 — 두 방향이 같은 해석기를 공유하므로, 접두사 파싱이
# 깨지면 정방향과 역방향이 **동시에** RED 를 낸다(mutation M7b 실측: 접두사 분기를
# 옛 접미사-only 판본으로 되돌리자 소실 2 + 고아 1).
#
# `norm_path` 는 그보다 좁다 — `../` 표기가 실제로 쓰일 때만 발화한다. 현재
# 코퍼스에는 그 표기가 없어 이 함수를 항등함수로 바꿔도 GREEN 이다(M7a 실측).
# 이빨은 `../` 포인터가 등장하는 순간 생긴다(M6 로 그 경로를 실측했다).
RESOLVED=""
# `(그 포인터를 담은 SKILL.md)::(해석된 대상)` 쌍. 역방향의 **소유** 판정이 이것을
# 그대로 되쓴다 — 접미사 비교가 아니라 쓰인 그대로의 해석 결과를 본다(F5).
RESOLVED_PAIRS=""

while IFS= read -r skill_md; do
  [ -n "$skill_md" ] || continue
  skill_dir="$(dirname -- "$skill_md")"
  plugin_root="${skill_md%/skills/*}"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    checked=$((checked + 1))
    # 접두사 → 해석 루트는 1:1. 폴백 없음. 알아보지 못하면 **거부**한다(절단 금지).
    target=""
    case "$ref" in
      '${CLAUDE_PLUGIN_ROOT'*'}/'*) target="$plugin_root/${ref#*\}/}" ;;
      plugins/*)                    target="$ref" ;;
      references/*)                 target="$skill_dir/$ref" ;;
      *)
        # `(../)+references/…` 만 상대 형태로 인정한다. `case` 로는 `+` 를 못 쓰므로
        # 선두 `../` 를 벗겨 나머지가 `references/` 로 시작하는지 본다.
        _rest="$ref"
        while [ "${_rest#../}" != "$_rest" ]; do _rest="${_rest#../}"; done
        case "$_rest" in
          references/*) target="$skill_dir/$ref" ;;
        esac
        ;;
    esac
    if [ -z "$target" ]; then
      # 예: 중괄호 없는 `$CLAUDE_PLUGIN_ROOT/references/x.md` · `docs/…/references/y.md`.
      # 조용히 스킬 디렉터리 상대로 재해석하지 않는다 — 그것이 이 락이 없다고 주장하는
      # 폴백이다. 표기를 인식 가능한 세 형태 중 하나로 고쳐야 한다.
      no "pointer: $skill_md → '$ref' 의 접두사를 알아볼 수 없다 — 인식 형태는 \`\${CLAUDE_PLUGIN_ROOT…}/…\` · \`plugins/<p>/…\` · \`(../)*references/…\` 뿐이다 (조용히 재해석하지 않는다)"
      unknown_form=$((unknown_form + 1))
    elif [ -f "$target" ]; then
      ok "pointer: $skill_md → $ref (존재: $target)"
      RESOLVED="$RESOLVED$(norm_path "$target")
"
      RESOLVED_PAIRS="$RESOLVED_PAIRS$skill_md::$(norm_path "$target")
"
    else
      no "pointer: $skill_md → $ref 를 가리키지만 그 경로에 파일이 없다 ($target)"
      missing=$((missing + 1))
    fi
  done < <(grep -oE -- "$REF_RE" "$skill_md" | sort -u)
done < <(printf '%s\n' "$CORPUS")

if [ "$checked" -eq 0 ]; then
  no "pointer: 코퍼스 ${corpus_n}개 SKILL.md 전체에서 references/*.md 포인터를 0개 발견 — 추출이 실패했다 (0 checked/0 missing 은 '없음'이 아니라 '안 봤다')"
else
  assert_eq "$missing" "0" "pointer: 대조 ${checked}건 / 소실 ${missing}건"
  assert_eq "$unknown_form" "0" "pointer: 인식 못 하는 접두사 ${unknown_form}건 (절단-재해석 대신 거부)"
fi

# ── 역방향(F6): SKILL.md 가 안 가리키는 references/*.md — 고아 ────────────
#
# 모양마다 규칙이 다르다 — 같은 규칙을 억지로 하나로 만들면 둘 중 하나가 느슨해진다.
#
#  - **skill 레벨** (`plugins/<p>/skills/<s>/references/<f>.md`): 기존 규칙 그대로,
#    **자기 소유 SKILL.md**(같은 `skills/<skill>/` 디렉터리)가 그것을 가리켜야 한다.
#    "다른 스킬이 가리키니 됐다"로 느슨해지지 않게 소유 관계를 유지한다.
#  - **플러그인 레벨** (`plugins/<p>/references/<f>.md`): 소유 스킬이 정의상 없다.
#    그래서 정방향이 **실제로 해석해 낸 대상 집합**에 드는지로 판정한다 — 정방향의
#    정확한 쌍대(dual)이며, 어느 SKILL.md 가 가리키든 한 곳이면 충분하다.
#
# 코퍼스 자체가 0 이면(추출 실패든 정말 없든) 아래 대조가 공허해지므로,
# 정방향과 같은 규율로 무조건 loud FAIL 한다 — "역방향 검사 자체가 vacuous
# 하다"를 "고아 없음"으로 읽지 않는다.
#
# 다만 **플러그인 레벨 개수 0 은 FAIL 하지 않는다.** 그 모양의 파일이 하나도 없는
# 것은 정당한 상태이며(2026-08-21 이전 리포가 그랬다) 그때는 고아가 될 수 있는
# 대상 자체가 없다 — 여기서 FAIL 하면 락이 정직한 상태에 RED 를 낸다. 대신 개수를
# **출력에 남겨** 0 으로 떨어진 것이 조용히 지나가지 않게 한다.
ref_corpus_n=0
plugin_level_n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  ref_corpus_n=$((ref_corpus_n + 1))
  case "$f" in */skills/*/references/*) ;; *) plugin_level_n=$((plugin_level_n + 1)) ;; esac
done < <(printf '%s\n' "$REF_CORPUS")
if [ "$ref_corpus_n" -lt 1 ]; then
  no "orphan: git ls-files 가 references/*.md 를 0개 도출했다 — 역방향 검사 자체가 vacuous 하다"
  finish
  exit $?
fi
ok "orphan: references/*.md 코퍼스 ${ref_corpus_n}개 도출 (그중 플러그인 레벨 ${plugin_level_n}개, vacuous 아님)"

ref_checked=0
orphans=0
while IFS= read -r reffile; do
  [ -n "$reffile" ] || continue
  ref_checked=$((ref_checked + 1))
  case "$reffile" in
    */skills/*/references/*)
      skill_dir="${reffile%/references/*}"
      owner_skill="$skill_dir/SKILL.md"
      # F5: 접미사 비교가 아니라 **정방향이 실제로 해석해 낸 쌍**을 본다. 접미사로
      # 비교하면 `${CLAUDE_PLUGIN_ROOT}/references/notes.md` 포인터가 skill 레벨
      # `references/notes.md` 의 소유 증거로도 인정돼, 둘 다 실재할 때 skill 레벨
      # 파일이 아무도 안 가리키는데 고아로 안 잡힌다(정방향은 엄격, 역방향만 느슨).
      want_pair="$owner_skill::$(norm_path "$reffile")"
      if printf '%s\n' "$RESOLVED_PAIRS" | grep -qxF -- "$want_pair"; then
        ok "orphan: $reffile ← $owner_skill 이 이 경로로 해석되는 포인터를 갖는다"
      else
        no "orphan: $reffile 를 **이 경로로** 가리키는 $owner_skill 의 포인터가 없다 (접미사만 같은 다른 경로 표기는 소유 증거가 아니다)"
        orphans=$((orphans + 1))
      fi
      ;;
    *)
      if printf '%s\n' "$RESOLVED" | grep -qxF -- "$(norm_path "$reffile")"; then
        ok "orphan: $reffile ← 어떤 SKILL.md 포인터가 실제로 이 경로로 해석됨 (플러그인 레벨)"
      else
        no "orphan: $reffile (플러그인 레벨) 로 해석되는 SKILL.md 포인터가 없다"
        orphans=$((orphans + 1))
      fi
      ;;
  esac
done < <(printf '%s\n' "$REF_CORPUS")

if [ "$ref_checked" -eq 0 ]; then
  no "orphan: 코퍼스 ${ref_corpus_n}개 references/*.md 전체에서 0개를 확인했다 — 루프가 실패했다"
else
  assert_eq "$orphans" "0" "orphan: references 파일 ${ref_checked}건 중 미참조(고아) ${orphans}건"
fi

finish
