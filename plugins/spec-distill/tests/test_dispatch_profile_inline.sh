#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md plugins/spec-distill/scripts/brief_review_state.py plugins/spec-distill/scripts/state_path.py
#
# 두 엔진 자리(`reviewing-brief` · `reviewing-spec`)의 탐지 · 재비판 dispatch 가 `<profile>` 슬롯에 프로필
# **경로가 아니라 내용**을 싣는가. 설치본에서 프로필은 플러그인 캐시(사용자 cwd 밖)에 있어 리뷰어의 Read 가
# 권한 거부되고, 리뷰어는 기준 없이 판정한다 — 엔진은 그 사실을 모른다(PR 3 최종 리뷰 F1, T9 p11 관측).
#
#   A  `## dispatch 블록 둘` 절 산문(펜스 밖)에 body-unique 문구 「경로가 아니라 **프로필 파일의 내용**을 싣는다」
#   B  양의 짝 — 같은 절에 `<profile>${PROFILE}</profile>` 슬롯이 brief 3 · spec 2 개 실재
#   C  `profile-content` 마커 사이 펜스가 그 절 안에 있고, `cat "$PROFILE"` 를 부르며, 실패 분기가
#      「dispatch 하지 않는다」를 말하고 rc 1 로 끝난다
#   X  그 펜스를 차가운 셸에서 실행한다 — 실제 플러그인 루트면 stdout 이 프로필 파일 내용 그대로(rc 0),
#      프로필이 없는 루트면 rc 1 · loud advisory · stdout 비움. 앞 블록의 `set -euo pipefail` 을 물려받아도 같다.
#      실패 분기는 미리 채워 둔 `$STATE_DIR/critic.txt`(직전 라운드 critic 출력)를 비우고, 성공 경로는 건드리지
#      않는다(PR 3 qg iter 1). brief 는 실패를 degrade 원장(없으면 두 번째 채널)에 남긴다.
# 실제 agent · codex 는 부르지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/references/docreview-profiles/brief.md"
  echo "plugins/spec-distill/references/docreview-profiles/design-doc.md"
  echo "plugins/spec-distill/scripts/brief_review_state.py"
  echo "plugins/spec-distill/scripts/state_path.py"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-profile-inline-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 가 유효한 디렉토리가 아니다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

PHRASE='경로가 아니라 **프로필 파일의 내용**을 싣는다'
SLOT='<profile>${PROFILE}</profile>'

