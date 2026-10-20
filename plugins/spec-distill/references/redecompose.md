# 재분해 — 로드맵 에픽의 경계를 다시 나눈다

로드맵으로 나뉜 일에서 하류가 에픽 경계가 틀렸다는 신호를 내면, 인터뷰를 처음부터 다시 열지 않고 같은 로드맵 위에서 사용자 승인 뒤에만 다시 나눈다. 확정 항목 하나를 뒤집는 일은 이 절차가 아니라 재결정 규약(P23)이다 — 이 절차는 에픽 단위의 변경만 다룬다.

아래 펜스는 spec-distill 플러그인 루트가 있어야 돈다. spec-distill 이 로드된 적 없는 지휘 세션에서는 `${CLAUDE_PLUGIN_ROOT}` 가 풀리지 않아 펜스 가드가 멈춰 보고한다 — 그때는 추측하지 말고 멈추고, 사용자가 spec-distill 이 로드된 세션에서 이 절차를 돌린다.

각 칸의 주인과 갱신 길(재분해 절차인지 로드맵 수정 PR 인지)은 `${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 로 확인한다.

## 1. 신호

에픽 경계가 틀렸다는 근거면 어디서 왔든 이 절차로 온다. 아래는 지금 알려진 자리이고, 목록은 닫혀 있지 않다 — 다른 자리에서 같은 근거가 보이면 그 근거와 출처를 적어 이 절차로 온다. 신호를 잡는 일은 이 절차의 몫이 아니다. 신호를 낸 자리는 경계를 스스로 고치지 않고 보고한다.

- 번호 대조 경고 — 빠짐 · 축소 · 여러 spec(`roadmap_status.py` · 번호 대조 검사가 낸다).
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서에서 「인터뷰 다시 열기」 갈래를 골랐을 때. 지적이 그 에픽 안에서 끝나면 「이 에픽 다시 설계」 로 가고 이 절차로 오지 않는다.
- 에픽 설계 세션 — 묶음을 다시 나눌 근거를 봤을 때(에픽 넘김 줄이 나누지 말고 보고하라고 한다).
- 계획 · 구현 세션 — 계획이나 실행 방식이 이 에픽의 몫이 다른 에픽과 겹치거나 빠졌다는 근거를 찾았을 때. 예: 다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다, 이 에픽의 AC 가 아직 머지되지 않은 앞 에픽의 변경에 기댄다.
- 지휘 세션 — 에픽이 머지될 때 남은 에픽을 재평가하다 경계를 바꿔야 한다고 볼 때.

## 2. 지금 표

먼저 작업 브랜치를 만든다 — 새로 fetch 한 `origin/main` 에서 `feature/roadmap-<요지>` 브랜치를 전용 worktree 로 만들고, 아래 extract 와 5 의 update 를 모두 그 worktree 에서 돈다. 에픽의 feature 브랜치(진행 중인 설계문서가 있는 브랜치)는 고치지 않는다.

- 인터뷰 상태 파일이 docs 에 커밋돼 있으면 그 파일의 `## 분해안` 표가 지금 표다.
- 아니면 로드맵 블록과 묶음(frontmatter 번호 · §7)에서 거꾸로 뽑는다. 아래 펜스의 자리에 로드맵 경로를 따옴표로 감싸지 않고 글자 그대로 넣는다 — 5 의 경로 자리와 같은 규칙이다(경로에 줄바꿈이 있으면 넣지 말고 멈춰 사용자에게 보이고, 구분 줄 `DEVBREW_REDECOMPOSE_PATH_EOF` 와 똑같은 줄이 경로에 있으면 여는 줄과 닫는 줄의 구분자를 함께 바꾼다).

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
IFS= read -r roadmap_path <<'DEVBREW_REDECOMPOSE_PATH_EOF'
<로드맵 경로>
DEVBREW_REDECOMPOSE_PATH_EOF
python3 "$SD/scripts/roadmap_write.py" extract --roadmap="$roadmap_path"
```

출력(`## 분해안` 머리와 열한 칸 표)이 지금 표다. rc 1 이면 사유를 그대로 보이고 멈춘다.

## 3. 영향 보이기

지금 표를 고쳐 새 표를 만들고, 바뀌는 것을 표로 보인다:

| 에픽 | 바뀌는 것 | 옮겨 가는 번호 | 새 의존 | 진행 중인 브랜치 · 설계문서 |
|---|---|---|---|---|

