## 컨텍스트 쌓기 상태 파일

이 컨텍스트 쌓기의 진행 기록(frontmatter 스키마 · `## R<n>` 라운드 기록 · 조사 원문 · `## audit §2 대기 줄`)은 작업 트리의
의도 폴더(`intent_dir`)의 `<날짜>-<주제>-context.state.md` 한 파일에 산다(옛 꼴 상태 파일로 이어 온 일은 그 파일의 폴더 · 줄기 그대로). brief · audit 는 같은 줄기로 옆에 놓인다
(`<줄기>.md` · `<줄기>.audit.md`). 작업 트리 안이라 `Write` · `Edit` 로 고친다.

### 진입 판결

SKILL 진입 단계 3.6 펜스의 마지막 줄이 판결이다(`REJECT` 는 SKILL 이 멈춘다). 각 행의 절차는 아래 절들에 있다.

| 판결 | 동작 |
|---|---|
| `context-state: RESUME <경로>` | 그 상태 파일로 이어 간다 |
| `context-state: ASK` | 이어 감/새로 시작을 묻는다 |
| `context-state: LEGACY <경로>` | 옛 진행 기록을 docs 로 옮긴 뒤 이어 간다 |
| `context-state: NEW-SEED <주제> seed=<경로>` · `context-state: NEW` | 상태 파일을 만든다 — NEW-SEED 는 첫 라운드 전, NEW 는 첫 라운드에서 주제를 정한 직후 |

### 처음 만들 때

frontmatter 첫 두 키:

```yaml
type: context-state
seed: <작업 트리 루트 기준 seed 상대경로 | 없음>
```

그 뒤에 SKILL `## State location` 의 스키마 키가 온다.

본문 맨 앞에는 `## 풀린 입력` 블록을 두고 「풀린 입력」(진입 단계 2 의 결과 — NEW-SEED 면 Read 한 seed 전문, NEW 면 받은 요청
그대로)을 P21 secret placeholder 치환을 적용한 뒤 그대로 적는다 — token · key · credential 꼴은 SKILL 의 치환 토큰(`<REDACTED>` ·
`<REDACTED:라벨>` 등)으로 바꾼다. framing 없이 시작한 컨텍스트 쌓기와 원자료를 찾지 못했거나 그대로 싣지 못한 컨텍스트 쌓기에서는 brief §6 의 `S1` 이 담을 글과 같은 치환본이다(원자료를 찾아 실은 컨텍스트 쌓기의 `S1` 에는 이 블록이 아니라 원자료가 실린다). 물결표 펜스(`~~~~`)로 감싸고, 원문에 그만큼 긴
물결표 줄이 있으면 펜스를 더 길게 한다. 치환 뒤에는 이 블록을 고치지 않는다 — 이어 갈 때 「풀린 입력」 이 여기서 나온다(끝맺음의 비밀값 확인이 사용자가 고른 값을 가리는 것만 예외다 — `finishing.md` Step A 3).

- 판결이 `context-state: NEW-SEED <주제> seed=<상대경로>` 면 첫 라운드 **전에** 만든다 — `<주제>` 를 그대로 topic 으로,
  `seed=` 값을 `seed:` 로 쓴다.
- 판결이 `context-state: NEW` 면 첫 라운드에서 주제를 정한 직후 만들고 그 라운드의 기록을 첫 내용으로 쓴다(그 전까지
  라운드 1 기록은 대화 안에만 있다). `seed:` 는 `없음`.
- 경로는 늘 스크립트가 낸다. 상태 파일은 그 출력 경로에만 만든다. rc 가 0 이 아니면 그 stderr 를 보이고 멈춘다(남의 파일
  위에 시작하지 않는다). rc 0 이어도 stderr 에 `[spec-distill]` 줄이 있으면 그대로 보인다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/state_path.py" context-state --topic "<kebab 주제>"