section() {   # section <SKILL> <제목 정규식> → 그 `## ` 절 본문(다음 `## ` 직전까지, 펜스 인식)
  SEC="$2" awk '
    !on && $0 ~ ("^## " ENVIRON["SEC"]) {on=1; next}
    on && /^```/ {fence=!fence}
    on && !fence && /^## / {exit}
    on
  ' "$1"
}
prose_of() { awk '/^```/ {f=!f; next} !f' <<<"$1"; }
cut_marked() {   # cut_marked <SKILL> → profile-content 마커 사이의 bash 블록
  awk '/<!-- profile-content:begin -->/ {g=1; next}
       /<!-- profile-content:end -->/ {g=0}
       g && /^```bash$/ {b=1; next}
       g && b && /^```$/ {b=0; next}
       g && b' "$1"
}
fail_branch() {   # fail_branch <펜스 파일> → `if [ "$prof_rc" -ne 0 ]` 부터 짝 `fi` 까지
  awk '!inb && /^if \[ "\$prof_rc" -ne 0 \]/ {inb=1} inb {print} inb && /^fi$/ {exit}' "$1"
}

# 차가운 셸의 python3 가 PyYAML 을 찾게 한다(셀마다 HOME 을 scratch 로 가둔다 — critic-select 락과 같은 전제).
BASE="/usr/bin:/bin"
YAML_SITE="$(env -i PATH="$BASE" HOME="$HOME" python3 -c 'import os, yaml; print(os.path.dirname(os.path.dirname(os.path.abspath(yaml.__file__))))' 2>/dev/null)"
[ -n "$YAML_SITE" ] && ok "전제: 차가운 셸의 python3 가 PyYAML 을 찾는다" \
  || no "전제: 차가운 셸의 python3 가 PyYAML 을 못 찾는다 — brief 실패 셀의 degrade 기록 판정이 흔들린다"

# 프로필이 없는 가짜 플러그인 루트 — scripts 는 실물, references 는 빈 디렉토리.
PR_NOPROF="$SCRATCH/pr-noprof"; mkdir -p "$PR_NOPROF/references"
ln -s "$SD/scripts" "$PR_NOPROF/scripts"
DOCS="$SCRATCH/docs"; mkdir -p "$DOCS"
cp "$ROOT/shared/tests/fixtures/docreview/brief-sample.md" "$DOCS/brief-sample.md"
cp "$ROOT/shared/tests/fixtures/docreview/design-sample.md" "$DOCS/design-sample.md"
printf -- '---\nx: 1\n---\n\n## 6. 사용자 원문\n\n- id: S2\n  source: verbatim\n  round: 1\n  text: "둘째 발화"\n' > "$DOCS/brief-sample.audit.md"

run_fence() {   # run_fence <셀> <펜스 파일> <플러그인 루트> [nodoc] — stdout·stderr·rc 를 scratch 에 남긴다
  # nodoc: 문서 슬롯(PAYLOAD · AUDIT · spec_path)을 넘기지 않는다 — 같은 Bash 호출에서 대입하지 않은 호출이다.
  local cell="$1" fence="$2" pr="$3" home="$SCRATCH/$1"
  local docvars=(PAYLOAD="$DOCS/brief-sample.md" AUDIT="$DOCS/brief-sample.audit.md" spec_path="$DOCS/design-sample.md")
  [ "${4:-}" = nodoc ] && docvars=()
  mkdir -p "$home/.claude/spec-distill/$cell"
  printf -- '---\nsession_id: %s\n---\n\nbody\n' "$cell" > "$home/.claude/spec-distill/$cell/state.local.md"
  ( cd "$home" && env -i PATH="$BASE" HOME="$home" PYTHONPATH="$YAML_SITE" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$pr" DEVBREW_SPEC_DISTILL_SESSION_ID="$cell" \
      ${docvars[@]+"${docvars[@]}"} bash "$fence" ) \
      >"$SCRATCH/$cell.out" 2>"$SCRATCH/$cell.err"
  echo $? > "$SCRATCH/$cell.rc"
}
# seed_critic <셀> <문서> — 그 셀의 문서별 상태 디렉토리(펜스와 같은 도출)에 직전 라운드의 critic 출력을 미리 둔다.
# 경로를 낸다. 도출이나 쓰기가 실패하면 빈 값 — 호출부가 전제로 잰다.
CRITIC_SEED='직전 라운드의 critic 출력'
seed_critic() {
  local cell="$1" doc="$2" home="$SCRATCH/$1" root sdir
  mkdir -p "$home/.claude/spec-distill/$cell" || return 0
  root="$(cd "$home" && env -i PATH="$BASE" HOME="$home" PYTHONPATH="$YAML_SITE" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$SD" DEVBREW_SPEC_DISTILL_SESSION_ID="$cell" python3 "$SD/scripts/state_path.py" state-root 2>/dev/null)"
  [ -n "$root" ] || return 0
  sdir="$(env -i PATH="$BASE" PYTHONPATH="$YAML_SITE" PYTHONDONTWRITEBYTECODE=1 \
      python3 "$SD/scripts/docreview_state.py" state-dir-for --root "$root" --session "$cell" --doc "$doc" 2>/dev/null)"
  [ -n "$sdir" ] && mkdir -p "$sdir" && printf '%s\n' "$CRITIC_SEED" > "$sdir/critic.txt" && echo "$sdir/critic.txt"
  return 0
}

for spec in "reviewing-brief:brief.md:3" "reviewing-spec:design-doc.md:2"; do
  sk="${spec%%:*}"; rest="${spec#*:}"; prof="${rest%%:*}"; want_slots="${rest#*:}"
  SKILL="$SD/skills/$sk/SKILL.md"
  PROF="$SD/references/docreview-profiles/$prof"
  SEC="$(section "$SKILL" 'dispatch 블록')"
  lines_sec="$(printf '%s\n' "$SEC" | grep -c . || true)"
  if [ "${lines_sec:-0}" -ge 10 ] && grep -q 'subagent_type:' <<<"$SEC"; then
    ok "$sk: \`## dispatch 블록 둘\` 절을 잘랐다 (${lines_sec}줄, dispatch 블록 포함 — 아래 절 단언이 공허하지 않다)"
  else
    no "$sk: \`## dispatch 블록 둘\` 절을 못 잘랐다 (${lines_sec:-0}줄) — 아래 절 단언이 공허하다"
  fi

  # A — 산문에만 산다(펜스의 echo 가 문구를 대신 만족시키지 못한다).
  assert_contains "$(prose_of "$SEC")" "$PHRASE" \
    "$sk A: dispatch 절 산문이 \`\${PROFILE}\` 에 경로가 아니라 프로필 파일의 내용을 싣는다고 말한다 (body-unique)"

  # B — 양의 짝: 문구가 가리키는 슬롯이 그 절에 실재한다.
  n_slot="$(printf '%s\n' "$SEC" | grep -oF "$SLOT" | wc -l | tr -d ' ')"
  assert_eq "$n_slot" "$want_slots" "$sk B: dispatch 절의 \`$SLOT\` 슬롯이 ${want_slots}개 (탐지 · 재비판)"

  # C — 내용을 얻는 펜스.
  FENCE="$SCRATCH/$sk.fence.sh"; cut_marked "$SKILL" > "$FENCE"
  n_fence="$(grep -c . "$FENCE" || true)"
  if [ "${n_fence:-0}" -ge 4 ] && bash -n "$FENCE" 2>/dev/null; then
    ok "$sk C: profile-content 펜스 ${n_fence}줄 · bash -n 통과"
  else
    no "$sk C: profile-content 펜스가 ${n_fence:-0}줄이거나 문법이 깨졌다 — 마커가 없거나 추출이 깨졌다"
  fi
  grep -qF '<!-- profile-content:begin -->' <<<"$SEC" \
    && ok "$sk C: 그 펜스가 \`## dispatch 블록 둘\` 절 안에 있다" \
    || no "$sk C: profile-content 펜스가 dispatch 절 밖이거나 없다"
  grep -v '^[[:space:]]*#' "$FENCE" | grep -qF 'cat "$PROFILE"' \
    && ok "$sk C: 펜스가 실행 줄에서 \`cat \"\$PROFILE\"\` 로 내용을 얻는다 (Read 가 아니다)" \
    || no "$sk C: 펜스에 \`cat \"\$PROFILE\"\` 실행 줄이 없다"
  FB="$(fail_branch "$FENCE")"
  { grep -qF 'dispatch 하지 않는다' <<<"$FB" && grep -qE '^[[:space:]]*exit 1$' <<<"$FB"; } \
    && ok "$sk C: 실패 분기가 dispatch 하지 않는다고 말하고 rc 1 로 끝난다" \
    || no "$sk C: 실패 분기(\`if [ \"\$prof_rc\" -ne 0 ]\`)가 없거나 dispatch 금지 · rc 1 이 빠졌다"

  # X — 실행. 셀마다 그 셀의 문서별 상태 디렉토리에 직전 라운드의 critic 출력을 미리 둔다 — 실패 분기는 그것을
  # 비워야 하고(5단계가 critic 사망으로 읽는다), 성공 경로는 건드리지 않아야 한다.
  case "$sk" in reviewing-brief) SDOC="$DOCS/brief-sample.md" ;; *) SDOC="$DOCS/design-sample.md" ;; esac
  if [ "${n_fence:-0}" -ge 4 ]; then
    FENCE_E="$SCRATCH/$sk.fence-errexit.sh"; { echo 'set -euo pipefail'; cat "$FENCE"; } > "$FENCE_E"
    for mode in plain errexit; do
      f="$FENCE"; [ "$mode" = errexit ] && f="$FENCE_E"
      seed_ok="$(seed_critic "ok-$sk-$mode" "$SDOC")"
      run_fence "ok-$sk-$mode" "$f" "$SD"
      assert_eq "$(cat "$SCRATCH/ok-$sk-$mode.rc")" "0" "$sk X($mode): 실제 루트면 rc 0"
      assert_eq "$(cat "$SCRATCH/ok-$sk-$mode.out")" "$(cat "$PROF")" "$sk X($mode): stdout 이 프로필 파일 내용 그대로다 ($prof)"
      assert_eq "$(cat "$seed_ok" 2>/dev/null)" "$CRITIC_SEED" "$sk X($mode) 양의 짝: 성공 경로는 미리 채운 \$STATE_DIR/critic.txt 를 건드리지 않는다"
      seed_no="$(seed_critic "no-$sk-$mode" "$SDOC")"
      { [ -n "$seed_no" ] && [ -s "$seed_no" ]; } \
        && ok "$sk X($mode) 전제: 실패 셀의 \$STATE_DIR/critic.txt 를 직전 라운드 출력으로 채워 뒀다 (아래 비움 단언이 공허하지 않다)" \
        || no "$sk X($mode) 전제: 실패 셀의 \$STATE_DIR/critic.txt 를 채우지 못했다 — 도출이 깨졌다 ('$seed_no')"
      run_fence "no-$sk-$mode" "$f" "$PR_NOPROF"
      assert_eq "$(cat "$SCRATCH/no-$sk-$mode.rc")" "1" "$sk X($mode): 프로필이 없는 루트면 rc 1"
      assert_eq "$(grep -c . "$SCRATCH/no-$sk-$mode.out" || true)" "0" "$sk X($mode): 그때 stdout 은 비었다 (빈 슬롯으로 dispatch 할 거리가 없다)"
      assert_contains "$(cat "$SCRATCH/no-$sk-$mode.err")" "dispatch 하지 않는다" "$sk X($mode): 그때 loud advisory 가 dispatch 금지를 말한다"
      assert_eq "$(wc -c < "$seed_no" 2>/dev/null | tr -d ' ')" "0" "$sk X($mode): 그때 실패 분기가 \$STATE_DIR/critic.txt(직전 라운드 critic 출력)를 비운다"
      assert_contains "$(cat "$SCRATCH/no-$sk-$mode.err")" "critic.txt)을 비웠다." "$sk X($mode): 그때 비운 «뒤에» 「비웠다」고 보고한다"
      # 문서 슬롯(brief 는 PAYLOAD · spec 은 spec_path)을 같은 Bash 호출에서 대입하지 않은 실패 분기 — STATE_DIR 이 비어
      # 비움을 건너뛰고, 그 사실을 말하며, 비웠다고 말하지 않는다(PR 3 qg iter 2 F-c).
      seed_nd="$(seed_critic "nd-$sk-$mode" "$SDOC")"
      run_fence "nd-$sk-$mode" "$f" "$PR_NOPROF" nodoc
      assert_eq "$(cat "$SCRATCH/nd-$sk-$mode.rc")" "1" "$sk X($mode) 문서 슬롯 없음: 그래도 rc 1 (dispatch 하지 않는다)"
      assert_contains "$(cat "$SCRATCH/nd-$sk-$mode.err")" "critic 출력 파일을 비우지 않았다 — STATE_DIR 도출 실패" \
        "$sk X($mode) 문서 슬롯 없음: 비움을 건너뛰었다고 말한다"
      assert_not_contains "$(cat "$SCRATCH/nd-$sk-$mode.err")" "을 비웠다" "$sk X($mode) 문서 슬롯 없음: 비우지 않은 파일을 비웠다고 말하지 않는다"
      assert_eq "$(cat "$seed_nd" 2>/dev/null)" "$CRITIC_SEED" \
        "$sk X($mode) 문서 슬롯 없음: 건너뛴 분기는 그 문서의 critic.txt 를 건드리지 않는다 (채워 둔 값 그대로)"
    done
  fi