진행 중인 브랜치 · 설계문서는 `roadmap_status.py <로드맵 경로>` 의 단계 · spec 에서 읽는다. 이어서 `AskUserQuestion` 하나:

```javascript
AskUserQuestion({
  questions: [{
    question: "다시 나눌 표와 영향을 위에 적었다. 어떻게 할까?",
    header: "재분해",
    options: [
      {label: "이대로 다시 나눈다", description: "새 표로 로드맵 블록과 묶음을 다시 쓰고 재분해 이력에 항목 하나를 남긴다."},
      {label: "고치기", description: "말로 받아 새 표를 고쳐 다시 보인다."},
      {label: "그만둔다", description: "아무것도 쓰지 않고 spec-review 게이트 ③ 의 후속 질문으로 돌아간다."}
    ],
    multiSelect: false
  }]
})
```

## 4. 번호 규칙

- 새 에픽은 다음 번호(`R<max+1>` — 블록과 재분해 이력에 나온 같은 글자 번호 중 가장 큰 것 다음)다. 새 에픽이 여럿이면 max+1, max+2 로 빈틈없이 잇는다. 재분해 이력의 「…」 안 글은 번호로 세지 않는다.
- 사라지는 번호는 재사용하지 않는다.
- 머지되거나 끝난 에픽은 건드리지 않는다 — 블록도 묶음도 그대로다. 생성기가 거부한다.
- 진행 중 에픽의 범위가 바뀌면 그 에픽의 설계문서에 남기라고 사용자에게 알린다 — 다른 에픽으로 옮겨 가는 범위는 `## 미룸` 표(칸: 항목 · 이유 · 받는 곳, 없으면 만든다)에 한 행씩, 항목은 그 범위의 `AC<n>`, 이유는 `재분해 · <날짜>`, 받는 곳은 그 범위를 받는 에픽 번호로 적는다. 받는 에픽이 없으면 받는 곳을 `없음` 으로 적는다 — `roadmap_status.py` 가 그 에픽에 받는 곳 없는 미룸 경고를 낸다. 범위가 넓어지기만 하면 `## 결정 기록` 에 `재분해 · <날짜> · <바뀐 범위>` 줄로. 이 결정 줄을 쓰는 길은 그 설계문서의 리뷰가 열려 있는지로 갈린다. 지금 이 세션에서 그 문서의 spec-review 가 열려 있으면(재분해가 그 리뷰의 「인터뷰 다시 열기」 갈래에서 왔다) 손으로 쓰지 않고 그 리뷰의 결정 줄 펜스(`${CLAUDE_PLUGIN_ROOT}/skills/spec-review/SKILL.md` 의 `decision-line` 펜스 — 원장 열기 다음, 사용자 말은 재분해를 승인한 말 그대로)로 쓴다 — 손으로 쓴 줄은 다음 리뷰 라운드에 「허가 없이 바뀜」 질문으로 돌아온다. 열린 리뷰가 없으면(지휘 세션 · 리뷰 밖의 재분해) 지금처럼 손으로 쓴다 — 그 펜스는 열린 리뷰 안에서만 쓴다(리뷰 밖에서는 표지가 없어 멈춘다). 표 행(`## 미룸` · 고친 범위 절)도 같다 — 표 행을 고치기 전에, 그 문서의 리뷰가 열려 있고 이 재분해의 근거가 된 채택 결정이 있으면 `docreview_state.py declare-related --state-dir D --decision <D#> --anchors '<고친 절 앵커>' …` 로 고칠 절을 모두 결정에 묶는다(원장 쓰기 — 진입 skill 의 표지 확인 줄 다음에만, 같은 Bash 호출에서). `## 미룸` 표 행도 묶는다 — 사용자 문서의 보통 절이다. 묶을 수 없는 것은 `## 결정 기록` 과 프로필의 미룸 자리(`### Deferred to plan`)뿐이다 — 엔진만 줄을 덧붙이는 울타리라 엔진이 거부한다. `declare-related` 가 rc 0 이 아니면(묶지 못했다) 엔진이 낸 사유를 그대로 보이고, 채택한 결정이 없을 때와 같이 사용자에게 먼저 알린다. 채택한 결정이 없으면 고친 표 행은 다음 게이트에 「허가 없이 바뀜」 결정으로 다시 온다 — 그 사실을 사용자에게 먼저 알리고, 그 게이트에서 「고친 대로 둠」으로 닫는다. 리뷰가 닫힌 뒤에는 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 손으로 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다). 끝맺음을 건너뛰어 계수 줄이 없거나 계수 줄에 표지가 없는 옛 원장이면 재리뷰가 그 줄을 한 번 묻는다 — 「고친 대로 둠」으로 닫는다. 리뷰가 닫힌 뒤 고친 표 행은 같은 문서의 재리뷰에서 다시 묻는다.