```

  같은 자리에 끝난 컨텍스트 쌓기(brief 가 있는 자리)가 있으면 스크립트가 `<주제>-<HHMM>` 자리를 내고 한 줄 알린다 — 나온 경로를 그대로 쓴다. 끝나지 않은 `type: context-state`(옛 `interview-state`) 파일이 있으면 새로 쓰지 않는다 — topic 을 `<주제>-<HHMM>` 으로 바꿔 다시 낸다.

### 이어 갈 때

- `context-state: RESUME <경로>` — 그 파일을 읽고 `state-migration.md` 의 스키마 이월을 적용한 뒤 마지막 라운드 다음부터 간다.
- `context-state: ASK` — 앞 줄의 `candidate: <경로>` 가 같은 seed 의 끝나지 않은 상태 파일이다. `AskUserQuestion` 하나로
  「이어 감 (권장)」/「새로 시작」을 묻는다(후보가 둘 이상이면 이어 감 선택지를 후보마다 하나씩, 그 설명 앞에 후보 이름을 붙인다). 설명은 이렇게 쓴다 — 「이어 감」: 얻음: 끝나지 않은 컨텍스트 쌓기를 마지막 라운드 다음부터 잇는다 · 내줌: 옛 상태 파일의 기록을 맞다고 믿고 이어 가는 셈이 된다 / 「새로 시작」: 얻음: 새 상태 파일에서 처음부터 시작한다 · 내줌: 앞서 모은 라운드 답과 조사가 이 컨텍스트 쌓기에 이어지지 않는다. 이어 감이면 고른 후보로 3.6 펜스를
  `ARG_PATH='<후보 경로>'` 로 다시 돌리고, 판결이 RESUME 일 때만 RESUME 과 같이 간다(아니면 그 줄을 보이고 멈춘다).
  후보 경로는 `candidate:` 줄의 글자 그대로만 붙인다 — 스크립트는 허용 글자(글자 · 숫자 · 공백 · `. _ - /`) 밖의 이름을 후보로
  내지 않는다. 직접 넘긴 경로의 REJECT 는 셸이 리터럴을 읽은 뒤의 판정이라 셸을 지키지 못한다 — 셸에 붙이기 전의 글자 확인은
  SKILL 3.6 이 한다.
  새로 시작이면 topic 을 `<seed 주제>-brief-<HHMM>` 으로 바꿔 위 펜스로 새 경로를 낸다. 기존 파일은 지우지 않는다.
- 이어 갈 때 「풀린 입력」은 그 파일의 `## 풀린 입력` 블록 펜스 안의 글이다 — 상태 파일 전문이 아니다. 그 블록이 없으면(옛 자리에서
  옮긴 파일) 옛 기록에 남은 최초 요청을 쓰고, 그것도 없으면 「풀린 입력」은 없음(`S1` 없음)이다 — 그 사실을 사용자에게 한 번 알린다.
- 이어 갈 때는 고른 파일의 절대경로가 그 컨텍스트 쌓기의 정체다. brief · audit 경로는 그 이름에서 `.state.md` 를 떼어 도출하고,
  날짜 · 주제로 다시 계산하지 않는다.

### 원자료 — 판결 뒤

framing 을 거친 컨텍스트 쌓기에서 사용자의 말은 seed 가 아니라 framing 기록 파일의 원자료다 — `## 1. 원문` 절에서 `### ` 로 시작하는 구분 줄을 뺀 전부 · `## 2. 질문 전체` 절의 «당신이 답한 것» 줄과 «사용자가 적은 말» 칸 · `## 6. 리뷰 결정` 절의 사용자 문구. 리뷰 결정 문구는 그렇게 정했다는 사실과 뜻까지만 읽는다 — 낱말을 사용자의 글자로 인용하지 않는다. seed 는 모델이 줄인 글이다. 위 판결을 처리한 뒤 컨텍스트 쌓기에 들어가기 전에 원자료를 찾아 읽는다 — 경로 글자를 직접 짓지 않는다.

