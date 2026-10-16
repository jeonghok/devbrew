## 인터뷰 상태 파일

이 인터뷰의 진행 기록(frontmatter 스키마 · `## R<n>` 라운드 기록 · 조사 원문 · `## audit §2 대기 줄`)은 작업 트리의
`docs/superpowers/interview/<날짜>-<주제>-interview.state.md` 한 파일에 산다. brief · audit 는 같은 줄기로 옆에 놓인다
(`<줄기>.md` · `<줄기>.audit.md`). 작업 트리 안이라 `Write` · `Edit` 로 고친다.

### 진입 판결

SKILL 진입 단계 3.6 펜스의 마지막 줄이 판결이다(`REJECT` 는 SKILL 이 멈춘다). 각 행의 절차는 아래 절들에 있다.

| 판결 | 동작 |
|---|---|
| `interview-state: RESUME <경로>` | 그 상태 파일로 이어 간다 |
| `interview-state: ASK` | 이어 감/새로 시작을 묻는다 |
| `interview-state: LEGACY <경로>` | 옛 진행 기록을 docs 로 옮긴 뒤 이어 간다 |
| `interview-state: NEW-SEED <주제> seed=<경로>` · `interview-state: NEW` | 상태 파일을 만든다 — NEW-SEED 는 첫 라운드 전, NEW 는 첫 라운드에서 주제를 정한 직후 |

### 처음 만들 때

frontmatter 첫 두 키:

```yaml
type: interview-state
seed: <작업 트리 루트 기준 seed 상대경로 | 없음>
```

그 뒤에 SKILL `## State location` 의 스키마 키가 온다.

본문 맨 앞에는 `## 풀린 입력` 블록을 두고 「풀린 입력」(진입 단계 2 의 결과 — NEW-SEED 면 Read 한 seed 전문, NEW 면 받은 요청
그대로)을 P21 secret placeholder 치환을 적용한 뒤 그대로 적는다 — token · key · credential 꼴은 SKILL 의 치환 토큰(`<REDACTED>` ·
`<REDACTED:라벨>` 등)으로 바꾼다. brief §6 의 `S1` 이 담을 글과 같은 치환본이다. 물결표 펜스(`~~~~`)로 감싸고, 원문에 그만큼 긴
물결표 줄이 있으면 펜스를 더 길게 한다. 치환 뒤에는 이 블록을 고치지 않는다 — 이어 갈 때 `S1` 이 여기서 나온다.

- 판결이 `interview-state: NEW-SEED <주제> seed=<상대경로>` 면 첫 라운드 **전에** 만든다 — `<주제>` 를 그대로 topic 으로,
  `seed=` 값을 `seed:` 로 쓴다.
- 판결이 `interview-state: NEW` 면 첫 라운드에서 주제를 정한 직후 만들고 그 라운드의 기록을 첫 내용으로 쓴다(그 전까지
  라운드 1 기록은 대화 안에만 있다). `seed:` 는 `없음`.
- 경로는 늘 스크립트가 낸다. 상태 파일은 그 출력 경로에만 만든다. rc 가 0 이 아니면 그 stderr 를 보이고 멈춘다(남의 파일
  위에 시작하지 않는다):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/state_path.py" interview-state --topic "<kebab 주제>"
```

  그 자리에 이미 `type: interview-state` 파일이 있으면 새로 쓰지 않는다 — topic 을 `<주제>-<HHMM>` 으로 바꿔 다시 낸다.

### 이어 갈 때

- `interview-state: RESUME <경로>` — 그 파일을 읽고 `state-migration.md` 의 스키마 이월을 적용한 뒤 마지막 라운드 다음부터 간다.
- `interview-state: ASK` — 앞 줄의 `candidate: <경로>` 가 같은 seed 의 끝나지 않은 상태 파일이다. `AskUserQuestion` 하나로
  「이어 감 (권장)」/「새로 시작」을 묻는다(후보가 둘 이상이면 이어 감 선택지를 후보마다 하나씩). 이어 감이면 고른 후보로 3.6 펜스를
  `ARG_PATH='<후보 경로>'` 로 다시 돌리고, 판결이 RESUME 일 때만 RESUME 과 같이 간다(아니면 그 줄을 보이고 멈춘다).
  새로 시작이면 topic 을 `<seed 주제>-brief-<HHMM>` 으로 바꿔 위 펜스로 새 경로를 낸다. 기존 파일은 지우지 않는다.
- 이어 갈 때 「풀린 입력」은 그 파일의 `## 풀린 입력` 블록 펜스 안의 글이다 — 상태 파일 전문이 아니다. 그 블록이 없으면(옛 자리에서
  옮긴 파일) 옛 기록에 남은 최초 요청을 쓰고, 그것도 없으면 「풀린 입력」은 없음(`S1` 없음)이다 — 그 사실을 사용자에게 한 번 알린다.
- 이어 갈 때는 고른 파일의 절대경로가 그 인터뷰의 정체다. brief · audit 경로는 그 이름에서 `.state.md` 를 떼어 도출하고,
  날짜 · 주제로 다시 계산하지 않는다.

### 옛 자리의 진행 기록

`interview-state: LEGACY <옛 경로>` 면 그 파일(이전 버전이 쓰던 `.claude/spec-distill/<session-id>/state.local.md`)을 읽어
주제를 정하고(기록에서 정하지 못하면 사용자에게 한 번 묻는다) 옮긴다. 출력 줄을 그대로 보인다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
python3 "$SD/scripts/interview_state.py" migrate-legacy --session "$sid" --topic "<kebab 주제>" --seed "<seed 절대경로 — 없으면 이 인자를 뺀다>"
```

rc 0 이면 옮긴 경로로 RESUME 과 같다. 0 이 아니면 그 사유를 보이고 멈춘다.

### 끝낼 때

brief · audit · 상태 파일 셋은 `finishing.md` B-3 의 커밋 펜스가 한 번에 커밋한다(①/② 의 확정 반영 · 게이트 재실행 통과 뒤,
④ 는 종료 안내 직전). 분해된 일이면 로드맵 폴더도 같은 커밋에 든다. 상태 파일은 지우지 않는다.