## 5. 적용

승인된 새 표(첫 절 `## 분해안`)를 아래 펜스의 heredoc 자리에 넣어 생성기를 부른다. 로드맵 · 원본 brief · 원본 audit 경로, 사유 한 줄, 사용자 말도 각자의 heredoc 자리에 따옴표로 감싸지 않고 글자 그대로 넣는다. 경로나 사유에 줄바꿈이 있으면 넣지 말고 멈춰 그 사실을 사용자에게 보인다. 넣는 글에 그 자리의 구분 줄(`DEVBREW_REDECOMPOSE_PATH_EOF` · `DEVBREW_REDECOMPOSE_CHANGE_EOF` · `DEVBREW_REDECOMPOSE_TABLE_EOF` · `DEVBREW_REDECOMPOSE_APPROVAL_EOF`)과 똑같은 줄이 있으면 그 자리의 여는 줄과 닫는 줄의 구분자를 글에 없는 다른 낱말로 함께 바꾼다. 사용자 말이 여럿이면 `AF1=` 줄부터 그 닫는 구분 줄까지를 말마다 `AF2` · `AF3` … 으로 하나씩 더하고, `--approval="$(cat "$AF<k>")"` 를 말마다 하나씩 붙인다(`=` 꼴 — 「-」 로 시작하는 말도 옵션으로 읽히지 않는다). 표와 말은 이 펜스가 만든 임시 파일에만 살고 펜스가 끝나면 지워진다 — 세션 상태 폴더에 쓰지 않는다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
IFS= read -r roadmap_path <<'DEVBREW_REDECOMPOSE_PATH_EOF'
<로드맵 경로>
DEVBREW_REDECOMPOSE_PATH_EOF
IFS= read -r brief_path <<'DEVBREW_REDECOMPOSE_PATH_EOF'
<원본 brief>
DEVBREW_REDECOMPOSE_PATH_EOF
IFS= read -r audit_path <<'DEVBREW_REDECOMPOSE_PATH_EOF'
<원본 audit>
DEVBREW_REDECOMPOSE_PATH_EOF
IFS= read -r change_line <<'DEVBREW_REDECOMPOSE_CHANGE_EOF'
<사유 한 줄>
DEVBREW_REDECOMPOSE_CHANGE_EOF
TABLE="$(mktemp "${TMPDIR:-/tmp}/redecompose-table.XXXXXX")" || { echo "[spec-distill] 표 임시 파일을 만들지 못했다" >&2; exit 1; }
AD="$(mktemp -d "${TMPDIR:-/tmp}/redecompose-approval.XXXXXX")" || { rm -f -- "$TABLE"; echo "[spec-distill] 사용자 말 임시 폴더를 만들지 못했다" >&2; exit 1; }
trap 'rm -f -- "$TABLE"; rm -rf -- "$AD"' EXIT
cat > "$TABLE" <<'DEVBREW_REDECOMPOSE_TABLE_EOF'
<승인된 새 표 — `## 분해안` 머리와 열한 칸 표>
DEVBREW_REDECOMPOSE_TABLE_EOF
AF1="$AD/1"
cat > "$AF1" <<'DEVBREW_REDECOMPOSE_APPROVAL_EOF'
<사용자 말 그대로>
DEVBREW_REDECOMPOSE_APPROVAL_EOF
u_rc=0
python3 "$SD/scripts/roadmap_write.py" update --roadmap="$roadmap_path" --brief="$brief_path" \
  --audit="$audit_path" --plan-table "$TABLE" \
  --date "<YYYY-MM-DD>" --change="$change_line" --approval="$(cat "$AF1")" || u_rc=$?