done

# brief 는 실패를 degrade 원장에 남긴다(Step B 로 가는 채널). 원장이 못 쓰이면 두 번째 채널.
st_b="$SCRATCH/no-reviewing-brief-plain/.claude/spec-distill/no-reviewing-brief-plain/state.local.md"
fb_b="$SCRATCH/no-reviewing-brief-plain/.claude/spec-distill/no-reviewing-brief-plain/brief-degrade-fallback.txt"
if grep -qF '프로필 내용 판독 불가' "$st_b" 2>/dev/null || grep -qF '프로필 내용 판독 불가' "$fb_b" 2>/dev/null; then
  ok "reviewing-brief X: 프로필 판독 실패가 degrade 원장(또는 두 번째 채널)에 남는다"
else
  no "reviewing-brief X: 프로필 판독 실패가 degrade 원장에도 두 번째 채널에도 없다 — Step B 가 사유를 모른다"
fi
grep -qF '프로필 내용 판독 불가' "$SCRATCH/ok-reviewing-brief-plain/.claude/spec-distill/ok-reviewing-brief-plain/state.local.md" 2>/dev/null \
  && no "reviewing-brief X(양의 짝): 성공 셀에도 판독 불가 기록이 있다 — 위 기록 판정이 무엇이든 참이 된다" \
  || ok "reviewing-brief X(양의 짝): 성공 셀에는 판독 불가 기록이 없다"

finish
