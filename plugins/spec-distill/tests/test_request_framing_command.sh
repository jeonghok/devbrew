#!/usr/bin/env bash
# guards: plugins/spec-distill/commands/request-framing.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/references/compression.md plugins/spec-distill/templates/interview-seed-template.md
#
# `/request-framing` command 가 자기 세 책임을 실제로 담고 있는가 — kill switch ·
# trivia escape 포인터 · skill dispatch. 그 셋뿐이고, 셋 다 없으면 안 된다.
#
# **포인터로 재는 이유**: trivia 5패턴을 이 파일에 그대로 쓰면 `interview.md` 와
# 20줄 이상 동일 구간이 생겨 `shared/tests/test_no_new_duplication.sh` 가 RED 를 낸다.
# 그래서 정본은 `references/trivia-escape.md` 이고 여기는 가리키기만 한다.
#
# ── 이 락이 재지 «못하는» 것 (실측) ─────────────────────────────────────────
# 아래 넷은 전부 **파일 어딘가에 그 리터럴이 있는가**를 보는 bare `grep -q` 다. 리터럴이
# 어느 문맥에 있는지, 그 문맥이 리터럴을 **긍정하는지 부정하는지**는 보지 않는다. 실측:
# 본문 끝에 「이 command 는 아래를 **항상 무시**한다 — 아무것도 실행하지 않는다」는 절을
# 붙이고 그 안에서 `DEVBREW_SPEC_DISTILL_DISABLE` · `references/trivia-escape.md` ·
# `framing-requests` 셋을 「…하지 않는다」로 인용하기만 해도 이 스위트는 **GREEN** 이다.
# 즉 「세 책임을 담고 있다」는 이 파일의 주장은 **리터럴 실재까지만** 보장한다.
#
# **계측기가 죽은 것은 아니다**(양성 대조, 실측): kill switch 문장을 실제로 지우면 RED 다.
# 리터럴 «삭제» 축에는 이빨이 있고, 리터럴 «부정» 축에는 없다 — 그 경계가 여기다.
#
# 형제 셋(`test_seed_gate_wiring.sh` · `test_seed_agents.sh` · `test_seed_codex_axes.sh`)은
# 관측된 사후상태로 판정해 이 부류를 넘지만, 그것들은 실행할 대상이 있는 락이다. 이
# command 는 실행되는 코드가 아니라 모델이 읽는 지시문이라 같은 방법을 쓸 수 없다 —
# 갭을 닫는 대신 여기 적어 둔다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CMD="$ROOT/plugins/spec-distill/commands/request-framing.md"
. "$ROOT/shared/tests/assert.sh"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/commands/request-framing.md"
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
  echo "plugins/spec-distill/references/compression.md"
  echo "plugins/spec-distill/templates/interview-seed-template.md"
  exit 0
fi

[ -f "$CMD" ] || { no "command 파일 부재: $CMD"; finish; exit $?; }
ok "command 파일 실재"

grep -q 'DEVBREW_SPEC_DISTILL_DISABLE' "$CMD" \
  && ok "kill switch 존중" || no "kill switch 가 없다 — 훅 밖 진입점이 스위치를 무시한다"

grep -qE 'references/trivia-escape\.md' "$CMD" \
  && ok "trivia escape 정본 포인터" || no "trivia escape 포인터가 없다"

grep -qE 'Skill .*framing-requests|framing-requests' "$CMD" \
  && ok "skill dispatch" || no "framing-requests skill 을 호출하지 않는다"

# 5패턴을 여기 «복제하지» 않았는가 — 정본이 있는데 사본이 있으면 둘이 갈라진다.
pc="$(grep -cE '^[0-9]\. \*\*(Typo|주석-only|formatting|단일 식별자|<10 토큰)' "$CMD")"
[ "$pc" -eq 0 ] \
  && ok "5패턴 본문이 복제되지 않았다 (정본만)" \
  || no "5패턴 본문이 이 파일에 복제돼 있다 (${pc}줄) — 정본과 갈라진다"