exit "$u_rc"
```

- 바뀐 블록과 그 묶음만 다시 쓰고, 재분해 이력에 항목 하나를 더한다 — 머리 `### <날짜> · <사유>`(사유는 `--change`), 그 아래 `- 바뀜:`(생성기가 바뀐 에픽 · 새 에픽 · 사라진 에픽 번호를 적고 끝에 승인 인용 「…」 을 단다)과 `- 원문:`(하위 항목 한 줄에 사용자 말 하나, 「…」 그대로). 원문 칸에는 사용자 말만 둔다. 사용자 말이 여럿이면 `--approval` 을 말마다 하나씩 준다.
- 사용자가 선택지 라벨만 고르고 따로 적은 말이 없으면 `--approval` 에 고른 라벨을 글자 그대로 넘긴다 — 고른 라벨이 그 사용자의 말이다. 표가 블록 순서만 다르면 생성기는 바뀜에 「순서만」 을 적는다 — 그때 `--change` 사유에 무엇을 왜 다시 나눴는지 적는다.
- 쓴 직후 생성 때와 같은 검증(`format_errors` · `unassigned` · `orphans` · `unknown_ids` 넷이 빈 목록)이 돈다. 실패하면 덮어쓴 파일은 원래 바이트로 돌아가고 새로 만든 파일은 지워진 채 rc 1 이다. rc 1 은 사유로 가른다.
  - 사유가 `brief §5 위험 줄 가운데 K 번호가 없는 줄` 이나 `brief §5 위험 줄의 K 번호가 겹친다` 면 표로 돌아가지 않고 멈추고 사유를 보인다 — 원인은 표가 아니라 brief §5 의 위험 줄 번호다. 재분해는 이력 brief 를 고치지 않는다 — brief 번호를 고쳐야 한다는 사실만 사용자에게 알리고 끝낸다.
  - 그 밖의 사유(검증 넷)는 사유를 그대로 보이고 3 으로 돌아간다.
- rc 0 이면 생성기가 `RISK_ORDER_NOTICE`(위험 줄에 번호가 없어 줄 순서로 매겼다는 줄)를 함께 낼 수 있다. 정보 줄이라 멈추지 않는다 — 생성기가 낸 그대로 사용자에게 보이고 이어 간다.
- 머지되거나 끝난 에픽을 바꾸거나 지우는 표, 쓴 적 있는 번호를 다시 쓰는 표, 번호가 빈틈없이 이어지지 않는 표, 머지 여부를 알 수 없는 레포는 쓰기 전에 rc 1 이다. 새 묶음 파일 자리에 이미 `<id>.md` 가 있거나(남의 파일) 묶음이 아니던 에픽의 `<id>.md` 가 있을 때도 쓰기 전에 rc 1 이다.

- 인터뷰 상태 파일이 docs 에 커밋돼 있으면 같은 로드맵 PR 에서 그 파일의 `## 분해안` 표를 `roadmap_write.py extract` 출력으로 바꿔 둔다 — 안 그러면 다음 재분해의 지금 표가 낡는다.

## 6. 올리기

로드맵 수정은 2 에서 만든 `feature/roadmap-<요지>` 브랜치에서 PR 로 올린다(`${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 의 손 절차 6). 머지는 사용자가 한다.

## 7. 끝내기

이 절차는 말없이 끝나지 않는다. 끝은 둘 중 하나다.

- 성공 — 바뀐 묶음을 보인 뒤, 심사 중이던 에픽 설계문서를 그 (바뀌었을 수 있는) 묶음에 맞춰 고쳐야 한다고 알린다. 고친 뒤 spec-review 를 부르기 전에 `check_bundle_coverage.py <묶음> <설계문서>` 를 먼저 돌려 빠진 번호가 없는지 보고, 그 설계문서 경로 뒤에 `--bundle <묶음의 레포 상대경로>` 를 붙여 spec-review 를 다시 돌린다. 새로 생긴 묶음 에픽의 설계는 `${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md` 의 에픽 넘김 줄로 연다. 다음 할 일 하나만 말하고 턴을 끝낸다.
- 「그만둔다」 — 아무것도 쓰지 않고 spec-review 게이트 ③ 의 후속 질문(「지적대로 고치기」 · 「이 에픽 다시 설계」 · 「인터뷰 다시 열기」 · 「직접 편집」 네 갈래)으로 돌아간다. 게이트 ③ 에서 온 길이 아니면(1 의 다른 신호) 어느 에픽 설계문서로 spec-review 를 다시 부를지 한 줄로 말하고 끝낸다.