| 자리 | 동작 |
|---|---|
| `NEW-SEED` 또는 `ASK` 의 「새로 시작」 — 상태 파일을 만든 직후 | 펜스를 `SEED_ABS` · `STATE` 둘 다 채워 돌린다 |
| `RESUME`(`LEGACY` 를 옮긴 뒤 포함) | 펜스를 `STATE` 를 채워 돌린다 — 이어 가는 세션은 앞 세션이 읽은 글을 갖고 있지 않다. 진입 인자가 seed 경로였으면(`ASK` 의 「이어 감」 등) `SEED_ABS` 도 채운다 — 진입 단계 2 의 「seed 원문 대조」 줄이 그 판결에서 나온다 |
| `NEW` 인데 seed 를 경로로 받았다(진입 판정이 seed 로 여는 컨텍스트 쌓기가 아니라고 냈다) | 펜스를 `SEED_ABS` 만 채워 돌리고(분류기용), `[spec-distill] 원자료: 찾지 못함 — seed 경로가 상태 파일에 기록되지 않는다` 를 낸다 |
| `NEW` 인데 seed 를 붙여 넣었다 | 펜스를 돌리지 않고 `[spec-distill] 원자료: 찾지 못함 — 붙여 넣은 seed` 를 낸다 |
| `NEW` 이고 seed 가 아니다 | 아무것도 하지 않는다 — 첫 입력이 곧 원자료다 |

펜스 앞에 `SEED_ABS='<진입 단계 2 에서 Read 한 seed 절대경로 — 없으면 빈 값>'` · `STATE='<상태 파일 절대경로 — 없으면 빈 값>'` 두 줄을 붙여 같은 Bash 호출로 돌린다(SKILL 3.6 의 `ARG_PATH` 와 같은 글자 확인을 거친 경로만 붙인다):

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
if [ -n "${SEED_ABS:-}" ]; then
  echo "[spec-distill] seed 옆 기록 파일(분류기용):"
  rc=0; python3 "$SD/scripts/raw_source.py" locate --seed "$SEED_ABS" || rc=$?
  if [ "${rc}" -eq 3 ]; then printf '%s\n' "[spec-distill] 판결 종료 코드 3 — 위 판결 줄로 「seed 원문 대조」 줄을 낸다(멈추지 않는다)" >&2
  elif [ "${rc}" -ne 0 ]; then printf '%s\n' "[spec-distill] 판결 종료 코드 ${rc} — 판결 줄이 없다. 「seed 원문 대조」 줄은 audit=없음(<위 [raw_source] 줄 — 없으면 오류 출력의 마지막 줄>) 로 낸다" >&2; fi
fi
if [ -n "${STATE:-}" ]; then
  [ -f "$STATE" ] || { echo "[spec-distill] 상태 파일이 없다(${STATE}) — 원자료 판결은 상태 파일이 생긴 뒤에 받는다. 상태 파일을 만든 뒤 다시 돌린다" >&2; exit 1; }
  echo "[spec-distill] 이 컨텍스트 쌓기의 원자료:"
  rc=0; python3 "$SD/scripts/raw_source.py" locate --interview "$STATE" --absolute || rc=$?
  if [ "${rc}" -eq 3 ]; then printf '%s\n' "[spec-distill] 판결 종료 코드 3 — 위 판결 줄대로 간다(멈추지 않는다)" >&2
  elif [ "${rc}" -ne 0 ]; then printf '%s\n' "[spec-distill] 판결 종료 코드 ${rc} — 판결 줄이 없다. 아래 「판결 줄이 없다」 갈래대로 간다" >&2; fi
fi
```

- 「seed 옆 기록 파일(분류기용)」 아래의 판결 줄이 SKILL 진입 단계 2 의 `[spec-distill] seed 원문 대조: seed=… · audit=…` 줄을 채운다 — `raw-source: FOUND <경로>` 면 그 경로, 아니면 `audit=없음(<사유>)`. seed 문장의 출처 분류는 아래의 원자료 판결과 무관하게 이 줄로 한다.
- 「이 컨텍스트 쌓기의 원자료」 아래의 판결 줄마다:
  - `raw-source: FOUND <절대경로>` — 그 파일의 세 절(`## 1. 원문` · `## 2. 질문 전체` · `## 6. 리뷰 결정`)을 Read 로 읽고 `[spec-distill] 원자료: 읽음 — <절대경로>` 를 낸다.
  - `raw-source: LOST <사유>` — `[spec-distill] 원자료: 찾지 못함 — <사유>` 를 낸다.
  - `raw-source: NO-FRAMING` — `[spec-distill] 원자료: 없음 — framing 없는 컨텍스트 쌓기` 를 낸다.
  - 판결 줄이 없다 — 펜스 출력을 그대로 보이고 `[spec-distill] 원자료: 찾지 못함 — 판결 줄이 없다(종료 코드 <n>: <[raw_source] 줄 — 없으면 오류 출력의 마지막 줄>)` 를 낸다. 컨텍스트 쌓기는 seed 로 간다 — 끝맺음은 같은 판결 없이는 멈추므로(`finishing.md` Step A 3) 그 사유를 첫 라운드에 함께 밝힌다.