# --- v0.57.0 AC11: seed 산문 규약 (블록 스코프) -------------------------------------------
SK="$ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"
CMP="$ROOT/plugins/spec-distill/references/compression.md"
TPL="$ROOT/plugins/spec-distill/templates/interview-seed-template.md"
conv_block="$(awk '/^### 확정 표시와 «다시 검증할 것»/{f=1;print;next} /^##/{f=0} f' "$SK")"
conv_flat="$(tr '\n' ' ' <<<"$conv_block" | tr -s ' ')"
# 수정 라운드 1: bare 리터럴 '(사용자 확인)' 은 이 블록의 안전망 문단(마커 오용 설명)에도
# 다시 등장해, 규칙 문장(「확정 표시는 «(사용자 확인)» 하나」)을 지워도 안전망 문단이 대신
# 만족시켜 GREEN 이 유지된다(자체 삭제-방향 뮤테이션으로 실측 — 리뷰가 지적한 것과 같은
# 결함을 이번 라운드의 내 수정이 새로 만들었다). 규칙 문장 고유의 리터럴로 좁힌다.
grep -qF '확정 표시는 «(사용자 확인)» 하나' <<<"$conv_block" && ok "AC11: SKILL 규약 절 + «(사용자 확인)» 표시" || no "AC11: 규약 절/확정 표시 부재"
# 수정 라운드 1: 「다시 검증할 것 —」bare 리터럴은 같은 블록 안 예시 문장(「예: «다시 검증할 것
# — 종료 술어가…»」)에도 그대로 있어, 규칙 문장(「마지막 문단은 «다시 검증할 것 —»로 시작」)을
# 지워도 예시가 대신 만족시켜 GREEN 이 유지됐다(리뷰 지적, 삭제-방향 뮤테이션으로 실측). 규칙
# 문장에만 있는 「…—»로 시작」 인접 표현으로 좁힌다 — 예시는 »다음에 「.」가 오지 「로 시작」이
# 오지 않으므로 이 리터럴을 만족시키지 못한다.
grep -qF '다시 검증할 것 —»로 시작' <<<"$conv_block" && ok "AC11: 마지막 문단 «다시 검증할 것 —»로 시작 규칙" || no "AC11: 재검증 문단 규약 부재"
grep -qE '그 밖[^.]{0,30}미확인|나머지[^.]{0,30}미확인' <<<"$conv_flat" && ok "AC11: 무표시 = 미확인" || no "AC11: 무표시=미확인 문장 부재"
# 수정 라운드 1: 「태그[^.]{0,30}(쓰지 않|없)」는 안전망 문장(「태그 없는 산문으로 떨어질 뿐」)도
# 만족시켜, 규칙 문장(「seed 는 태그를 쓰지 않습니다」)을 지워도 GREEN 이 유지됐다(리뷰 지적,
# 삭제-방향 뮤테이션으로 실측). 규칙 문장 고유의 리터럴로 좁힌다.
grep -qF 'seed 는 태그를 쓰지 않습니다' <<<"$conv_block" && ok "AC11: 태그 문법 없음 (check_seed 정합)" || no "AC11: 태그 금지 문장 부재"
cmp_block="$(awk '/^## 확정 표시와 마지막 문단/{f=1;print;next} /^## /{f=0} f' "$CMP")"
{ [[ -n "$cmp_block" ]] && grep -qF '(사용자 확인)' <<<"$cmp_block" && grep -qF '다시 검증할 것 —' <<<"$cmp_block"; } \
  && ok "AC11: compression.md 규약 절" || no "AC11: compression.md 규약 절 부재"
tpl_ex="$(awk '/^```markdown/{f=1;next} f&&/^```/{exit} f' "$TPL")"
grep -qF '(사용자 확인)' <<<"$tpl_ex" && ok "AC11: seed 템플릿 예시에 확정 표시" || no "AC11: 템플릿 예시 확정 표시 부재"
[[ "$(printf '%s\n' "$tpl_ex" | grep -v '^\s*$' | tail -1 | head -c 400)" == *"다시 검증할 것"* || "$(awk -v RS='' 'END{print}' <<<"$tpl_ex")" == "다시 검증할 것 —"* ]] \
  && ok "AC11: 템플릿 예시의 마지막 문단이 «다시 검증할 것 —»로 시작" || no "AC11: 템플릿 마지막 문단 규약 위반"
# check_seed.py 는 손대지 않는다 — Task 착수 커밋(main merge) 대비 diff 0
[[ -z "$(git -C "$ROOT" diff --name-only main -- plugins/spec-distill/scripts/check_seed.py)" ]] \
  && ok "AC11: check_seed.py 무변경 (diff 0 vs main)" || no "AC11: check_seed.py 가 변경됐다"

