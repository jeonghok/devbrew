# 링크 로더 측정 — `agents/` · `references/` 파일 단위 심볼릭 링크

설계 `2026-09-06-document-review-redesign-design.md` §13 항목 0. 측정일: 2026-09-06, CLI: `claude --version` → `2.1.263 (Claude Code)`.

| 모드 | `references/` 링크가 `Read` 로 읽힘 | `agents/` 링크의 agent 가 dispatch 됨 | 근거 파일 |
|---|---|---|---|
| A `--plugin-dir` (링크가 링크로 남음) | **yes** | **no** | `modeA.jsonl` grep 3/3 — 단 `agents/` 쪽 3건은 dispatch 성공이 아니라, `Agent(subagent_type: "linkprobe:probe-agent")` 가 `"Agent type 'linkprobe:probe-agent' not found"` 로 실패한 뒤 모델이 원본 파일을 `Read` 로 직접 읽어 우회한 결과다. 세션 시작 `init` 이벤트의 `agents` 배열에도 애초 `linkprobe:probe-agent` 가 없었다. `references/`는 `Read({file_path: ".../references/probe-ref.md"})` 가 실제로 성공해 진짜 yes. 대조군(같은 트리에 심볼릭 링크가 아닌 일반 agent 파일 `probe-agent-direct.md` 추가, 별도 토큰)은 동일 `--plugin-dir` 세션에서 정상 dispatch 됨(`subagent_stats.spawned=1`) — `--plugin-dir` 자체의 한계가 아니라 심볼릭 링크가 원인임을 확인. |
| B 격리 `claude plugin install` (설치 시 역참조) | **측정 불가**(인증 차단) — 구조 증거는 yes 방향 | **측정 불가**(인증 차단) — 구조 증거는 no 방향 | 캐시 심볼릭 링크 수 0, 두 파일 모두 캐시에 일반 파일로 존재하고 원본과 바이트 완전 동일(`diff` 무출력). 헤드리스 `claude -p` 실행은 `CLAUDE_CONFIG_DIR` 완전 격리로 로그인 상태(OAuth/keychain)까지 격리되어 `"Not logged in · Please run /login"`(`error:"authentication_failed"`)로 rc=1 즉시 실패 — grep 0/0 은 "커맨드 미실행"이지 "no"가 아니다. `ANTHROPIC_API_KEY` 미설정, 사용자 실제 자격증명을 격리 디렉토리로 복사하는 우회는 안전상 시도하지 않았다. 다만 인증 실패 이전에 완성되는 `init` 이벤트의 `agents` 배열은 Mode A 와 동일 패턴(`probe-agent` 없음, `probe-agent-direct` 있음)을 재현했다 — 확정은 아니지만 방증. |

**결론:** 디렉토리별로 갈린다. **`agents/` 는 확정 `no`**(Mode A 실측 dispatch 실패 + 대조군으로 confound 배제 완료, Mode B 국지 스캔에서도 동일 패턴 재현) → PR 2 이후 `agents/` 는 `copy-of:` 사본(바이트 동일 + 첫 줄 마커)으로 배포하고 설계 §5.1·AC14 를 그에 맞게 고친다(아키텍처 불변, 배포 방식만). **`references/` 는 Mode A 확정 `yes`, Mode B 라이브 실행은 인증 차단으로 미결** — 구조 증거(캐시 심볼릭 링크 0개 + 바이트 완전 동일 + 파일 read 에는 agent 같은 별도 레지스트리 스캔이 없다는 사실)는 정상 동작 쪽을 강하게 시사하나 확정은 아니다. 확정을 원하면 인증 가능한 격리 환경(별도 `ANTHROPIC_API_KEY` 또는 사람이 직접 `claude setup-token`으로 격리 디렉토리에 1회 로그인)에서 Step 3 헤드리스 부분만 재실행할 것을 후속 항목으로 남긴다. 그 전까지 설계 문서는 `references/`를 심볼릭 링크로 잠정 채택하거나, 보수적으로 `agents/`와 함께 `copy-of:`로 통일하는 두 선택지 중 설계자가 고른다.

재현: `docs/superpowers/plans/2026-09-06-document-review-engine.md` 의 「Task 1: 링크 로더 측정」 Step 1~3. 프로브 자체는 리포에 남기지 않는다(job tmp: `$CLAUDE_JOB_DIR/tmp/linkprobe`).