- 원자료를 찾지 못한 컨텍스트 쌓기는 막지 않고 지금처럼 간다. 첫 라운드의 «지금 이해» 에 `원자료를 찾지 못했다(<사유>) — seed 만 읽는다` 한 줄을 밝힌다. 끝맺음의 첫 칸과 결과물 리뷰는 같은 판결을 상태 파일에서 다시 받는다(`finishing.md` Step A 3).

### 옛 자리의 진행 기록

`context-state: LEGACY <옛 경로>` 면 그 파일(이전 버전이 쓰던 `.claude/spec-distill/<session-id>/state.local.md`)을 읽어
주제를 정하고(기록에서 정하지 못하면 사용자에게 한 번 묻는다) 옮긴다. 출력 줄을 그대로 보인다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sid="$(python3 "$SD/scripts/state_path.py" session-id || true)"
python3 "$SD/scripts/interview_state.py" migrate-legacy --session "$sid" --topic "<kebab 주제>" --seed "<seed 절대경로 — 없으면 이 인자를 뺀다>"
```

rc 0 이면 옮긴 경로로 RESUME 과 같다. 0 이 아니면 그 사유를 보이고 멈춘다.

### 상태 파일 본문의 절

본문의 절은 아래가 전부다 — 절마다 누가 쓰고 어디로 옮겨 가는지를 적는다.

- `## 풀린 입력` — 진입 단계 2 의 결과(위 「처음 만들 때」). framing 없이 시작한 컨텍스트 쌓기면 Step A 가 결과물 §6 의 `S1` 로 쓴다. seed 로 시작한 컨텍스트 쌓기의 `S1` 은 이 블록이 아니라 원자료다(`finishing.md` Step A 3).
- `## R<n>` — 라운드 기록(SKILL 의 라운드 규약 절). 대체됨 · 확인 줄은 Step A 4 가 audit §5 로 옮긴다.
- `## audit §2 대기 줄` — 상한 도달 · 포화 판정 · 사용자 종료 · 건너뜀 줄. Step A 4 가 audit §2 로 옮긴다.
- `## 반대 논거 기록 대기` — 반대 논거를 세운 기록의 재료(넘긴 입력 · 확인한 것 · 사용자 선택)를 `#### ST<N> — <요지>` 블록으로(`steelman.md` Step 4). Step A 4 가 audit §3 으로 옮긴다.
- `## 위험 줄 대기` — 맹점 조사가 낸 위험 줄(번호 없이 — SKILL 의 blind-spot-prober dispatch 절). Step A 4 가 결과물 §5 로 옮기며 번호를 박는다.
- `## 분해안` — 로드맵 잡기만 쓴다(승인된 표 · 고친 횟수 · 승인 줄).
- `## 생성 기록` — 생성기(`roadmap_write.py`)가 쓴다.

### 끝낼 때

brief · audit · 상태 파일 셋은 `finishing.md` B-3 의 커밋 펜스가 한 번에 커밋한다(①/② 와 B-1 끝 질문의 「확정하고 끝낸다」 는 확정 반영 · 게이트 재실행 통과 뒤,
④ 와 B-1 의 「brief만 종료」 는 종료 안내 직전). 원자료를 찾은 컨텍스트 쌓기면 framing 기록 · seed 도 커밋되지 않은 변경이 있을 때 같은 커밋에 든다(F3 결정 B9). 로드맵 폴더는 들지 않는다 — 로드맵 잡기가 만들어 커밋한다. 상태 파일은 지우지 않는다.