# --- v0.57.0 AC12: 워크트리 (블록 스코프) -------------------------------------------------
wt_block="$(awk '/^## 워크트리 — 진입 직후/{f=1;print;next} /^## /{f=0} f' "$SK")"
wt_flat="$(tr '\n' ' ' <<<"$wt_block" | tr -s ' ')"
{ [[ -n "$wt_block" ]] && grep -qF 'AskUserQuestion(' <<<"$wt_block"; } && ok "AC12: 워크트리 절 + 단독 AskUserQuestion" || no "AC12: 워크트리 절/질문 부재"
grep -qE 'audit[^.]{0,20}첫 write[^.]{0,10}전|첫 write 전' <<<"$wt_flat" && ok "AC12: audit 첫 write 전에 묻는다" || no "AC12: 시점(첫 write 전) 부재"
grep -qF 'feature/<kebab-topic>' <<<"$wt_block" && ok "AC12: feature/<kebab-topic> 이름" || no "AC12: 브랜치 이름 규약 부재"
[[ "$(grep -cE '^[1-5]\. ' <<<"$wt_block")" -eq 5 ]] && ok "AC12: 5단계 절차" || no "AC12: 5단계가 아니다 ($(grep -cE '^[1-5]\. ' <<<"$wt_block"))"
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE' <<<"$wt_block" && ok "AC12: kill switch 를 절이 본다" || no "AC12: 절에 kill switch 부재"
# 수정 라운드 1: base-ref 풋건이 질문 «앞»에서 확인되고 질문 본문에 실리는가(질문 뒤에만
# 적으면 사용자가 이미 고른 뒤에야 안다 — 리뷰 지적). 리터럴은 실제 실행 줄에만 있는
# 것으로 좁힌다 — bare 'rev-list'/'확인 못함' 은 같은 구간의 설명 산문(주석·caveat 문단)에도
# 다시 등장해, 규칙 줄(실제 명령/대입)을 지워도 그 산문이 대신 만족시켜 GREEN 이 유지된다
# (AC11 에서 실측된 것과 같은 결함 — 삭제-방향 뮤테이션으로 직접 확인 후 좁혔다).
pre_q="${wt_block%%AskUserQuestion(*}"
grep -qF 'git rev-list --count' <<<"$pre_q" && ok "AC12: 로컬 전용 커밋 확인이 질문 앞에 있다" || no "AC12: 로컬 전용 커밋 확인이 질문 앞에 없다"
# v1.0.1: 빈 요청에는 워크트리 이름을 댈 주제가 없다. 주제 질문이 워크트리 질문 «앞»에 있는지
# (위치 축 — 절 안 어딘가가 아니라 pre_q), 그 답이 audit 원문으로 가는지, command 가 순서를
# 다시 정하지 않고 이 절을 가리키는지.
grep -qF '무엇을 맡기려' <<<"$pre_q" && ok "AC12: 빈 요청의 주제 질문이 워크트리 질문 앞에 있다" || no "AC12: 빈 요청의 주제 질문이 워크트리 질문 앞에 없다"
grep -qF '건너뛰는 경우도 같다' <<<"$(tr '\n' ' ' <<<"$pre_q" | tr -s ' ')" && ok "AC12: 워크트리를 건너뛰어도 주제 질문이 먼저다" || no "AC12: 워크트리를 건너뛰는 경로에서 주제 질문 순서가 빠졌다"
grep -qF '첫 행동**이다(빈 요청일 때만' <<<"$wt_flat" && ok "AC12: «첫 행동» 문장이 빈 요청 예외를 스스로 밝힌다" || no "AC12: «첫 행동» 문장이 빈 요청 예외 없이 단정한다 — 절 안에서 모순"
grep -qE '1\. 원문[^.]{0,20}첫 항목' <<<"$wt_flat" && ok "AC12: 주제 질문의 답이 audit 원문 첫 항목으로 간다" || no "AC12: 주제 질문의 답이 audit 원문으로 가는 규칙 부재"
args_block="$(awk '/^## Arguments/{f=1;next} /^## /{f=0} f' "$CMD")"
{ grep -qF '무엇을 맡기려' <<<"$args_block" && grep -qF '워크트리 — 진입 직후' <<<"$args_block"; } && ok "AC12: command 가 빈 요청 순서의 정본으로 skill 절을 가리킨다" || no "AC12: command 의 빈 요청 안내가 skill 절을 안 가리킨다"
askq_block="$(awk '/^```javascript$/{f=1;next} f&&/^```$/{exit} f' <<<"$wt_block")"
grep -qF 'LOCAL_ONLY_NOTE' <<<"$askq_block" && ok "AC12: 질문 본문에 로컬 전용 커밋 안내가 실린다" || no "AC12: 질문 본문에 로컬 전용 커밋 안내 부재"
grep -qF 'LOCAL_ONLY_NOTE="확인 못함' <<<"$wt_block" && ok "AC12: base 부재/확인 실패가 «확인 못함» 으로 드러난다" || no "AC12: 확인 불가 상태가 침묵(또는 0건 오독)으로 떨어진다"
# 위 셋은 「확인이 있는가·앞에 있는가·실패가 드러나는가」만 재고 **무엇을 기준으로 재는가**는
# 안 봤다. 그래서 tracking branch(`@{u}`) 를 재던 동안 셋 다 green 이었다 — 워크트리 base 는
# origin 의 기본 브랜치인데(EnterWorktree baseRef=fresh) 자기 remote 를 추적하는 브랜치는
# push 를 마쳤다는 이유로 «0» 을 보고하면서 실제로는 origin/main 과 발산해 있을 수 있다.
# 그때 워크트리는 조용히 커밋을 빠뜨린다. 기준 자체를 잰다.
rev_line="$(grep -F 'git rev-list --count' <<<"$pre_q")"
[[ -n "$rev_line" ]] \
  && ok "AC12(양성대조): rev-list 실행 줄을 찾았다 (아래 단언이 실재한다)" \
  || no "AC12(양성대조): rev-list 실행 줄이 없다 — 아래 단언이 공허하다"
grep -qF '"@{u}"' <<<"$rev_line" \
  && no "AC12: 발산을 tracking branch 기준으로 잰다 — 워크트리 base(origin 기본 브랜치)가 아니다" \
  || ok "AC12: 발산 기준이 tracking branch 가 아니다"
grep -qF '"$base"..HEAD' <<<"$rev_line" \
  && ok "AC12: 발산을 «워크트리가 실제로 쓰는 base» 기준으로 잰다" \
  || no "AC12: rev-list 가 도출한 base 를 안 쓴다 — 산문의 «origin 기준» 주장과 갈린다"
grep -qF 'refs/remotes/origin/HEAD' <<<"$pre_q" \
  && ok "AC12: origin 의 기본 브랜치를 열거가 아니라 도출한다" \
  || no "AC12: origin 기본 브랜치 도출이 없다 — main 하드코딩은 다른 기본 브랜치 리포서 틀린다"
{ grep -qF '실측한 것' <<<"$wt_block" && grep -qF '실측 밖' <<<"$wt_block"; } && ok "AC12: 단정 범위 문장이 잰 것/안 잰 것을 가른다" || no "AC12: 단정 범위 문장이 자기모순(모두 단정 안 함으로 읽힘)"
grep -qF '워크트리 없음 —' <<<"$wt_block" && ok "AC12: 거절/부재 시 audit §5 문구" || no "AC12: 강등 문구 부재"
grep -qE '(거절|부재|스위치)[^.]{0,60}seed[^.]{0,20}막지 않' <<<"$wt_flat" && ok "AC12: 어느 경우도 seed 작성을 막지 않는다" || no "AC12: 비차단 선언 부재"
ks_block="$(awk '/^## kill switch/{f=1;print;next} /^## /{f=0} f' "$SK")"
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1' <<<"$ks_block" && ok "AC12: kill switch 목록 등재" || no "AC12: kill switch 목록에 없다"
gate_block="$(awk '/^## 확정 — proceed 게이트/{f=1;print;next} /^## /{f=0} f' "$SK")"
gate_flat="$(tr '\n' ' ' <<<"$gate_block" | tr -s ' ')"
grep -qF 'docs(interview): <topic> interview seed + audit' <<<"$gate_block" && ok "AC12: 커밋 메시지 리터럴 (C10 과 동일)" || no "AC12: 커밋 메시지 리터럴 부재/불일치"
grep -qE '(①|②)[^.]{0,80}handoff 직전[^.]{0,40}커밋' <<<"$gate_flat" && ok "AC12: ①/② 에서 handoff 직전 커밋" || no "AC12: 커밋 시점 규칙 부재"
grep -qE '(③|④)[^.]{0,40}커밋하지 않' <<<"$gate_flat" && ok "AC12: ③/④ 는 커밋 없음" || no "AC12: ③/④ 비커밋 규칙 부재"
grep -qE '워크트리 절대경로|절대경로' <<<"$gate_flat" && ok "AC12: 게이트 텍스트에 워크트리 경로" || no "AC12: 게이트 경로 안내 부재"
grep -qF 'git commit -q -F' <<<"$gate_block" && ok "AC12: 커밋은 -F 파일 한 줄 명령" || no "AC12: 커밋 명령 모양 부재"

finish
