---
type: research
epic: P1
source_interview: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/P1.md
roadmap: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md
docs_checked_at: 2026-11-15
measured_at: 아직 재지 않음
claude_code: 2.1.325
---

# P1 — 공식 장치 실측

공식 장치(데이터 폴더 · 설정 값 받기 · 플러그인 끄기)가 devbrew 가 쓰는 방식 — skill 이 Bash 로 부르는 스크립트 — 에서 실제로 되는지 잰 기록이다. 지금은 뼈대다: 재는 도구와 문서 확인까지 들어 있고, 실측 표의 「되는가」 칸은 도구를 돌린 뒤에 채운다.

## 목차

- [무엇을 왜 재는가](#무엇을-왜-재는가)
- [실측 표](#실측-표)
  - [항목 1 데이터 폴더 쓰기와 샌드박스](#항목-1-데이터-폴더-쓰기와-샌드박스)
  - [항목 2 작업 폴더 밖 읽기와 쓰기 그리고 하위 agent](#항목-2-작업-폴더-밖-읽기와-쓰기-그리고-하위-agent)
  - [항목 3 변수 치환과 환경변수](#항목-3-변수-치환과-환경변수)
  - [항목 4 플러그인 끄기](#항목-4-플러그인-끄기)
- [문서에서 확인한 것](#문서에서-확인한-것)
  - [장치마다 필요한 판](#장치마다-필요한-판)
  - [문서가 적는 것](#문서가-적는-것)
  - [받은 자료](#받은-자료)
- [재는 방법](#재는-방법)
  - [돌리는 명령](#돌리는-명령)
  - [기계에 생기는 것과 바뀌는 것](#기계에-생기는-것과-바뀌는-것)
  - [실행 목록](#실행-목록)
  - [판정 규칙](#판정-규칙)
  - [선택 단계 설치본 끄기](#선택-단계-설치본-끄기)
  - [되돌리기](#되돌리기)
  - [도구 전문](#도구-전문)
- [옛 기록과 달라진 것](#옛-기록과-달라진-것)
- [재지 못하는 것](#재지-못하는-것)
- [있는 것 검토](#있는-것-검토)
- [번호 대조](#번호-대조)

## 무엇을 왜 재는가

받는 곳은 에픽 F7(스위치와 상태 자리 이전)의 설계다. F7 은 환경변수 kill switch 와 프로젝트 안 상태 폴더를 공식 장치로 옮긴다(D21). 그 방향은 유지하되 옮기기 전에 재고, 막히면 대체 길을 다시 묻기로 했다(D31 · D35). 이 문서가 넘기는 것은 「실측 표 — 장치마다 되는가 · 조건 · 필요한 판」 이다.

재는 까닭은 숨은 가정 둘이다.

- K10 — skill 이 Bash 로 부르는 스크립트가 공식 데이터 폴더에 쓸 수 있다. 샌드박스를 켠 세션에서는 잰 적이 없다.
- K11 — 공식 설정 값 받기(userConfig)가 스크립트까지 닿는다. 문서가 적는 길은 skill 본문 치환과 훅 프로세스뿐이다.

재는 것은 로드맵 `### P1` 블록의 범위 다섯이다.

1. 샌드박스를 켠 세션에서, skill 이 Bash 로 부르는 스크립트가 데이터 폴더(`CLAUDE_PLUGIN_DATA`)에 쓸 수 있는가. 쓰기 허용 설정을 더하면 달라지는가.
2. 작업 폴더 밖 읽기 · 쓰기가 권한 모드마다 어떻게 승인되는가. 하위 agent 가 그 자리를 읽을 수 있는가.
3. 변수 치환이 어디까지 닿는가 — skill 본문의 펜스, 사전 실행 줄(`!` 로 도는 줄), Read 로 여는 보조 파일. 대상은 플러그인 루트 · 데이터 폴더 · 설정 값이다. 설정 값이 Bash 로 도는 스크립트에 환경변수로 닿는가.
4. 플러그인을 끈 뒤 진입 skill 과 훅이 어떻게 되는가. 언제 반영되는가(도는 세션 · 새 세션).
5. 장치마다 필요한 Claude Code 판.

하지 않는 것은 스위치 · 상태를 실제로 옮기는 일이다(F7). 열린 질문 OQ32 · OQ37 · OQ38 은 F7 이 정하고, 이 문서는 그 판단에 쓸 사실만 낸다.

지금 상태: 항목 5 와 문서가 적는 것은 «문서에서 확인한 것» 에 있다. 항목 1–4 의 「되는가」 는 전부 「아직 재지 않음」 이다 — «재는 방법» 의 도구를 사용자가 돌리면 그 결과로 채운다.

## 실측 표

칸의 뜻: 「되는가」 는 실측 결과다(지금은 전부 「아직 재지 않음」). 「조건」 은 그 행을 재는 실행의 이름이다(«실행 목록»). 「필요한 판」 은 문서 · changelog 에서 확인한 값이고 실측이 아니다. 「근거」 의 «문서 N» 은 «문서가 적는 것» 의 행 번호다.

### 항목 1 데이터 폴더 쓰기와 샌드박스

| # | 장치 · 물음 | 되는가 | 조건 | 필요한 판 | 근거 |
|---|---|---|---|---|---|
| 1-1 | Bash 로 도는 스크립트가 데이터 폴더에 쓴다 — 샌드박스를 끈 세션 | 아직 재지 않음 | `s1-fence` | 2.1.78 | 옛 기록은 「됐다」(«옛 기록과 달라진 것» 5) |
| 1-2 | 같은 쓰기 — 샌드박스를 켠 세션 | 아직 재지 않음 | `s2-fence-sbx` | 샌드박스 2.0.24 | «문서 5» — 데이터 폴더가 보호 경로에 드는지는 문서에 없다 |
| 1-3 | 같은 쓰기 — `sandbox.filesystem.allowWrite` 에 데이터 폴더의 윗 폴더를 더한 세션 | 아직 재지 않음 | `s3-fence-sbx-allow` | 2.1.78 | «문서 5» — 보호 경로면 풀리지 않는다고 적는다 |
| 1-4 | 같은 쓰기 — `--add-dir` 로 데이터 폴더를 더한 세션 | 아직 재지 않음 | `s4-fence-sbx-adddir` | — | «문서 5» |
| 1-5 | 훅 프로세스가 데이터 폴더에 쓴다 — 샌드박스를 켠 세션 | 아직 재지 않음 | `s2-fence-sbx` 의 훅 | 2.1.78 | «문서 6» — 훅은 샌드박스 밖에서 돈다고 적는다 |
| 1-6 | 데이터 폴더가 언제 생기는가 | 아직 재지 않음 | `s1-fence` | 2.1.78 | «문서 1» |
| 1-7 | Write 도구로 데이터 폴더에 쓴다 — 권한 모드마다 | 아직 재지 않음 | `p1-manual` · `p2-acceptedits` · `p3-auto` · `p4-dontask` | — | «문서 9» — `.claude` 는 보호 경로다 |
| 1-8 | 사전 실행 줄로 도는 스크립트의 같은 쓰기 — 샌드박스를 켠 세션 | 아직 재지 않음 | `s6-inject-sbx` | — | «문서 14» |

### 항목 2 작업 폴더 밖 읽기와 쓰기 그리고 하위 agent

| # | 장치 · 물음 | 되는가 | 조건 | 필요한 판 | 근거 |
|---|---|---|---|---|---|
| 2-1 | Read 도구로 작업 폴더 밖 파일을 읽는다 — 권한 모드마다 | 아직 재지 않음 | `p1-manual` · `p2-acceptedits` · `p3-auto` · `p4-dontask` | — | «문서 9» |
| 2-2 | Write 도구로 작업 폴더 밖에 쓴다 — 권한 모드마다 | 아직 재지 않음 | 같은 실행 | — | «문서 9» |
| 2-3 | Bash `cat` 으로 작업 폴더 밖 파일을 읽는다 | 아직 재지 않음 | 같은 실행 | — | «문서 9» |
| 2-4 | Bash 리다이렉트로 작업 폴더 밖에 쓴다 | 아직 재지 않음 | 같은 실행 | — | «문서 9» |
| 2-5 | Bash 로 도는 스크립트가 안에서 밖에 쓴다(권한 판정이 보지 못하는 쓰기) | 아직 재지 않음 | `s1-fence` · `p1-manual` · `p2-acceptedits` · `p3-auto` · `p4-dontask` | — | «문서 9» |
| 2-6 | 같은 걸음들 — manual 모드에 샌드박스를 켠 세션 | 아직 재지 않음 | `p5-manual-sbx` | 2.1.325 | «문서 8» |
| 2-7 | 플러그인 폴더 안 보조 파일을 Read 로 연다(작업 폴더 밖) — 권한 모드마다 | 아직 재지 않음 | `p1`–`p4` 의 아홉째 걸음 | — | «문서 9» |
| 2-8 | 하위 agent 가 작업 폴더 밖 파일과 데이터 폴더 파일을 읽는다(Read · Bash) | 아직 재지 않음 | `a1-agent-manual` · `a2-agent-auto` · `a3-agent-sbx` | — | «문서 15» |

### 항목 3 변수 치환과 환경변수

| # | 장치 · 물음 | 되는가 | 조건 | 필요한 판 | 근거 |
|---|---|---|---|---|---|
| 3-1 | 플러그인 루트(`${CLAUDE_PLUGIN_ROOT}`) 치환 — skill 본문 펜스 | 아직 재지 않음 | `s1-fence` | — | «문서 3» |
| 3-2 | 데이터 폴더(`${CLAUDE_PLUGIN_DATA}`) 치환 — skill 본문 펜스 | 아직 재지 않음 | `s1-fence` | 2.1.78 | «문서 3» |
| 3-3 | 설정 값(`${user_config.KEY}`) 치환 — skill 본문 펜스 | 아직 재지 않음 | `s1-fence` | 2.1.83 | «문서 4» |
| 3-4 | 세 변수 치환 — 사전 실행 줄 | 아직 재지 않음 | `s5-inject` | — | «문서 14» |
| 3-5 | 세 변수 치환 — Read 로 여는 보조 파일 | 아직 재지 않음 | `s1-fence` | — | 문서에 문장이 없다. 레포는 「치환되지 않는다」 를 전제로 쓴다(«있는 것 검토») |
| 3-6 | 세 변수 치환 — agent 본문 | 아직 재지 않음 | `a1-agent-manual` · `a2-agent-auto` · `a3-agent-sbx` | 2.1.83 | «문서 2» · «문서 4» |
| 3-7 | 설정 값의 출처 — `--settings` 로 준 `pluginConfigs` 와 manifest 기본값 | 아직 재지 않음 | `s1-fence`(실행 옵션 값) · `s2-fence-sbx`(기본값) | 2.1.207 | «문서 4» |
| 3-8 | 세 값이 환경변수로 Bash 로 도는 스크립트에 닿는가(K11) | 아직 재지 않음 | `s1-fence` · `s5-inject` · `a3-agent-sbx` | — | «문서 2» — 닿지 않는다고 적는다 |
| 3-9 | 세 값이 환경변수로 훅 프로세스에 닿는가 | 아직 재지 않음 | `s1-fence` 의 훅 | 2.1.83 | «문서 4» — 닿는다고 적는다 |

### 항목 4 플러그인 끄기

| # | 장치 · 물음 | 되는가 | 조건 | 필요한 판 | 근거 |
|---|---|---|---|---|---|
| 4-1 | 끈 플러그인의 진입 skill 과 훅 — 새 세션, 한 번 실행에만 끔(`--settings` 의 `enabledPlugins`) | 아직 재지 않음 | `d0-on`(대조) · `d1-off-flag` | 2.0.12 | «문서 11» |
| 4-2 | 같은 것 — 새 세션, local 설정 파일의 `enabledPlugins` 로 끔 | 아직 재지 않음 | `d2-off-local` | 2.0.12 | «문서 11» |
| 4-3 | 도는 세션에서 끈다 — 다시 불러오기 전 | 아직 재지 않음 | `d4-off-midsession` 둘째 차례 | — | «문서 12» — 닿지 않는다고 적는다 |
| 4-4 | 도는 세션에서 끈다 — `/reload-plugins` 뒤 | 아직 재지 않음 | `d4-off-midsession` 셋째 · 넷째 차례 | 2.1.69 · 화면 없는 세션은 2.1.260 | «문서 12» |
| 4-5 | 훅 전부 끄기 — 한 번 실행에만(`--settings` 의 `disableAllHooks`) | 아직 재지 않음 | `d3-hooks-off` | 1.0.68 | «문서 13» |
| 4-6 | 설치본을 `claude plugin disable --scope local` 로 끈다 — 새 세션 · 도는 세션 | 아직 재지 않음 | 선택 단계 `--installed` | 2.0.12 | «문서 11» · «문서 12» |

## 문서에서 확인한 것

확인 날짜는 2026-11-15, 그때 깔린 판은 2.1.325 다. 1차 자료(공식 문서 · changelog)만 썼다. 인용은 원문 그대로다.

### 장치마다 필요한 판

「근거의 종류」 가 「문서」 면 문서가 「Requires …」 로 적은 값이고, 「changelog 첫 언급」 이면 changelog 에서 그 이름이 가장 먼저 나온 판이다 — 도입 판일 수도, 그보다 뒤의 수정일 수도 있다. changelog 는 0.2.21 까지 거슬러 올라간다.

| 장치 | 판 | 근거의 종류 | 원문 |
|---|---|---|---|
| 데이터 폴더 `${CLAUDE_PLUGIN_DATA}` | 2.1.78 (2026-03-17) | changelog 첫 언급 | 「Added `${CLAUDE_PLUGIN_DATA}` variable for plugin persistent state that survives plugin updates; `/plugin uninstall` prompts before deleting it」 |
| 설정 값 받기 `userConfig` | 2.1.83 (2026-03-25) | changelog 첫 언급 | 「Plugin options (`manifest.userConfig`) now available externally — plugins can prompt for configuration at enable time, with `sensitive: true` values stored in keychain (macOS) or protected credentials file (other platforms)」 |
| `pluginConfigs` 를 읽는 자리 | 2.1.207 (2026-07-11) | changelog | 「Plugin option values (`pluginConfigs`) are no longer read from project-level `.claude/settings.json`; only user, `--settings`, and managed settings are honored」 |
| `userConfig` 의 `options`(고르는 값) | 2.1.271 | 문서 | 「If you declare `options` on any field, users on Claude Code versions before v2.1.271 can't load the plugin.」 |
| `claude plugin configure` | 2.1.285 | 문서 | 「Requires Claude Code v2.1.285 or later.」 |
| 샌드박스(Bash) | 2.0.24 (2025-10-20) | changelog 첫 언급 | 「Sandbox: Releasing a sandbox mode for the BashTool on Linux & Mac」 |
| `sandbox.allowUnsandboxedCommands` | 2.0.30 (2025-10-30) | changelog 첫 언급 | 「Added `allowUnsandboxedCommands` sandbox setting to disable the dangerouslyDisableSandbox escape hatch at policy level」 |
| `sandbox.filesystem.allowWrite` 절대 경로 | 2.1.78 (2026-03-17) | changelog 첫 언급(수정) | 「Fixed `sandbox.filesystem.allowWrite` not working with absolute paths (previously required `//` prefix)」 |
| 샌드박스 안 명령의 자동 허용 기본값이 꺼짐 | 2.1.324 또는 2.1.325 | 문서와 changelog 가 어긋남 | 문서: 「Default: `false`. Before v2.1.324, the default was `true`」 · changelog 2.1.325: 「Changed sandboxed Bash commands to follow the normal permission flow by default; set `sandbox.autoAllowBashIfSandboxed: true` to keep running them without prompts」 |
| 한 번 실행에만 거는 설정 `--settings` | 1.0.61 (2025-07-25) | changelog 첫 언급 | 「Settings: Added `--settings` flag to load settings from a JSON file」 |
| 플러그인 켜기 · 끄기 | 2.0.12 (2025-10-09) | changelog 첫 언급 | 「`/plugin install`, `/plugin enable/disable`, `/plugin marketplace` commands for plugin management」 |
| `claude plugin enable` · `disable` 의 범위 자동 찾기 | 2.1.49 (2026-02-19) | changelog(수정) | 「Fixed `plugin enable` and `plugin disable` to auto-detect the correct scope when `--scope` is not specified, instead of always defaulting to user scope」 |
| `/reload-plugins` | 2.1.69 (2026-03-05) | changelog 첫 언급 | 「Added `/reload-plugins` command to activate pending plugin changes without restarting」 |
| 화면 없는 세션의 `/reload-plugins` | 2.1.260 | 문서 | 「`/reload-plugins` also runs in sessions without an interactive terminal, such as the desktop app, the Agent SDK, and non-interactive mode with `-p`. Requires Claude Code v2.1.260 or later.」 |
| `--plugin-dir` | 2.1.74 (2026-03-12) 이전 | changelog 첫 언급(동작 변경) — 도입 판은 찾지 못함 | 「Changed `--plugin-dir` so local dev copies now override installed marketplace plugins with the same name (unless that plugin is force-enabled by managed settings)」 |
| 훅 전부 끄기 `disableAllHooks` | 1.0.68 (2025-08-04) | changelog 첫 언급 | 「Added `disableAllHooks` setting」 |
| `${CLAUDE_SKILL_DIR}` | 2.1.69 (2026-03-05) | changelog 첫 언급 | 「Added `${CLAUDE_SKILL_DIR}` variable for skills to reference their own directory in SKILL.md content」 |
| skill `allowed-tools` 안의 `${CLAUDE_PLUGIN_ROOT}` 치환 | 2.1.0 (2026-01-07) | changelog(수정) | 「Fixed `${CLAUDE_PLUGIN_ROOT}` not being substituted in plugin `allowed-tools` frontmatter, which caused tools to incorrectly require approval」 |
| 작업 폴더 밖 쓰기 막기 `permissions.blockWritesOutsideWorkingDirectories` | 2.1.314 | 문서 | 「Requires Claude Code v2.1.314 or later.」 |
| 화면 없는 실행의 기본 권한 모드가 manual | 2.1.302 | 문서 | 「In Claude Code v2.1.302 or later, `claude -p` and Agent SDK runs with no permission mode set start in Manual mode.」 |
| `--permission-prompts none` | 2.1.259 | 문서 | 「The `--permission-prompts` flag requires Claude Code v2.1.259 or later. Earlier versions reject it with an unknown-option error.」 |

레포가 개발 · 검증 때 쓴 판으로 적어 둔 값은 2.1.303 이다(RC273). 위 표에서 그보다 높은 것은 둘이다 — 작업 폴더 밖 쓰기 막기(2.1.314)와 샌드박스 자동 허용 기본값 변경(2.1.324 또는 2.1.325). 앞의 것은 F7 이 쓰려는 장치가 아니고, 뒤의 것은 같은 설정이 판에 따라 다르게 도는 자리다. 최소 판을 강제할지는 F7 이 정한다(OQ38).

### 문서가 적는 것

| # | 무엇 | 문서가 적는 것(원문) | 문서가 적지 않는 것 |
|---|---|---|---|
| 문서 1 | 데이터 폴더의 자리 · 생기는 때 | 「`~/.claude/plugins/data/<id>/`, created on first reference and kept across plugin updates. `<id>` is the plugin identifier with every character other than a letter, digit, `_`, or `-` replaced by `-`」 (manifest-reference) | 「first reference」 가 치환인지 쓰기인지 |
| 문서 2 | Bash 도구의 환경 | 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent. In skill, command, and agent content, write the `${...}` reference in the Markdown body instead, and Claude Code substitutes the path inline when it loads the content.」 (manifest-reference) | — |
| 문서 3 | skill 에서 치환되는 자리 | 「Claude Code substitutes `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` in two places: the skill's markdown content, and Bash rules in the `allowed-tools` frontmatter. In a plugin skill, Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` in the same two places.」 (skills) | Read 로 여는 보조 파일이 치환되는지 |
| 문서 4 | 설정 값이 닿는 길 | 「`${user_config.KEY}`: substituted in MCP server config, LSP server config, exec-form hook `args`, and skill and agent content. In skill and agent content, only non-sensitive values are substituted, and a sensitive value there becomes a placeholder」 · 「`CLAUDE_PLUGIN_OPTION_<KEY>`: exported to hook processes for every option, with `<KEY>` uppercased.」 (manifest-reference) · 「Claude Code ignores project and local entries because it substitutes these values into plugin hook, MCP, and LSP configurations, and a cloned repository must not be able to supply them.」 (settings-reference `pluginConfigs`) | Bash 로 도는 스크립트에 환경변수로 싣는 길(같은 페이지의 표는 skill · command · agent 본문 행의 「Exported to the process」 칸을 「Not applicable」 로 적는다) |
| 문서 5 | 샌드박스의 쓰기 자리 · 보호 경로 | 표의 「Writes」 행: 「The working directory, a per-user temp directory, and directories you've added. Protected paths stay write-denied」 · 「In `~/.claude`, or the directory `CLAUDE_CONFIG_DIR` points to: most of its contents, plus `~/.claude.json` and the `.credentials.json` credential store」 · 「If you add an `allowWrite` entry or an `Edit` allow rule that covers one of these paths, the protection still applies.」 (sandboxing) | `~/.claude/plugins/data` 가 「most of its contents」 에 드는지 |
| 문서 6 | 샌드박스 밖에서 도는 것 | 「The sandbox covers shell commands only. Claude's file tools, MCP servers, and hooks run outside it.」 · 「command hooks, local MCP servers, plugin monitors, LSP servers, and helper commands such as your status line command and `apiKeyHelper` run with your full access」 (sandboxing) | — |
| 문서 7 | 한 번 실행에만 거는 설정 | 「To change the sandbox for one session without writing to a settings file, start Claude Code with `--settings`.」 · 「`--settings` lasts one session and doesn't write to any file.」 (sandboxing · settings) | — |
| 문서 8 | 샌드박스 안 명령의 승인 | 「`false`: sandboxed commands go through the regular permission flow, so your allow rules and permission mode decide.」 · 「Default: `false`. Before v2.1.324, the default was `true`」 (settings-reference) | — |
| 문서 9 | 권한 판정이 보는 것 | 읽기: 「No, within the working directory and additional directories」 (permissions 표의 「Approval required」 칸) · 보호 경로 쓰기 표: `default` · `acceptEdits` 는 「Prompted」, `auto` 는 「Routed to the classifier, which decides」, `dontAsk` 는 「Denied」, `bypassPermissions` 는 「Allowed」 · 보호 폴더 목록에 「`.claude`, with a few exceptions」 와 「A directory you loaded with `--plugin-dir`」 (permission-modes) · 「They don't apply to a command that reads files without naming them, such as `grep -r pattern .` run from the directory that holds the file, or to arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself.」 (permissions) | 데이터 폴더가 `.claude` 보호의 예외인지(예외 목록에 없다) |
| 문서 10 | 화면 없는 실행의 권한 | 「Calls needing approval are denied unless you approve them with an allow rule, hook, `canUseTool` callback, or `--permission-prompt-tool`.」 (permission-modes) · 「With `--output-format stream-json`, denials appear as `permission_denied` system messages, and the final result message lists them in `permission_denials`.」 (headless) | — |
| 문서 11 | 플러그인 끄기 | `enabledPlugins` 를 둘 수 있는 자리 여섯 가운데 `flag` 행: 「The `--settings` value you pass at launch」 · 「This session only」 · `--plugin-dir` 로 실은 것은 「On for the session unless the manifest sets `defaultEnabled: false` or a settings file sets `"<name>@inline": false`」 (loading) · 「`claude plugin disable formatter --scope local` turns off a project-enabled plugin for you alone」 (cli-reference) | — |
| 문서 12 | 반영되는 때 | 「Changes to settings or to disk don't reach this layer until you run `/reload-plugins` or start a new session.」 (loading) · 「In those sessions, the command runs only when you type it into the session yourself, such as in the `-p` prompt or the desktop app's prompt box.」 (cli-reference) | 화면 없는 세션에 stream-json 입력으로 넣은 `/reload-plugins` 가 「직접 친 것」 으로 치이는지 |
| 문서 13 | 훅 끄기 | 「A plugin's hooks don't wait for one of the plugin's skills or commands to be used. Claude Code registers them when a session loads the plugin, and they fire on their events from then on.」 (components) · 「To turn hooks off for one run whatever the project's settings say, pass `--settings '{"disableAllHooks": true}'`, which takes precedence over project and local settings. There is no way to disable an individual hook while keeping it in the configuration.」 (hooks) | — |
| 문서 14 | 사전 실행 줄 | 「Either tool runs the commands the same way it runs Claude's own shell commands.」 · 「Outside auto mode, when a command's permission check returns anything other than allow, Claude Code aborts the invocation.」 · 「A failed command aborts the entire skill invocation, not just its own placeholder.」 (skills) | 사전 실행 줄이 샌드박스 안에서 도는지를 따로 적은 문장 |
| 문서 15 | 하위 agent 의 권한 | 「If you leave it unset, the subagent inherits the main conversation's permission mode.」 (sub-agents) · 플러그인 agent 에서 무시되는 칸: 「`permissionMode`, `hooks`, `mcpServers`, and `initialPrompt`」 (components) | — |
| 문서 16 | 지울 때 | 「When you uninstall a plugin from the last scope it's installed at, Claude Code also deletes the plugin's stored options and secrets and its data directory, `~/.claude/plugins/data/<id>/`.」 예외로 「With `--keep-data`, the data directory stays」 (cli-reference) | — |

### 받은 자료

각 주소에 `.md` 를 붙여 원문 markdown 으로 받았다(2026-11-15). manifest-reference 는 `plugins-reference` 로, install 은 `discover-plugins` 로 받아도 같은 글이 온다.

- https://code.claude.com/docs/en/plugins/manifest-reference
- https://code.claude.com/docs/en/plugins/components
- https://code.claude.com/docs/en/plugins/loading
- https://code.claude.com/docs/en/plugins/cli-reference
- https://code.claude.com/docs/en/plugins/install
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/sandboxing
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/settings-reference
- https://code.claude.com/docs/en/permissions
- https://code.claude.com/docs/en/permission-modes
- https://code.claude.com/docs/en/headless
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/changelog

옵션 이름은 깔린 판의 도움말로도 확인했다 — `claude --help` 에 `--plugin-dir` · `--settings` · `--permission-mode`(고를 값에 `manual` 이 있고 `default` 는 없다) · `--permission-prompts` · `--allowedTools` · `--add-dir` · `--setting-sources` · `--max-budget-usd` · `--include-hook-events` · `--forward-subagent-text` · `--no-session-persistence` · `--input-format` · `--output-format` 이 있다. `claude plugin disable --help` 는 `-s, --scope <scope>`(user · project · local, 기본은 자동 찾기)를 보인다. `claude plugin validate <폴더>` 는 시험용 플러그인에 「Validation passed」 를 냈다(아이콘이 없다는 등록용 경고 하나).

## 재는 방법

화면 없는 실행(`claude -p`)으로 잰다. 시험용 플러그인 `qzprobe`(버리는 것)를 `--plugin-dir` 로 그 실행에만 싣고, 실행마다 새 빈 폴더(git init)에서 돌린다. 판정은 실행이 남긴 파일 · 표식 글자 · 스트림 이벤트로 한다.

### 돌리는 명령

도구는 레포에 커밋하지 않는다(시험용 `plugin.json` · `SKILL.md` 가 레포 검사에 걸린다). 실물은 메인 체크아웃의 git 이 무시하는 자리에 둔다.

```
<레포 루트>/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/report/P1/kit/
```

세션 밖 터미널에서 한 줄로 돌린다.

```bash
python3 "<위 kit 폴더>/qzp_run.py"
```

시작할 때 실행 수 · 예상 비용 · 시간을 한 줄로 알리고, 끝에 결과 표 경로와 지우는 명령을 보인다. 기본 실행은 세션 19회다. 비용은 어제 실측 단가(짧은 실행 하나 약 $0.13)로 미루어 $3–6, 시간은 9–19분으로 본다 — 여러 걸음을 밟는 실행이 섞여 있어 추정이다. 합계 $8, 세션당 $1 에서 멈춘다(`--budget` 으로 바꾼다).

| 명령 | 하는 일 |
|---|---|
| `qzp_run.py --list` | 실행 목록만 보인다. 아무것도 만들지 않는다 |
| `qzp_run.py --dry-run` | 폴더와 명령 줄까지만 만든다. 세션을 띄우지 않는다 |
| `qzp_run.py --only s2-fence-sbx,s3-fence-sbx-allow` | 고른 실행만 돈다 |
| `qzp_run.py --with p9-bypass` | 기본 실행에 고른 것을 더한다 |
| `qzp_run.py --clean` | 사용자 설정을 빼고 돈다(`--setting-sources project,local`) |
| `qzp_run.py --installed` | 선택 단계만 돈다(«선택 단계 설치본 끄기») |
| `qzp_summarize.py <근거 폴더>` | 결과 표만 다시 만든다 |

이 문서만으로 도구를 다시 만들려면 «도구 전문» 의 파일을 제목에 적힌 경로대로 한 폴더 아래에 두면 된다. python 3.9 와 bash 3.2 에서 돈다. Claude Code 는 2.1.259 이상이어야 한다(`--permission-prompts`).

도구의 확인 상태: 실제 세션으로는 아직 한 번도 돌리지 않았다. 확인한 것은 넷이다 — 셸 스크립트 둘을 세션 없이 임시 폴더에서 돌려 기록 파일이 나오는 것, python 둘의 문법, `--dry-run` 으로 만든 명령 줄과 설정 파일, 어제 실측의 이벤트 꼴로 지어낸 근거에 요약 스크립트를 돌려 표가 나오는 것. 그래서 첫 실행에서 도구 쪽이 틀린 자리(예: 여러 차례를 넣는 세션, 하위 agent 의 도구 호출이 스트림에 보이는지)는 「재지 못함」 으로 나올 수 있다. 그 행은 도구를 고쳐 그 실행만 다시 돈다(`--only`).

### 기계에 생기는 것과 바뀌는 것

기본 실행이 만드는 것은 셋이다. 사용자의 설정 파일은 고치지 않는다 — 설정은 실행마다 `--settings <파일>` 로만 건다.

| 자리 | 무엇 | 누가 만드나 |
|---|---|---|
| `$HOME/.cache/qzprobe/<시각>/` | 시험용 플러그인 사본과 실행마다의 작업 폴더 · 「작업 폴더 밖」 표적 폴더 | 러너 |
| `<kit 폴더>/../results/<시각>/` | 근거(명령 · stdout · stderr · rc · 남은 파일)와 결과 표 `results.md` · `results.json` | 러너 |
| `$HOME/.claude/plugins/data/qzprobe-inline/` | 시험용 플러그인의 데이터 폴더 — 재려는 대상이라 피할 수 없다 | Claude Code(와 그 안에 쓰는 시험 스크립트) |

작업 폴더를 `$HOME/.cache` 아래에 두는 까닭은 표적이 섞이지 않게 하려는 것이다. 샌드박스는 작업 폴더와 임시 폴더를 기본으로 쓰기 허용하므로, 「작업 폴더 밖」 표적은 그 둘도 `~/.claude` 도 아닌 자리여야 한다. 러너는 작업 폴더가 임시 폴더 · `~/.claude` · git 레포 안이면 시작하지 않는다(`QZP_WORK` 로 바꿀 수 있다).

러너는 사용자 설정 파일(`~/.claude/settings.json`)을 읽기만 해서 결과에 영향을 줄 값(기본 권한 모드 · 파일과 Bash 의 허용 규칙 · 샌드박스 키)을 근거 폴더의 `env.json` 에 적는다. 설치된 플러그인과 그 훅은 평소처럼 함께 실린다 — 빼려면 `--clean`.

### 실행 목록

「허용 규칙」 은 그 실행에만 `--allowedTools` 로 준 것이다. 「샌드박스 strict」 는 `enabled` · `failIfUnavailable` · `autoAllowBashIfSandboxed` 를 켜고 `allowUnsandboxedCommands` 를 끈 설정이다 — 샌드박스 밖 재시도를 막아 판정이 갈리지 않게 한다.

| 실행 | 재는 것 | 권한 모드 | 샌드박스 | 허용 규칙 | 그 밖 |
|---|---|---|---|---|---|
| `s1-fence` | 펜스 치환 · 스크립트 환경 · 데이터 폴더 쓰기 · 보조 파일 Read | dontAsk | 끔 | `Bash(bash *)` · `Read` | `pluginConfigs` 로 설정 값을 준다 |
| `s2-fence-sbx` | 데이터 폴더 쓰기(스크립트 · 훅) | dontAsk | strict | 같음 | 훅도 데이터 폴더에 써 본다 |
| `s3-fence-sbx-allow` | 쓰기 허용 설정을 더하면 | dontAsk | strict + `allowWrite` | 같음 | `allowWrite` 에 데이터 폴더의 윗 폴더와 대조용 폴더를 넣는다 |
| `s4-fence-sbx-adddir` | 폴더를 더하면 | dontAsk | strict | 같음 | `--add-dir <데이터 폴더>` |
| `s5-inject` | 사전 실행 줄의 치환 · 환경 | dontAsk | 끔 | 같음 | `pluginConfigs` |
| `s6-inject-sbx` | 사전 실행 줄이 샌드박스 안에서 도는가 | dontAsk | strict | 같음 | |
| `p1-manual` | 밖 읽기 · 쓰기 아홉 걸음 | manual | 끔 | 없음 | |
| `p2-acceptedits` | 같음 | acceptEdits | 끔 | 없음 | |
| `p3-auto` | 같음 | auto | 끔 | 없음 | |
| `p4-dontask` | 같음 | dontAsk | 끔 | 없음 | |
| `p5-manual-sbx` | 같음 | manual | strict | 없음 | |
| `p9-bypass` | 같음(기본 실행에 없다 — `--with`) | bypassPermissions | 끔 | 없음 | |
| `a1-agent-manual` | 하위 agent 의 읽기 | manual | 끔 | 없음 | |
| `a2-agent-auto` | 같음 | auto | 끔 | 없음 | |
| `a3-agent-sbx` | 하위 agent 의 읽기 · 스크립트 | dontAsk | strict | `Bash(bash *)` · `Read` · `Agent` | |
| `d0-on` | 대조 — 끄지 않은 새 세션 | dontAsk | 끔 | 없음 | |
| `d1-off-flag` | `--settings` 의 `enabledPlugins` 로 끈 새 세션 | dontAsk | 끔 | 없음 | |
| `d2-off-local` | 작업 폴더의 `.claude/settings.local.json` 으로 끈 새 세션 | dontAsk | 끔 | 없음 | 그 파일은 버리는 작업 폴더 안에 있다 |
| `d3-hooks-off` | `--settings` 의 `disableAllHooks` | dontAsk | 끔 | 없음 | |
| `d4-off-midsession` | 도는 세션에서 끄기 → `/reload-plugins` | dontAsk | 끔 | 없음 | 한 세션에 네 차례를 stream-json 입력으로 넣는다 |

시험용 플러그인이 하는 일은 넷이다.

- 스크립트 `qzp.sh` — Bash 로 불려서, 받은 인자와 환경변수를 적고 다섯 자리(작업 폴더 · 임시 폴더 · 데이터 폴더 · 작업 폴더 밖 · `allowWrite` 대조 폴더)에 써 본다. 결과는 작업 폴더의 `qzp-out/probe-<모드>-<번호>.tsv` 에 남는다. 언제나 0 으로 끝난다.
- skill 다섯 — `qz-fence`(펜스 한 줄 + 보조 파일 Read), `qz-inject`(사전 실행 줄), `qz-outside`(밖 읽기 · 쓰기 아홉 걸음), `qz-agent`(하위 agent 하나 띄우기), `qz-ping`(표식 글자 하나만 답하기). 묻는 도구를 쓰지 않는다. 변수는 작은따옴표 안에 적어서, 치환되지 않으면 셸이 비우지 않고 글자 그대로 스크립트에 닿게 했다.
- agent `qz-reader` — Read 와 Bash 만 가진 하위 agent. 밖 파일과 데이터 폴더 파일을 읽고 한 줄로 보고한다.
- 훅 넷(SessionStart · UserPromptSubmit · PreToolUse(Bash) · Stop) — 돌 때마다 `qzp-out/hooks.tsv` 에 한 줄을 남긴다. 화면에는 아무것도 내지 않는다.

### 판정 규칙

- 판정은 rc 로 하지 않는다. 어제 실측에서 거부된 실행도 rc 0 · 성공으로 끝났다. 남은 파일 · 표식 글자 · 스트림의 도구 호출과 `permission_denied` · `permission_denials` 로 판정한다.
- 판정하지 못한 것은 「재지 못함」 으로 내고 이유를 적는다. 없는 것과 확인하지 못한 것은 다르다 — 모델이 그 걸음을 시도하지 않았으면 「거부」 가 아니라 「재지 못함」 이다.
- 양성 대조: 스크립트는 먼저 작업 폴더에 쓴다. 이 쓰기가 실패하면 그 실행의 쓰기 판정은 전부 「재지 못함」 이다.
- 음성 대조: 샌드박스를 켠 실행에서 작업 폴더 밖 쓰기는 막혀야 한다. 성공하면 샌드박스가 걸리지 않은 것이므로 데이터 폴더 판정을 「재지 못함」 으로 낸다. 설정 파일이 검증에 실패하면 화면 없는 실행은 그것을 조용히 건너뛰기 때문에 이 대조를 둔다.
- `allowWrite` 대조: `s3-fence-sbx-allow` 는 `allowWrite` 에 보호 경로가 아닌 폴더도 하나 넣는다. 그 폴더에 쓰지 못했으면 설정이 먹지 않은 것이므로 데이터 폴더 판정을 「재지 못함」 으로 낸다.
- 화면 없는 실행에서는 물을 사람이 없다. `--permission-prompts none` 을 붙였으므로 「거부」 는 「대화형이었으면 물었을 자리」 와 「모드가 거부한 자리」 를 함께 담는다. 권한 판정 칸(`decision/source/reason_type`)과 거부 메시지를 근거에 싣는다.
- 권한 모드는 실행마다 `--permission-mode` 로 밝힌다. 주지 않으면 기계의 설정에 따라 갈린다.
- 플러그인 끄기 실행의 대조는 `d0-on` 과 `d4-off-midsession` 의 첫 차례다(끄기 전에 진입 skill 이 표식 글자를 답하고 훅 줄이 남는가).
- 하위 agent 의 걸음은 스트림에 보이는 하위 도구 호출로 판정한다. 보이지 않으면 하위 agent 의 한 줄 보고를 「약한 근거」 로만 싣는다.

### 선택 단계 설치본 끄기

기본 실행은 `--plugin-dir` 로 실은 플러그인(`qzprobe@inline`)을 설정으로 끈다. 실제 명령 `claude plugin disable` 과 설치본은 사용자의 실제 플러그인 기록을 건드려야 재지므로 따로 둔다.

```bash
python3 "<위 kit 폴더>/qzp_run.py" --installed
```

하는 일은 이 순서다. 모두 버리는 작업 폴더(`$HOME/.cache/qzprobe/<시각>/installed/cwd`) 안에서 `--scope local` 로 한다.

1. 앞 상태를 적는다 — `claude plugin list --json` · `claude plugin marketplace list --json` 의 출력과 `~/.claude/settings.json` · `installed_plugins.json` · `known_marketplaces.json` 의 해시.
2. `claude plugin marketplace add <작업 폴더의 market> --scope local`
3. `claude plugin install qzprobe@qzprobe-market --scope local`
4. 새 세션 — 켠 상태.
5. `claude plugin disable qzprobe@qzprobe-market --scope local` → 새 세션.
6. `claude plugin enable qzprobe@qzprobe-market --scope local` → 한 세션 안에서: 첫 차례 → 같은 끄기 명령 → 둘째 차례 → 셋째 차례로 `/reload-plugins` → 넷째 차례.
7. `claude plugin uninstall qzprobe@qzprobe-market --scope local` · `claude plugin marketplace remove qzprobe-market` — 도중에 실패해도 이 둘은 돈다.
8. 뒤 상태를 적고 앞과 견준다(`restore-check.json`).

바뀌는 것: `enabledPlugins` 와 마켓플레이스 선언은 버리는 작업 폴더의 `.claude/settings.local.json` 에 들어간다. 사용자 폴더에서는 `~/.claude/plugins/known_marketplaces.json` · `installed_plugins.json` 에 줄이 생겼다가 7 에서 지워지고, 데이터 폴더 `~/.claude/plugins/data/qzprobe-qzprobe-market/` 가 생길 수 있다. 문서대로면 `~/.claude/settings.json` 은 바뀌지 않는다 — 8 의 해시 비교가 그것을 확인한다. 이 흐름은 아직 한 번도 돌려 보지 않았다.

이 단계가 재지 못하는 것: 로컬 폴더에서 더한 마켓플레이스의 플러그인은 캐시로 복사되지 않고 제자리에서 실린다(loading 문서). git 마켓플레이스에서 받아 캐시에 복사된 설치본과 같다고 보장하지 못한다.

격리 설정 폴더(`CLAUDE_CONFIG_DIR=<빈 폴더>`)로 돌리면 사용자의 실제 기록을 건드리지 않는다. 다만 옛 기록(2026-10-09, 판 2.1.294)은 이렇게 적는다 — 빈 격리 폴더에도 내장 마켓플레이스 하나는 보인다 · 격리 폴더에는 로그인이 없어 세션이 `Not logged in` 으로 끝난다 · `claude auth login` 은 된다. 이것은 「옛 기록 — 다시 확인 필요」 다. 지금 판에서 다시 재지 않았고 도구도 이 길을 쓰지 않는다. 격리 폴더로 재려면 그 폴더에서 다시 로그인해야 한다고 보고 시작하는 편이 안전하다.

### 되돌리기

러너는 끝에 지우는 명령을 그대로 보인다. 스스로 지우지는 않는다.

```bash
rm -rf "$HOME/.cache/qzprobe/<시각>" "$HOME/.claude/plugins/data/qzprobe-inline"
```

선택 단계가 도중에 멈췄으면 그 작업 폴더에서 아래 둘을 손으로 돌린다. 끝난 뒤 `claude plugin list` 와 `claude plugin marketplace list` 에 `qzprobe` 가 없으면 된다.

```bash
claude plugin uninstall qzprobe@qzprobe-market --scope local
claude plugin marketplace remove qzprobe-market
rm -rf "$HOME/.claude/plugins/data/qzprobe-qzprobe-market"
```

근거 폴더(`<kit 폴더>/../results/<시각>/`)는 실측 표를 채울 때 읽으므로 그때까지 둔다.

### 도구 전문

파일마다 제목이 kit 폴더 아래의 경로다. `qzp.sh` 와 `qzp-hook.sh` 는 실행 비트가 없어도 된다(`bash <파일>` 로 부른다).

#### `qzp_run.py`

````python
#!/usr/bin/env python3
"""qzp_run.py - runner for the qzprobe kit (Claude Code official-device probe).

    python3 qzp_run.py              run the default set
    python3 qzp_run.py --list       print the plan and exit (creates nothing)
    python3 qzp_run.py --dry-run    build folders and command lines, start no session
    python3 qzp_run.py --only a,b   run only these ids
    python3 qzp_run.py --with x     default set plus opt-in ids
    python3 qzp_run.py --installed  optional step only: real `claude plugin` commands
    python3 qzp_run.py --clean      leave user settings out (--setting-sources)

Every session runs in a fresh git-initialised folder under the work root, which is
outside any repository, outside ~/.claude and outside the temp folders the Bash
sandbox opens by default. Evidence (stdout, stderr, rc, files left behind) goes to
the evidence root. No settings file of the user is edited by the default set.
"""
import argparse
import hashlib
import json
import os
import platform
import queue
import shutil
import subprocess
import sys
import threading
import time

PLUGIN = "qzprobe"
INLINE_ID = PLUGIN + "@inline"
MARKET = "qzprobe-market"
MARKET_ID = PLUGIN + "@" + MARKET
CFG_FLAG = "QZP7-CFG-FLAG"
PER_RUN_USD = "1.00"
TURN_GAP_S = 4

KIT = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
DATA_PARENT = os.path.join(HOME, ".claude", "plugins", "data")
DATA_GUESS = os.path.join(DATA_PARENT, PLUGIN + "-inline")

REACH_ALLOW = ["Bash(bash *)", "Read"]
SBX = "strict"
SBX_ALLOW = "strict+allowWrite"

# id, item, kind, skill, mode, sandbox, allow, cfg, pre, default, about
PLAN = [
    ("s1-fence", 3, "probe", "qz-fence", "dontAsk", "off", REACH_ALLOW, True, [], True,
     "skill fence + support file, no sandbox"),
    ("s2-fence-sbx", 1, "probe", "qz-fence", "dontAsk", SBX, REACH_ALLOW, False,
     ["hook_data_flag"], True, "script write to data folder, sandbox on"),
    ("s3-fence-sbx-allow", 1, "probe", "qz-fence", "dontAsk", SBX_ALLOW, REACH_ALLOW,
     False, ["allowed_dir"], True, "sandbox on + filesystem.allowWrite"),
    ("s4-fence-sbx-adddir", 1, "probe", "qz-fence", "dontAsk", SBX, REACH_ALLOW, False,
     ["add_data_dir"], True, "sandbox on + --add-dir <data folder>"),
    ("s5-inject", 3, "probe", "qz-inject", "dontAsk", "off", REACH_ALLOW, True, [], True,
     "pre-executed line, no sandbox"),
    ("s6-inject-sbx", 3, "probe", "qz-inject", "dontAsk", SBX, REACH_ALLOW, False, [],
     True, "pre-executed line, sandbox on"),
    ("p1-manual", 2, "outside", "qz-outside", "manual", "off", [], True, [], True,
     "outside reads/writes, manual mode"),
    ("p2-acceptedits", 2, "outside", "qz-outside", "acceptEdits", "off", [], True, [],
     True, "outside reads/writes, acceptEdits"),
    ("p3-auto", 2, "outside", "qz-outside", "auto", "off", [], True, [], True,
     "outside reads/writes, auto mode"),
    ("p4-dontask", 2, "outside", "qz-outside", "dontAsk", "off", [], True, [], True,
     "outside reads/writes, dontAsk"),
    ("p5-manual-sbx", 2, "outside", "qz-outside", "manual", SBX, [], False, [], True,
     "outside reads/writes, manual + sandbox auto-allow"),
    ("p9-bypass", 2, "outside", "qz-outside", "bypassPermissions", "off", [], True, [],
     False, "opt-in: outside reads/writes, bypassPermissions"),
    ("a1-agent-manual", 2, "agent", "qz-agent", "manual", "off", [], True, [], True,
     "subagent reads, manual mode"),
    ("a2-agent-auto", 2, "agent", "qz-agent", "auto", "off", [], True, [], True,
     "subagent reads, auto mode"),
    ("a3-agent-sbx", 2, "agent", "qz-agent", "dontAsk", SBX, REACH_ALLOW + ["Agent"],
     False, [], True, "subagent reads + script, sandbox on"),
    ("d0-on", 4, "ping", "qz-ping", "dontAsk", "off", [], False, [], True,
     "baseline: plugin on, new session"),
    ("d1-off-flag", 4, "ping", "qz-ping", "dontAsk", "off", [], False, ["off_flag"], True,
     "plugin off by --settings enabledPlugins"),
    ("d2-off-local", 4, "ping", "qz-ping", "dontAsk", "off", [], False, ["off_local"],
     True, "plugin off by .claude/settings.local.json"),
    ("d3-hooks-off", 4, "ping", "qz-ping", "dontAsk", "off", [], False, ["hooks_off"],
     True, "hooks off by --settings disableAllHooks"),
    ("d4-off-midsession", 4, "multi", "qz-ping", "dontAsk", "off", [], False, [], True,
     "plugin turned off while the session runs, then /reload-plugins"),
]
FIELDS = ("id", "item", "kind", "skill", "mode", "sandbox", "allow", "cfg", "pre",
          "default", "about")


def say(msg):
    print(msg, flush=True)


def sh(argv, cwd=None, timeout=120):
    """Run a short command; never raises. Returns dict(argv, rc, out, err)."""
    try:
        p = subprocess.run(argv, cwd=cwd, stdin=subprocess.DEVNULL,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           timeout=timeout)
        return {"argv": argv, "rc": p.returncode,
                "out": p.stdout.decode("utf-8", "replace"),
                "err": p.stderr.decode("utf-8", "replace")}
    except subprocess.TimeoutExpired:
        return {"argv": argv, "rc": "timeout", "out": "", "err": ""}
    except OSError as exc:
        return {"argv": argv, "rc": "oserror", "out": "", "err": str(exc)}


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def write_json(path, obj):
    write_text(path, json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


def first_line(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.readline().rstrip("\n")
    except OSError as exc:
        return "<unreadable: %s>" % exc.__class__.__name__


def listing(path):
    """Names and first lines of the files directly under path."""
    out = {"path": path, "exists": os.path.isdir(path), "files": {}}
    if out["exists"]:
        try:
            for name in sorted(os.listdir(path)):
                full = os.path.join(path, name)
                out["files"][name] = first_line(full) if os.path.isfile(full) else "<dir>"
        except OSError as exc:
            out["error"] = str(exc)
    return out


def sha(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return "absent"


def user_settings_summary():
    """What in the user's own settings could change a reading (read only)."""
    path = os.path.join(HOME, ".claude", "settings.json")
    out = {"path": "~/.claude/settings.json", "readable": False}
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return out
    out["readable"] = True
    perms = data.get("permissions") or {}
    out["defaultMode"] = perms.get("defaultMode")
    for key in ("allow", "ask", "deny"):
        rules = [r for r in (perms.get(key) or []) if isinstance(r, str)]
        out[key + "_count"] = len(rules)
        out[key + "_file_or_bash"] = [
            r for r in rules if r.split("(")[0] in ("Bash", "Read", "Edit", "Write")]
    out["additionalDirectories"] = len(perms.get("additionalDirectories") or [])
    for key in ("blockReadsOutsideWorkingDirectories",
                "blockWritesOutsideWorkingDirectories", "denyInsteadOfPrompting"):
        out[key] = perms.get(key)
    out["sandbox_keys"] = sorted((data.get("sandbox") or {}).keys())
    out["disableAllHooks"] = data.get("disableAllHooks")
    out["enabledPlugins_count"] = len(data.get("enabledPlugins") or {})
    out["has_pluginConfigs"] = bool(data.get("pluginConfigs"))
    return out


def refuse_bad_work_root(work):
    real = os.path.realpath(work)
    bad = [os.path.realpath(p) for p in
           ("/tmp", "/private/tmp", "/var/folders", "/private/var/folders",
            os.path.join(HOME, ".claude"))]
    tmp_env = os.environ.get("TMPDIR")
    if tmp_env:
        bad.append(os.path.realpath(tmp_env))
    for b in bad:
        if real == b or real.startswith(b.rstrip("/") + "/"):
            sys.exit("work root %s is under %s; choose another (QZP_WORK)" % (work, b))
    probe = sh(["git", "-C", work, "rev-parse", "--show-toplevel"])
    if probe["rc"] == 0:
        sys.exit("work root %s is inside a git repository (%s); choose another "
                 "(QZP_WORK)" % (work, probe["out"].strip()))


def build_settings(run, ctx):
    settings = {}
    if run["sandbox"] != "off":
        sbx = {"enabled": True, "failIfUnavailable": True,
               "autoAllowBashIfSandboxed": True, "allowUnsandboxedCommands": False}
        if run["sandbox"] == SBX_ALLOW:
            sbx["filesystem"] = {"allowWrite": [DATA_PARENT, ctx["allowed"]]}
        settings["sandbox"] = sbx
    if run["cfg"]:
        settings["pluginConfigs"] = {INLINE_ID: {"options": {"qz_token": CFG_FLAG}}}
    if "off_flag" in run["pre"]:
        settings["enabledPlugins"] = {INLINE_ID: False}
    if "hooks_off" in run["pre"]:
        settings["disableAllHooks"] = True
    return settings


def common_flags(run, ctx, args, plugin_dir):
    flags = []
    if plugin_dir:
        flags += ["--plugin-dir", plugin_dir]
    flags += ["--model", args.model, "--effort", args.effort,
              "--no-session-persistence",
              "--permission-mode", run["mode"],
              "--permission-prompts", "none",
              "--max-budget-usd", PER_RUN_USD,
              "--include-hook-events", "--forward-subagent-text", "--verbose"]
    if ctx.get("settings_path"):
        flags += ["--settings", ctx["settings_path"]]
    if run["allow"]:
        flags += ["--allowedTools"] + list(run["allow"])
    if "add_data_dir" in run["pre"]:
        flags += ["--add-dir", DATA_GUESS]
    if args.clean:
        flags += ["--setting-sources", "project,local"]
    flags += ["--output-format", "stream-json"]
    return flags


def prompt_for(run, ctx):
    if run["kind"] in ("outside", "agent"):
        return '/%s:%s "%s" %s' % (PLUGIN, run["skill"], ctx["outside"], run["id"])
    return "/%s:%s" % (PLUGIN, run["skill"])


def run_single(argv, cwd, out_path, err_path, timeout):
    t0 = time.time()
    with open(out_path, "wb") as out, open(err_path, "wb") as err:
        try:
            p = subprocess.run(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=out,
                               stderr=err, timeout=timeout)
            rc = p.returncode
        except subprocess.TimeoutExpired:
            rc = "timeout"
        except OSError as exc:
            rc = "oserror:%s" % exc
    return rc, round(time.time() - t0, 1)


def run_multi(argv, cwd, steps, out_path, err_path, turn_timeout=150):
    """Feed user turns over stream-json stdin, with shell actions in between."""
    t0 = time.time()
    turns = []
    results = queue.Queue()
    with open(err_path, "wb") as err:
        try:
            proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE, stderr=err)
        except OSError as exc:
            return "oserror:%s" % exc, 0.0, turns

        def reader():
            with open(out_path, "wb") as out:
                for raw in proc.stdout:
                    out.write(raw)
                    out.flush()
                    try:
                        ev = json.loads(raw.decode("utf-8", "replace"))
                    except ValueError:
                        continue
                    if isinstance(ev, dict) and ev.get("type") == "result":
                        results.put(ev)
            results.put(None)

        thread = threading.Thread(target=reader, daemon=True)
        thread.start()
        alive = True
        for step in steps:
            if not alive:
                turns.append({"kind": step["kind"], "label": step["label"],
                              "status": "skipped-session-ended"})
                continue
            if step["kind"] == "action":
                res = step["fn"]()
                turns.append({"kind": "action", "label": step["label"],
                              "at": time.time(), "detail": res})
                time.sleep(TURN_GAP_S)
                continue
            line = json.dumps({"type": "user", "message": {
                "role": "user", "content": step["text"]}}) + "\n"
            turn = {"kind": "turn", "label": step["label"], "text": step["text"],
                    "sent_at": time.time()}
            try:
                proc.stdin.write(line.encode("utf-8"))
                proc.stdin.flush()
            except (BrokenPipeError, OSError) as exc:
                turn["status"] = "stdin-closed:%s" % exc.__class__.__name__
                turns.append(turn)
                alive = False
                continue
            try:
                ev = results.get(timeout=turn_timeout)
            except queue.Empty:
                turn["status"] = "no-result-within-%ss" % turn_timeout
                turns.append(turn)
                continue
            turn["result_at"] = time.time()
            if ev is None:
                turn["status"] = "session-ended-before-result"
                alive = False
            else:
                turn["status"] = "result"
                turn["result"] = ev.get("result")
                turn["subtype"] = ev.get("subtype")
                turn["is_error"] = ev.get("is_error")
                turn["cost"] = ev.get("total_cost_usd")
            turns.append(turn)
            time.sleep(TURN_GAP_S)
        try:
            proc.stdin.close()
        except OSError:
            pass
        try:
            rc = proc.wait(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill()
            rc = "killed-after-stdin-close"
        thread.join(timeout=10)
    return rc, round(time.time() - t0, 1), turns


def cost_of(out_path):
    """Largest total_cost_usd seen in result events (it is cumulative per session)."""
    best = 0.0
    try:
        with open(out_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if '"total_cost_usd"' not in line:
                    continue
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                if isinstance(ev, dict) and ev.get("type") == "result":
                    best = max(best, float(ev.get("total_cost_usd") or 0.0))
    except OSError:
        pass
    return best


def prepare_run(run, work, evid):
    rdir = os.path.join(work, "runs", run["id"])
    ctx = {"cwd": os.path.join(rdir, "cwd"), "outside": os.path.join(rdir, "outside"),
           "allowed": os.path.join(rdir, "allowed"), "edir": os.path.join(evid, "runs",
                                                                           run["id"])}
    if os.path.exists(rdir):
        sys.exit("run folder exists already: %s" % rdir)
    os.makedirs(ctx["cwd"])
    os.makedirs(ctx["outside"])
    os.makedirs(ctx["edir"], exist_ok=True)
    sh(["git", "init", "-q", ctx["cwd"]])
    write_text(os.path.join(ctx["cwd"], ".qzp-run-id"), run["id"] + "\n")
    write_text(os.path.join(ctx["outside"], "seed.txt"), "QZP7-SEED-OUT-%s\n" % run["id"])
    if "allowed_dir" in run["pre"]:
        os.makedirs(ctx["allowed"])
    if "hook_data_flag" in run["pre"]:
        write_text(os.path.join(ctx["cwd"], ".qzp-hook-data-write"), "1\n")
    if "off_local" in run["pre"]:
        write_json(os.path.join(ctx["cwd"], ".claude", "settings.local.json"),
                   {"enabledPlugins": {INLINE_ID: False}})
    settings = build_settings(run, ctx)
    if settings:
        ctx["settings_path"] = os.path.join(rdir, "settings.json")
        write_json(ctx["settings_path"], settings)
        write_json(os.path.join(ctx["edir"], "settings.json"), settings)
    ctx["settings"] = settings
    return ctx


def collect(run, ctx, extra):
    """Copy what the session left behind into the evidence folder."""
    edir = ctx["edir"]
    src = os.path.join(ctx["cwd"], "qzp-out")
    if os.path.isdir(src):
        shutil.copytree(src, os.path.join(edir, "qzp-out"), dirs_exist_ok=True)
    local = os.path.join(ctx["cwd"], ".claude", "settings.local.json")
    artifacts = {
        "cwd": listing(ctx["cwd"]),
        "cwd_qzp_out": listing(src),
        "outside": listing(ctx["outside"]),
        "allowed": listing(ctx["allowed"]),
        "data_after": listing(extra["data_dir"]),
        "data_parent_after": sorted(
            n for n in (os.listdir(DATA_PARENT) if os.path.isdir(DATA_PARENT) else [])
            if n.startswith(PLUGIN)),
        "settings_local": first_line(local) if os.path.exists(local) else None,
    }
    write_json(os.path.join(edir, "artifacts.json"), artifacts)


def execute(run, args, work, evid, plugin_dir, dry):
    ctx = prepare_run(run, work, evid)
    edir = ctx["edir"]
    flags = common_flags(run, ctx, args, plugin_dir)
    meta = dict(run)
    meta.update({"cwd": ctx["cwd"], "outside": ctx["outside"], "allowed": ctx["allowed"],
                 "settings": ctx["settings"], "data_guess": DATA_GUESS,
                 "data_before": listing(DATA_GUESS), "started_at": time.time()})
    out_path = os.path.join(edir, "stdout.jsonl")
    err_path = os.path.join(edir, "stderr.txt")
    if run["kind"] == "multi":
        argv = ["claude", "-p", "--input-format", "stream-json"] + flags
        local = os.path.join(ctx["cwd"], ".claude", "settings.local.json")

        def turn_off():
            write_json(local, {"enabledPlugins": {INLINE_ID: False}})
            return {"wrote": local, "content": first_line(local)}

        ping = "/%s:%s" % (PLUGIN, run["skill"])
        steps = [
            {"kind": "turn", "label": "t1-before", "text": ping},
            {"kind": "action", "label": "write-local-settings-off", "fn": turn_off},
            {"kind": "turn", "label": "t2-after-off-no-reload", "text": ping},
            {"kind": "turn", "label": "t3-reload", "text": "/reload-plugins"},
            {"kind": "turn", "label": "t4-after-reload", "text": ping},
        ]
    else:
        argv = ["claude", "-p", prompt_for(run, ctx)] + flags
        steps = None
    meta["argv"] = argv
    write_text(os.path.join(edir, "cmd.txt"),
               " ".join(json.dumps(a, ensure_ascii=False) for a in argv)
               + "\ncwd=" + ctx["cwd"] + "\n")
    if dry:
        meta["rc"] = "dry-run"
        write_json(os.path.join(edir, "meta.json"), meta)
        return 0.0
    if steps is None:
        rc, wall = run_single(argv, ctx["cwd"], out_path, err_path, args.timeout)
        turns = None
    else:
        rc, wall, turns = run_multi(argv, ctx["cwd"], steps, out_path, err_path)
    cost = cost_of(out_path)
    meta.update({"rc": rc, "wall_s": wall, "cost_usd": cost, "ended_at": time.time()})
    if turns is not None:
        for t in turns:
            t.pop("fn", None)
        meta["turns"] = turns
    write_json(os.path.join(edir, "meta.json"), meta)
    collect(run, ctx, {"data_dir": DATA_GUESS})
    return cost


def snapshot(evid, name, cwd):
    snap = {
        "plugin_list": sh(["claude", "plugin", "list", "--json"], cwd=cwd),
        "marketplace_list": sh(["claude", "plugin", "marketplace", "list", "--json"],
                               cwd=cwd),
        "sha_user_settings": sha(os.path.join(HOME, ".claude", "settings.json")),
        "sha_installed_plugins": sha(os.path.join(HOME, ".claude", "plugins",
                                                  "installed_plugins.json")),
        "sha_known_marketplaces": sha(os.path.join(HOME, ".claude", "plugins",
                                                   "known_marketplaces.json")),
    }
    write_json(os.path.join(evid, "installed", name + ".json"), snap)
    return snap


def installed_step(args, work, evid, plugin_src):
    """Optional: install the fixture from a local marketplace at local scope, then
    measure `claude plugin disable` / `enable` with the real commands."""
    base = os.path.join(work, "installed")
    cwd = os.path.join(base, "cwd")
    market = os.path.join(base, "market")
    edir = os.path.join(evid, "installed")
    os.makedirs(cwd)
    os.makedirs(edir, exist_ok=True)
    sh(["git", "init", "-q", cwd])
    shutil.copytree(plugin_src, os.path.join(market, "plugins", PLUGIN))
    write_json(os.path.join(market, ".claude-plugin", "marketplace.json"), {
        "name": MARKET, "owner": {"name": "qzprobe kit"},
        "plugins": [{"name": PLUGIN, "source": "./plugins/" + PLUGIN,
                     "description": "Throwaway measurement fixture"}]})
    undo = ["claude plugin uninstall %s --scope local" % MARKET_ID,
            "claude plugin marketplace remove %s" % MARKET]
    say("[installed] if this stops halfway, undo by hand from %s :" % cwd)
    for line in undo:
        say("    " + line)
    log = []

    def step(label, argv):
        res = sh(argv, cwd=cwd, timeout=180)
        res["label"] = label
        res["at"] = time.time()
        res["settings_local"] = first_line(
            os.path.join(cwd, ".claude", "settings.local.json"))
        log.append(res)
        write_json(os.path.join(edir, "steps.json"), log)
        say("[installed] %s -> rc=%s" % (label, res["rc"]))
        return res

    run = dict(zip(FIELDS, ("installed", 4, "ping", "qz-ping", "dontAsk", "off", [],
                            False, [], False, "installed plugin")))
    flags = common_flags(run, {}, args, None)
    ping = "/%s:qz-ping" % PLUGIN
    total = 0.0

    def session(label):
        out_path = os.path.join(edir, label + ".stdout.jsonl")
        err_path = os.path.join(edir, label + ".stderr.txt")
        rc, wall = run_single(["claude", "-p", ping] + flags, cwd, out_path, err_path,
                              args.timeout)
        log.append({"label": label, "rc": rc, "wall_s": wall, "at": time.time(),
                    "session": True})
        write_json(os.path.join(edir, "steps.json"), log)
        say("[installed] session %s -> rc=%s" % (label, rc))
        return cost_of(out_path)

    before = snapshot(evid, "before", cwd)
    try:
        step("marketplace-add", ["claude", "plugin", "marketplace", "add", market,
                                 "--scope", "local"])
        step("install", ["claude", "plugin", "install", MARKET_ID, "--scope", "local"])
        snapshot(evid, "after-install", cwd)
        total += session("i1-on")
        step("disable", ["claude", "plugin", "disable", MARKET_ID, "--scope", "local"])
        total += session("i2-off-new-session")
        step("enable", ["claude", "plugin", "enable", MARKET_ID, "--scope", "local"])
        out_path = os.path.join(edir, "i3-midsession.stdout.jsonl")
        err_path = os.path.join(edir, "i3-midsession.stderr.txt")
        steps = [
            {"kind": "turn", "label": "t1-before", "text": ping},
            {"kind": "action", "label": "claude-plugin-disable", "fn": lambda: step(
                "disable-midsession",
                ["claude", "plugin", "disable", MARKET_ID, "--scope", "local"])},
            {"kind": "turn", "label": "t2-after-off-no-reload", "text": ping},
            {"kind": "turn", "label": "t3-reload", "text": "/reload-plugins"},
            {"kind": "turn", "label": "t4-after-reload", "text": ping},
        ]
        rc, wall, turns = run_multi(
            ["claude", "-p", "--input-format", "stream-json"] + flags, cwd, steps,
            out_path, err_path)
        for t in turns:
            t.pop("fn", None)
        write_json(os.path.join(edir, "i3-midsession.turns.json"),
                   {"rc": rc, "wall_s": wall, "turns": turns})
        total += cost_of(out_path)
    finally:
        step("uninstall", ["claude", "plugin", "uninstall", MARKET_ID, "--scope",
                           "local"])
        step("marketplace-remove", ["claude", "plugin", "marketplace", "remove", MARKET])
        after = snapshot(evid, "after", cwd)
        same = {k: before[k] == after[k] for k in before if k.startswith("sha_")}
        same["plugin_list"] = before["plugin_list"]["out"] == after["plugin_list"]["out"]
        same["marketplace_list"] = (before["marketplace_list"]["out"]
                                    == after["marketplace_list"]["out"])
        src = os.path.join(cwd, "qzp-out")
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(edir, "qzp-out"), dirs_exist_ok=True)
        write_json(os.path.join(edir, "restore-check.json"), same)
        say("[installed] restored? %s" % json.dumps(same))
    return total


def main():
    ap = argparse.ArgumentParser(description="qzprobe kit runner")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--with", dest="extra", default="")
    ap.add_argument("--installed", action="store_true")
    ap.add_argument("--clean", action="store_true")
    ap.add_argument("--budget", type=float, default=8.0)
    ap.add_argument("--model", default="sonnet")
    ap.add_argument("--effort", default="medium")
    ap.add_argument("--timeout", type=int, default=420)
    args = ap.parse_args()

    runs = [dict(zip(FIELDS, row)) for row in PLAN]
    known = {r["id"] for r in runs}
    only = [x for x in args.only.split(",") if x]
    extra = [x for x in args.extra.split(",") if x]
    for rid in only + extra:
        if rid not in known:
            sys.exit("unknown run id: %s (see --list)" % rid)
    if only:
        chosen = [r for r in runs if r["id"] in only]
    elif args.installed:
        chosen = []
    else:
        chosen = [r for r in runs if r["default"] or r["id"] in extra]

    if args.list:
        for r in runs:
            say("%-20s item %s  %-10s mode=%-17s sandbox=%-18s %s%s" % (
                r["id"], r["item"], r["kind"], r["mode"], r["sandbox"], r["about"],
                "" if r["default"] else "  [opt-in]"))
        say("%-20s item 4  optional step, edits real plugin records [--installed]"
            % "installed")
        return

    plugin_src = os.path.join(KIT, "plugin", PLUGIN)
    if not os.path.isfile(os.path.join(plugin_src, ".claude-plugin", "plugin.json")):
        sys.exit("fixture plugin not found at %s" % plugin_src)
    ver = sh(["claude", "--version"])
    if ver["rc"] != 0:
        sys.exit("`claude --version` failed (%s); is Claude Code on PATH?" % ver["rc"])
    version = ver["out"].strip()

    stamp = time.strftime("%Y%m%d-%H%M%S")
    work = os.environ.get("QZP_WORK") or os.path.join(HOME, ".cache", PLUGIN, stamp)
    evid = os.environ.get("QZP_EVID") or os.path.join(os.path.dirname(KIT), "results",
                                                      stamp)
    if os.path.exists(work):
        sys.exit("work root exists already: %s" % work)
    os.makedirs(work)
    if not args.dry_run:
        # A dry run starts no session, so where the folders sit does not matter.
        refuse_bad_work_root(work)
    os.makedirs(evid, exist_ok=True)
    plugin_dir = os.path.join(work, "plugin", PLUGIN)
    shutil.copytree(plugin_src, plugin_dir)
    for name in ("qzp.sh", "qzp-hook.sh"):
        os.chmod(os.path.join(plugin_dir, "scripts", name), 0o755)

    n_sessions = len(chosen) + (3 if args.installed else 0)
    say("qzprobe: 세션 %d회 (%s, 모델 %s/%s). 예상 $%.0f-%.0f · %d-%d분. "
        "합계 $%.2f, 세션당 $%s 에서 멈춘다." % (
            n_sessions, version, args.model, args.effort,
            max(1, n_sessions * 0.15), max(1, n_sessions * 0.30),
            max(1, n_sessions // 2), max(2, n_sessions), args.budget, PER_RUN_USD))
    say("  작업 폴더 : %s" % work)
    say("  근거 폴더 : %s" % evid)
    say("  Claude Code 가 스스로 만들 수 있는 폴더 : %s" % DATA_GUESS)
    if os.environ.get("CLAUDECODE"):
        say("  경고: CLAUDECODE 가 있다 - Claude Code 세션 안의 셸로 보인다.")
        say("        세션 밖 터미널에서 돌려야 값이 섞이지 않는다.")
    if args.installed:
        say("  --installed 는 실제 플러그인 기록을 바꾼다")
        say("  (local 범위로 마켓플레이스 추가 · 설치 → 끝에 지운다).")

    write_json(os.path.join(evid, "env.json"), {
        "stamp": stamp, "claude_version": version, "platform": platform.platform(),
        "python": sys.version.split()[0], "work": work, "evid": evid, "kit": KIT,
        "home": HOME, "model": args.model, "effort": args.effort, "clean": args.clean,
        "claudecode_env": bool(os.environ.get("CLAUDECODE")),
        "data_guess": DATA_GUESS, "data_existed_at_start": os.path.isdir(DATA_GUESS),
        "user_settings": user_settings_summary(),
        "plan": [r["id"] for r in chosen], "installed": args.installed,
        "dry_run": args.dry_run})

    spent = 0.0
    skipped = []
    for r in chosen:
        if spent >= args.budget:
            skipped.append(r["id"])
            continue
        say("[%s] %s ..." % (r["id"], r["about"]))
        spent += execute(r, args, work, evid, plugin_dir, args.dry_run)
        say("[%s] done (running total $%.2f)" % (r["id"], spent))
    if skipped:
        say("budget reached; not run: %s" % ", ".join(skipped))
    if args.installed and not args.dry_run:
        if spent >= args.budget:
            say("budget reached; --installed step not run")
        else:
            spent += installed_step(args, work, evid, plugin_src)
    write_json(os.path.join(evid, "totals.json"),
               {"spent_usd": round(spent, 4), "skipped_for_budget": skipped})

    summ = sh([sys.executable, os.path.join(KIT, "qzp_summarize.py"), evid], timeout=300)
    if summ["rc"] != 0:
        say("summary failed (rc=%s): %s" % (summ["rc"], summ["err"][-400:]))
    else:
        say(summ["out"].strip())
    say("쓴 비용 합계 $%.2f" % spent)
    say("결과 표 : %s" % os.path.join(evid, "results.md"))
    say("이 실행이 만든 것을 지우는 명령:")
    say('  rm -rf "%s" "%s"' % (work, DATA_GUESS))
    if args.installed:
        say('  rm -rf "%s"' % os.path.join(DATA_PARENT, PLUGIN + "-" + MARKET))


if __name__ == "__main__":
    main()
````

#### `qzp_summarize.py`

````python
#!/usr/bin/env python3
"""qzp_summarize.py <evidence-root> - turn qzprobe evidence into results.md / .json.

Verdicts come from files left behind, marker strings and stream events, never from
the exit code alone. Whatever could not be judged is reported as "재지 못함" with
the reason: "not there" and "could not check" are different facts.
"""
import glob
import json
import os
import sys

OK, NO, DENIED, ERR, UNK = "됨", "안 됨", "거부", "오류", "재지 못함"
RAN, BLOCKED = "실행됨", "막힘"
PING = "QZP7-PING-58213"
ITEMS = {
    1: "항목 1 - 샌드박스와 데이터 폴더 쓰기",
    2: "항목 2 - 작업 폴더 밖 읽기 · 쓰기와 하위 agent",
    3: "항목 3 - 변수 치환과 환경변수",
    4: "항목 4 - 플러그인 끄기",
}
VARS = (("QZP_ROOT", "${CLAUDE_PLUGIN_ROOT}", "플러그인 루트"),
        ("QZP_DATA", "${CLAUDE_PLUGIN_DATA}", "데이터 폴더"),
        ("QZP_CFG", "${user_config.qz_token}", "설정 값(userConfig)"))
WHERE = {"fence": "skill 본문 펜스", "inject": "사전 실행 줄", "agent": "agent 본문",
         "outside": "skill 본문 번호 목록"}
HOME = os.path.expanduser("~")


def load_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def load_events(path):
    events = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                if isinstance(ev, dict):
                    events.append(ev)
    except OSError:
        pass
    return events


def read_text(path, limit=600):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read(limit)
    except OSError:
        return ""


def parse_tsv(path):
    data = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                key, _, val = line.rstrip("\n").partition("\t")
                data[key] = val
    except OSError:
        pass
    return data


def probes(edir, mode=None):
    out = []
    for path in sorted(glob.glob(os.path.join(edir, "qzp-out", "probe-*.tsv"))):
        tsv = parse_tsv(path)
        if mode is None or tsv.get("mode") == mode:
            out.append(tsv)
    return out


def hook_lines(edir):
    out = []
    for line in read_text(os.path.join(edir, "qzp-out", "hooks.tsv"), 200000).splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        fields = dict(p.partition("=")[::2] for p in parts[2:])
        try:
            ts = float(parts[0])
        except ValueError:
            ts = 0.0
        out.append({"ts": ts, "event": parts[1], "fields": fields})
    return out


def short(text, limit=240):
    text = "" if text is None else str(text)
    text = text.replace(HOME, "~").replace("\n", " ").replace("\t", " ")
    return text if len(text) <= limit else text[:limit] + "..."


def blocks(ev):
    content = (ev.get("message") or {}).get("content")
    return [b for b in content if isinstance(b, dict)] if isinstance(content, list) else []


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(str(b.get("text", "")) for b in content if isinstance(b, dict))
    return "" if content is None else str(content)


def parse_stream(events):
    s = {"inits": [], "calls": [], "results": [], "texts": []}
    by_id = {}
    for ev in events:
        kind, sub = ev.get("type"), ev.get("subtype")
        if kind == "system" and sub == "init":
            s["inits"].append(ev)
        elif kind == "system" and sub == "permission_denied":
            call = by_id.get(ev.get("tool_use_id"))
            if call is not None:
                call["denied_msg"] = ev.get("message") or "denied"
        elif kind == "assistant":
            for b in blocks(ev):
                if b.get("type") == "tool_use":
                    call = {"id": b.get("id"), "name": b.get("name"),
                            "input": b.get("input") or {},
                            "parent": ev.get("parent_tool_use_id"), "result": None,
                            "is_error": None, "decision": None, "non_exec": None,
                            "denied_msg": None}
                    by_id[call["id"]] = call
                    s["calls"].append(call)
                elif b.get("type") == "text":
                    s["texts"].append(str(b.get("text", "")))
        elif kind == "user":
            metas = {m.get("id"): m for m in ev.get("tool_result_meta") or []
                     if isinstance(m, dict)}
            for b in blocks(ev):
                if b.get("type") != "tool_result":
                    continue
                call = by_id.get(b.get("tool_use_id"))
                if call is None:
                    continue
                call["result"] = text_of(b.get("content"))
                call["is_error"] = bool(b.get("is_error"))
                meta = metas.get(call["id"]) or {}
                call["decision"] = meta.get("permission_decision")
                call["non_exec"] = meta.get("non_execution_kind")
        elif kind == "result":
            s["results"].append(ev)
            s["texts"].append(str(ev.get("result") or ""))
    s["init"] = s["inits"][0] if s["inits"] else None
    return s


def call_verdict(call):
    """(verdict, evidence) for one tool call, or 'not attempted'."""
    if call is None:
        return UNK, "모델이 이 걸음을 시도하지 않았다(도구 호출이 스트림에 없다)"
    dec = call.get("decision") or {}
    how = "/".join(str(dec.get(k)) for k in ("decision", "source", "reason_type")
                   if dec.get(k) is not None)
    if call.get("denied_msg") or dec.get("decision") == "reject" or call.get("non_exec"):
        return DENIED, "권한 판정 %s · %s · %s" % (
            how or "-", call.get("non_exec") or "-",
            short(call.get("denied_msg") or call.get("result"), 160))
    if call.get("result") is None:
        return UNK, "도구 결과가 스트림에 없다"
    if call.get("is_error"):
        return ERR, "권한 판정 %s · %s" % (how or "-", short(call.get("result"), 200))
    return RAN, "권한 판정 %s · 결과 %s" % (how or "-", short(call.get("result"), 120))


def find_call(calls, names, pred, parent="any"):
    for call in calls:
        if call["name"] not in names:
            continue
        if parent != "any" and call.get("parent") != parent:
            continue
        try:
            if pred(call["input"]):
                return call
        except (TypeError, AttributeError):
            continue
    return None


def fp(inp):
    return str(inp.get("file_path", ""))


def cmd(inp):
    return str(inp.get("command", ""))


class Rows:
    def __init__(self):
        self.rows = []

    def add(self, item, run, what, verdict, evidence):
        self.rows.append({"item": item, "run": run, "what": what, "verdict": verdict,
                          "evidence": short(evidence, 420), "seq": len(self.rows)})


def subst_rows(R, run, tsv):
    where = WHERE.get(tsv.get("mode"), tsv.get("mode"))
    for name, literal, label in VARS:
        val = tsv.get("arg." + name)
        what = "%s 치환 - %s" % (label, where)
        if not val:
            R.add(3, run["id"], what, UNK, "그 인자가 스크립트에 오지 않았다")
        elif val == literal:
            R.add(3, run["id"], what, NO, "글자 그대로 왔다: " + val)
        elif "${" in val:
            R.add(3, run["id"], what, UNK, "뜻밖의 값: " + val)
        else:
            note = ""
            if name == "QZP_CFG":
                note = {"QZP7-CFG-FLAG": " (실행 옵션 pluginConfigs 의 값)",
                        "QZP7-CFG-DEFAULT": " (manifest 기본값)"}.get(val, " (뜻밖의 값)")
            R.add(3, run["id"], what, OK, "값: " + val + note)
    for env_name, label in (("CLAUDE_PLUGIN_ROOT", "플러그인 루트"),
                            ("CLAUDE_PLUGIN_DATA", "데이터 폴더"),
                            ("CLAUDE_PLUGIN_OPTION_QZ_TOKEN", "설정 값(userConfig)")):
        val = tsv.get("env." + env_name)
        what = "%s 환경변수가 Bash 로 도는 스크립트에 닿는가 - %s" % (label, where)
        if val is None:
            R.add(3, run["id"], what, UNK, "기록이 없다")
        elif val == "unset":
            R.add(3, run["id"], what, NO, "%s 가 스크립트 환경에 없다" % env_name)
        else:
            R.add(3, run["id"], what, OK, "%s=%s" % (env_name, val[4:]))
    R.add(3, run["id"], "스크립트가 본 CLAUDE*/SANDBOX 환경변수 이름 - %s" % where, "-",
          tsv.get("env.names", ""))


def write_rows(R, run, tsv):
    where = WHERE.get(tsv.get("mode"), tsv.get("mode"))
    sandbox = run["sandbox"] != "off"
    pos = tsv.get("write.cwd.verdict") == "ok"
    out_v = tsv.get("write.outside.verdict")
    neg_ok = (not sandbox) or out_v == "fail"
    alw = tsv.get("write.allowed.verdict")
    tag = "샌드박스 %s" % run["sandbox"]

    def detail(label):
        return "%s · mkdir[%s] · write[%s]" % (
            tsv.get("write.%s.path" % label, ""), tsv.get("write.%s.mkdir" % label, ""),
            tsv.get("write.%s.write" % label, ""))

    R.add(run["item"], run["id"], "[양성 대조] 작업 폴더 쓰기 - %s (%s)" % (where, tag),
          OK if pos else NO, detail("cwd"))
    if sandbox:
        R.add(run["item"], run["id"],
              "[음성 대조] 작업 폴더 밖 쓰기는 막혀야 한다 - %s (%s)" % (where, tag),
              "막힘(기대대로)" if out_v == "fail" else "막히지 않음", detail("outside"))
    else:
        R.add(2, run["id"], "스크립트 안의 작업 폴더 밖 쓰기 - %s (%s)" % (where, tag),
              OK if out_v == "ok" else BLOCKED, detail("outside"))
    if alw in ("ok", "fail"):
        R.add(run["item"], run["id"],
              "[양성 대조] allowWrite 에 넣은 다른 폴더 쓰기 - %s (%s)" % (where, tag),
              OK if alw == "ok" else NO, detail("allowed"))
    tmp_v = tsv.get("write.tmp.verdict")
    R.add(run["item"], run["id"], "임시 폴더($TMPDIR) 쓰기 - %s (%s)" % (where, tag),
          {"ok": OK, "fail": BLOCKED}.get(tmp_v, UNK), detail("tmp") + " · " + str(tmp_v))

    extra = "경로 출처 %s · 스크립트 시작 때 폴더 %s" % (
        tsv.get("data.path_source"), tsv.get("data.exists_before"))
    data_v = tsv.get("write.data.verdict")
    what = "데이터 폴더 쓰기(Bash 로 도는 스크립트) - %s (%s)" % (where, tag)
    if "add_data_dir" in run["pre"]:
        what += " + --add-dir"
    if not pos:
        verdict, why = UNK, "양성 대조 실패(작업 폴더에도 못 썼다) · "
    elif not neg_ok:
        verdict, why = UNK, "샌드박스가 걸리지 않았다(작업 폴더 밖 쓰기가 성공) · "
    elif run["sandbox"].endswith("allowWrite") and alw != "ok":
        verdict, why = UNK, "allowWrite 양성 대조 실패(설정이 먹지 않았을 수 있다) · "
    else:
        verdict, why = (OK if data_v == "ok" else BLOCKED), ""
    R.add(1, run["id"], what, verdict, why + detail("data") + " · " + extra)
    for label, name in (("outside", "작업 폴더 밖 파일"), ("data_seed", "데이터 폴더 파일")):
        res = tsv.get("read.%s.result" % label, "")
        R.add(2, run["id"], "스크립트 안의 %s 읽기 - %s (%s)" % (name, where, tag),
              OK if res.startswith("rc=0") else NO,
              "%s · %s" % (tsv.get("read.%s.path" % label, ""), res))


def hook_rows(R, run, edir):
    lines = hook_lines(edir)
    first = next((h for h in lines if h["event"] == "SessionStart"), None)
    if first is None:
        R.add(3, run["id"], "훅 프로세스 환경변수(SessionStart)", UNK,
              "훅 기록 줄이 없다(hooks.tsv)")
    else:
        for key, label in (("root", "플러그인 루트"), ("data", "데이터 폴더"),
                           ("option", "설정 값(userConfig)")):
            val = first["fields"].get(key, "")
            R.add(3, run["id"], "%s 환경변수가 훅 프로세스에 닿는가" % label,
                  NO if val == "unset" else OK, val)
        R.add(1, run["id"], "SessionStart 훅 시점에 데이터 폴더가 있었나", "-",
              "data_dir_exists=%s" % first["fields"].get("data_dir_exists"))
    hdw = read_text(os.path.join(edir, "qzp-out", "hook-data-write.tsv")).strip()
    if "hook_data_flag" in run["pre"]:
        if not hdw:
            R.add(1, run["id"], "데이터 폴더 쓰기(훅 프로세스, 샌드박스 %s)"
                  % run["sandbox"], UNK, "훅 쓰기 기록이 없다")
        else:
            R.add(1, run["id"], "데이터 폴더 쓰기(훅 프로세스, 샌드박스 %s)"
                  % run["sandbox"], OK if "\trc=0\t" in hdw + "\t" else NO, hdw)


def probe_run(R, run, edir, s):
    mode = "inject" if run["skill"] == "qz-inject" else "fence"
    found = probes(edir, mode)
    if not found:
        last = s["results"][-1] if s["results"] else {}
        R.add(run["item"], run["id"], "스크립트 실행(%s)" % WHERE[mode], UNK,
              "스크립트 기록 파일이 없다 · 결과 글: %s · stderr: %s" % (
                  short(last.get("result"), 160),
                  short(read_text(os.path.join(edir, "stderr.txt")), 160)))
    for tsv in found:
        subst_rows(R, run, tsv)
        write_rows(R, run, tsv)
    if len(found) > 1:
        R.add(run["item"], run["id"], "스크립트가 여러 번 돌았다", "-",
              "%d 번 - 모델이 다시 시도했다" % len(found))
    if mode == "fence":
        call = find_call(s["calls"], ("Bash",), lambda i: "qzp.sh" in cmd(i))
        verdict, ev = call_verdict(call)
        R.add(3, run["id"], "펜스 명령 실행(Bash 도구) - 모델이 받은 명령 글", verdict,
              ev + (" · 명령: " + short(cmd(call["input"]), 200) if call else ""))
        call = find_call(s["calls"], ("Read",), lambda i: fp(i).endswith("support.md"))
        verdict, ev = call_verdict(call)
        R.add(3, run["id"], "보조 파일 Read(플러그인 폴더 안, 작업 폴더 밖)", verdict,
              ev + (" · 경로: " + short(fp(call["input"]), 160) if call else ""))
        line = ""
        if call and call.get("result"):
            line = next((ln for ln in call["result"].splitlines()
                         if "QZP7-SUPPORT-LINE" in ln), "")
        for name, literal, label in VARS:
            what = "%s 치환 - Read 로 연 보조 파일" % label
            if not line:
                R.add(3, run["id"], what, UNK, "보조 파일의 표식 줄을 읽지 못했다")
            elif literal in line:
                R.add(3, run["id"], what, NO, "글자 그대로 왔다: " + short(line, 260))
            else:
                R.add(3, run["id"], what, OK, short(line, 260))
    else:
        saw = next((t for t in s["texts"] if "QZP7-INJECT-SAW" in t), "")
        R.add(3, run["id"], "사전 실행 줄의 출력이 본문에 끼워졌나(모델 보고)",
              OK if "QZP7-PROBE-RAN" in saw else UNK, short(saw, 200) or "보고 글이 없다")
    hook_rows(R, run, edir)


OUTSIDE_STEPS = (
    ("작업 폴더 밖 읽기 - Read 도구", ("Read",),
     lambda i: fp(i).endswith("/seed.txt"), None),
    ("작업 폴더 밖 쓰기 - Write 도구", ("Write",),
     lambda i: fp(i).endswith("/tool-write.txt"), ("outside", "tool-write.txt")),
    ("작업 폴더 밖 읽기 - Bash cat", ("Bash",),
     lambda i: "seed.txt" in cmd(i) and "cat" in cmd(i) and "qzp-seed" not in cmd(i),
     None),
    ("작업 폴더 밖 쓰기 - Bash 리다이렉트", ("Bash",),
     lambda i: "bash-redirect.txt" in cmd(i), ("outside", "bash-redirect.txt")),
    ("데이터 폴더 읽기 - Read 도구", ("Read",),
     lambda i: fp(i).endswith("qzp-seed.txt"), None),
    ("데이터 폴더 쓰기 - Write 도구", ("Write",),
     lambda i: "tool-write-" in os.path.basename(fp(i))
     and not fp(i).endswith("tool-write-cwd.txt"), ("data_after", "tool-write-%s.txt")),
    ("스크립트 실행 - Bash(스크립트가 안에서 밖에 쓴다)", ("Bash",),
     lambda i: "qzp.sh" in cmd(i), None),
    ("작업 폴더 안 쓰기 - Write 도구", ("Write",),
     lambda i: fp(i).endswith("tool-write-cwd.txt"), ("cwd_qzp_out", "tool-write-cwd.txt")),
    ("플러그인 폴더 안 보조 파일 읽기 - Read 도구", ("Read",),
     lambda i: fp(i).endswith("support.md"), None),
)


def outside_run(R, run, edir, s):
    arts = load_json(os.path.join(edir, "artifacts.json"), {}) or {}
    tag = "권한 모드 %s · 샌드박스 %s" % (run["mode"], run["sandbox"])
    for what, names, pred, art in OUTSIDE_STEPS:
        call = find_call(s["calls"], names, pred)
        verdict, ev = call_verdict(call)
        if call:
            target = fp(call["input"]) or cmd(call["input"])
            ev += " · 대상: " + short(target, 150)
        if art:
            name = art[1] % run["id"] if "%s" in art[1] else art[1]
            files = (arts.get(art[0]) or {}).get("files") or {}
            ev += " · 파일 남음: %s" % ("예(%s)" % files[name] if name in files else "아니오")
        item = 1 if what.startswith("데이터 폴더 쓰기") else 2
        R.add(item, run["id"], "%s (%s)" % (what, tag), verdict, ev)
    for tsv in probes(edir, "outside"):
        subst_rows(R, run, tsv)
        write_rows(R, run, tsv)


def agent_run(R, run, edir, s):
    tag = "권한 모드 %s · 샌드박스 %s" % (run["mode"], run["sandbox"])
    agent = find_call(s["calls"], ("Agent", "Task"),
                      lambda i: "qz-reader" in json.dumps(i))
    verdict, ev = call_verdict(agent)
    R.add(2, run["id"], "하위 agent 띄우기 (%s)" % tag, verdict, ev)
    parent = agent["id"] if agent else None
    subs = [c for c in s["calls"] if parent and c.get("parent") == parent]
    seen = "하위 agent 의 도구 호출 %d개가 스트림에 보인다" % len(subs)
    steps = (
        ("하위 agent 가 작업 폴더 밖 파일 읽기 - Read 도구", ("Read",),
         lambda i: fp(i).endswith("/seed.txt")),
        ("하위 agent 가 데이터 폴더 파일 읽기 - Read 도구", ("Read",),
         lambda i: fp(i).endswith("qzp-seed.txt")),
        ("하위 agent 가 데이터 폴더 파일 읽기 - Bash cat", ("Bash",),
         lambda i: "qzp-seed.txt" in cmd(i) and "cat" in cmd(i)),
        ("하위 agent 가 스크립트 실행 - Bash", ("Bash",), lambda i: "qzp.sh" in cmd(i)),
    )
    for what, names, pred in steps:
        call = find_call(subs, names, pred)
        verdict, ev = call_verdict(call)
        if call is None:
            ev += " · " + seen
        else:
            ev += " · 대상: " + short(fp(call["input"]) or cmd(call["input"]), 150)
        R.add(2, run["id"], "%s (%s)" % (what, tag), verdict, ev)
    report = next((t for t in reversed(s["texts"]) if "QZP7-AGENT-REPORT" in t), "")
    R.add(2, run["id"], "하위 agent 의 한 줄 보고(모델이 옮긴 글 - 약한 근거)", "-",
          short(report, 400) or "보고 글이 없다")
    line = report.split("line=", 1)[1].split("|", 1)[0] if "line=" in report else ""
    for name, literal, label in VARS:
        what = "%s 치환 - agent 본문(모델이 옮긴 글 - 약한 근거)" % label
        if not line:
            R.add(3, run["id"], what, UNK, "보고에 표식 줄이 없다")
        else:
            R.add(3, run["id"], what, NO if literal in line else OK, short(line, 260))
    for tsv in probes(edir, "agent"):
        subst_rows(R, run, tsv)
        write_rows(R, run, tsv)


def plugin_facts(init):
    if not init:
        return None
    names = [p.get("name") for p in init.get("plugins") or [] if isinstance(p, dict)]
    return {"loaded": "qzprobe" in names,
            "slash": "qzprobe:qz-ping" in (init.get("slash_commands") or []),
            "errors": init.get("plugin_errors")}


def count_hooks(lines, lo=None, hi=None):
    counts = {}
    for h in lines:
        if lo is not None and not (lo - 1.5 <= h["ts"] <= hi + 1.5):
            continue
        counts[h["event"]] = counts.get(h["event"], 0) + 1
    return ", ".join("%s %d" % kv for kv in sorted(counts.items())) or "0 줄"


def ping_rows(R, rid, label, s, lines, lo=None, hi=None):
    facts = plugin_facts(s["init"])
    if facts is None:
        R.add(4, rid, "%s - 플러그인이 실렸나" % label, UNK, "init 이벤트가 없다")
    else:
        R.add(4, rid, "%s - 플러그인이 실렸나(init.plugins)" % label,
              "예" if facts["loaded"] else "아니오",
              "slash_commands 에 qzprobe:qz-ping %s · plugin_errors %s" % (
                  "있음" if facts["slash"] else "없음", short(facts["errors"], 120)))
    last = s["results"][-1] if s["results"] else None
    if last is None:
        R.add(4, rid, "%s - 진입 skill 이 도는가" % label, UNK, "result 이벤트가 없다")
    else:
        text = str(last.get("result") or "")
        R.add(4, rid, "%s - 진입 skill 이 도는가(표식 글자)" % label,
              "예" if PING in text else "아니오", "결과 글: " + short(text, 200))
    R.add(4, rid, "%s - 플러그인 훅이 돌았나(훅이 남긴 줄)" % label, "-",
          count_hooks(lines, lo, hi))


def ping_run(R, run, edir, s):
    how = {"off_flag": "--settings 로 끔", "off_local": "local 설정 파일로 끔",
           "hooks_off": "--settings disableAllHooks"}
    label = next((how[p] for p in run["pre"] if p in how), "끄지 않음")
    ping_rows(R, run["id"], "새 세션 · " + label, s, hook_lines(edir))


def multi_rows(R, rid, turns, s, lines):
    R.add(4, rid, "도는 세션 - init 이벤트 수", "-", "%d 개" % len(s["inits"]))
    facts = plugin_facts(s["init"])
    R.add(4, rid, "도는 세션 - 시작할 때 플러그인이 실렸나",
          UNK if facts is None else ("예" if facts["loaded"] else "아니오"), "")
    for t in turns or []:
        if t.get("kind") == "action":
            R.add(4, rid, "도는 세션 - 사이 동작 %s" % t.get("label"), "-",
                  short(json.dumps(t.get("detail"), ensure_ascii=False), 300))
            continue
        label = t.get("label")
        if t.get("status") != "result":
            R.add(4, rid, "도는 세션 - %s" % label, UNK, "차례 상태: %s" % t.get("status"))
            continue
        text = str(t.get("result") or "")
        hooks = count_hooks(lines, t.get("sent_at"), t.get("result_at"))
        if label == "t3-reload":
            R.add(4, rid, "도는 세션 - /reload-plugins 를 화면 없는 세션에 넣었다", "-",
                  "결과 글: %s · 훅 %s" % (short(text, 220), hooks))
        else:
            R.add(4, rid, "도는 세션 - %s - 진입 skill 이 도는가" % label,
                  "예" if PING in text else "아니오",
                  "결과 글: %s · 훅 %s" % (short(text, 160), hooks))


def run_overview(run, meta, s):
    init = s["init"] or {}
    last = s["results"][-1] if s["results"] else {}
    facts = plugin_facts(s["init"])
    denied = sum(1 for c in s["calls"] if call_verdict(c)[0] == DENIED)
    return {
        "run": run["id"], "about": run["about"], "rc": meta.get("rc"),
        "wall_s": meta.get("wall_s"), "cost_usd": meta.get("cost_usd"),
        "version": init.get("claude_code_version"),
        "permission_mode": init.get("permissionMode"),
        "plugin_loaded": None if facts is None else facts["loaded"],
        "tool_calls": len(s["calls"]), "denied": denied,
        "result_subtype": last.get("subtype"), "is_error": last.get("is_error"),
    }


def installed_rows(R, evid):
    edir = os.path.join(evid, "installed")
    steps = load_json(os.path.join(edir, "steps.json"))
    if steps is None:
        return
    rid = "installed"
    windows = {}
    for st in steps:
        if st.get("session"):
            windows[st["label"]] = (st["at"] - float(st.get("wall_s") or 0), st["at"])
        else:
            R.add(4, rid, "명령 %s" % st.get("label"), "rc=%s" % st.get("rc"),
                  "%s · 출력: %s · local 설정: %s" % (
                      " ".join(st.get("argv") or []), short(st.get("out") or st.get("err"),
                                                             160),
                      short(st.get("settings_local"), 120)))
    lines = hook_lines(edir)
    for label, about in (("i1-on", "설치본 · 켠 상태 새 세션"),
                         ("i2-off-new-session", "설치본 · claude plugin disable 뒤 새 세션")):
        s = parse_stream(load_events(os.path.join(edir, label + ".stdout.jsonl")))
        lo, hi = windows.get(label, (None, None))
        ping_rows(R, rid, about, s, lines, lo, hi)
    multi = load_json(os.path.join(edir, "i3-midsession.turns.json"), {}) or {}
    s = parse_stream(load_events(os.path.join(edir, "i3-midsession.stdout.jsonl")))
    multi_rows(R, rid, multi.get("turns"), s, lines)
    check = load_json(os.path.join(edir, "restore-check.json"))
    R.add(4, rid, "되돌림 확인(앞뒤 목록 · 설정 파일 해시가 같은가)",
          UNK if check is None else ("같음" if all(check.values()) else "다름"),
          json.dumps(check, ensure_ascii=False))


def cell(text):
    return short(text, 420).replace("|", "\\|")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: qzp_summarize.py <evidence-root>")
    evid = sys.argv[1]
    env = load_json(os.path.join(evid, "env.json"), {}) or {}
    R = Rows()
    overview = []
    runs_dir = os.path.join(evid, "runs")
    on_disk = sorted(os.listdir(runs_dir)) if os.path.isdir(runs_dir) else []
    for rid in env.get("plan") or on_disk:
        edir = os.path.join(evid, "runs", rid)
        meta = load_json(os.path.join(edir, "meta.json"))
        if meta is None:
            overview.append({"run": rid, "about": "기록 없음(돌지 않았다)", "rc": None})
            R.add(0, rid, "실행", UNK, "meta.json 이 없다 - 예산 상한이나 중단으로 돌지 않았다")
            continue
        run = meta
        s = parse_stream(load_events(os.path.join(edir, "stdout.jsonl")))
        overview.append(run_overview(run, meta, s))
        if meta.get("rc") == "dry-run":
            continue
        if not s["results"] and run["kind"] != "multi":
            R.add(run["item"], rid, "세션", UNK,
                  "result 이벤트가 없다 · rc=%s · stderr: %s · stdout 첫머리: %s" % (
                      meta.get("rc"),
                      short(read_text(os.path.join(edir, "stderr.txt")), 200),
                      short(read_text(os.path.join(edir, "stdout.jsonl"), 300), 200)))
        expect_on = not any(p in run["pre"] for p in ("off_flag", "off_local"))
        facts = plugin_facts(s["init"])
        if expect_on and facts is not None and not facts["loaded"]:
            R.add(run["item"], rid, "[양성 대조] 시험용 플러그인이 실렸나", NO,
                  "init.plugins 에 없다 · plugin_errors %s" % short(facts["errors"], 200))
        if run["kind"] == "probe":
            probe_run(R, run, edir, s)
        elif run["kind"] == "outside":
            outside_run(R, run, edir, s)
        elif run["kind"] == "agent":
            agent_run(R, run, edir, s)
        elif run["kind"] == "ping":
            ping_run(R, run, edir, s)
        elif run["kind"] == "multi":
            multi_rows(R, rid, meta.get("turns"), s, hook_lines(edir))
    installed_rows(R, evid)

    us = env.get("user_settings") or {}
    out = ["# qzprobe 결과 - %s" % env.get("stamp"), "",
           "- Claude Code: %s · %s · python %s" % (
               env.get("claude_version"), env.get("platform"), env.get("python")),
           "- 모델 %s · effort %s · 사용자 설정 제외(--clean): %s" % (
               env.get("model"), env.get("effort"), env.get("clean")),
           "- 시작할 때 데이터 폴더가 이미 있었나: %s" % env.get("data_existed_at_start"),
           "- 사용자 설정에서 읽은 것: defaultMode=%s · allow %s개 · ask %s개 · deny %s개 · "
           "sandbox 키 %s · disableAllHooks=%s" % (
               us.get("defaultMode"), us.get("allow_count"), us.get("ask_count"),
               us.get("deny_count"), us.get("sandbox_keys"), us.get("disableAllHooks")),
           "- 사용자 설정의 파일 · Bash 규칙: allow %s · ask %s · deny %s" % (
               us.get("allow_file_or_bash"), us.get("ask_file_or_bash"),
               us.get("deny_file_or_bash")),
           "- Claude Code 세션 안에서 돌렸나(CLAUDECODE): %s" % env.get("claudecode_env"),
           "", "## 실행", "",
           "| 실행 | 무엇 | rc | 초 | $ | 판 | 권한 모드(init) | 플러그인 실림 | 도구 호출 | 거부 |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    for o in overview:
        out.append("| %s |" % " | ".join(cell(o.get(k)) for k in (
            "run", "about", "rc", "wall_s", "cost_usd", "version", "permission_mode",
            "plugin_loaded", "tool_calls", "denied")))
    for item in (1, 2, 3, 4, 0):
        rows = [r for r in R.rows if r["item"] == item]
        if not rows:
            continue
        out += ["", "## %s" % ITEMS.get(item, "그 밖"), "",
                "| 실행 | 잰 것 | 판정 | 근거 |", "|---|---|---|---|"]
        for r in rows:
            out.append("| %s | %s | %s | %s |" % (
                cell(r["run"]), cell(r["what"]), cell(r["verdict"]), cell(r["evidence"])))
    with open(os.path.join(evid, "results.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    with open(os.path.join(evid, "results.json"), "w", encoding="utf-8") as fh:
        json.dump({"env": env, "overview": overview, "rows": R.rows}, fh,
                  ensure_ascii=False, indent=2)
    unk = sum(1 for r in R.rows if str(r["verdict"]).startswith(UNK))
    print("summary: %d rows, %d of them '%s' -> %s" % (
        len(R.rows), unk, UNK, os.path.join(evid, "results.md")))


if __name__ == "__main__":
    main()
````

#### `plugin/qzprobe/.claude-plugin/plugin.json`

````json
{
  "name": "qzprobe",
  "version": "0.0.1",
  "description": "Throwaway measurement fixture for probing Claude Code plugin devices. Not for real use.",
  "author": { "name": "qzprobe kit" },
  "userConfig": {
    "qz_token": {
      "type": "string",
      "title": "qzprobe token",
      "description": "Marker value read back by the qzprobe measurement kit",
      "default": "QZP7-CFG-DEFAULT"
    }
  }
}
````

#### `plugin/qzprobe/hooks/hooks.json`

````json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}\"/scripts/qzp-hook.sh SessionStart" }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}\"/scripts/qzp-hook.sh UserPromptSubmit" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}\"/scripts/qzp-hook.sh PreToolUse" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}\"/scripts/qzp-hook.sh Stop" }
        ]
      }
    ]
  }
}
````

#### `plugin/qzprobe/scripts/qzp.sh`

````bash
#!/bin/bash
# qzp.sh <mode> [KEY=VALUE ...]
# Probe that a skill or agent runs through the Bash tool. It records what it was
# handed (arguments, environment) and where it could write and read.
# Evidence: <cwd>/qzp-out/probe-<mode>-<n>.tsv, one KEY<TAB>VALUE per line.
# Always exits 0 so that a blocked write never aborts the caller.
set -u

MODE="${1:-none}"
[ $# -gt 0 ] && shift

CWD="$(pwd -P)"
OUT="$CWD/qzp-out"
RUN_ID="norunid"
if [ -r "$CWD/.qzp-run-id" ]; then
  RUN_ID="$(head -n 1 "$CWD/.qzp-run-id")"
fi

# Positive control: the working directory must be writable in every session.
if ! mkdir -p "$OUT" 2>/dev/null; then
  echo "QZP7-PROBE-NOOUT mode=$MODE"
  exit 0
fi

N=1
while [ -e "$OUT/probe-$MODE-$N.tsv" ]; do
  N=$((N + 1))
done
F="$OUT/probe-$MODE-$N.tsv"
TOKEN="QZP7-W-$RUN_ID-$MODE-$N"

rec() {
  # rec <key> <value> — tabs and newlines in the value become spaces
  printf '%s\t%s\n' "$1" "$(printf '%s' "$2" | tr '\n\t' '  ')" >> "$F"
}

envrec() {
  # envrec <NAME> — "set:<value>" or "unset", so empty and missing stay apart
  eval "_isset=\${$1+x}"
  if [ -n "$_isset" ]; then
    eval "_val=\${$1}"
    rec "env.$1" "set:$_val"
  else
    rec "env.$1" "unset"
  fi
}

rec "mode" "$MODE"
rec "n" "$N"
rec "run_id" "$RUN_ID"
rec "ts" "$(date +%s)"
rec "cwd" "$CWD"

ARG_ROOT=""
ARG_DATA=""
ARG_CFG=""
i=0
for a in "$@"; do
  i=$((i + 1))
  rec "argv.$i" "$a"
  case "$a" in
    QZP_ROOT=*) ARG_ROOT="${a#QZP_ROOT=}" ;;
    QZP_DATA=*) ARG_DATA="${a#QZP_DATA=}" ;;
    QZP_CFG=*) ARG_CFG="${a#QZP_CFG=}" ;;
  esac
done
rec "arg.QZP_ROOT" "$ARG_ROOT"
rec "arg.QZP_DATA" "$ARG_DATA"
rec "arg.QZP_CFG" "$ARG_CFG"

envrec CLAUDE_PLUGIN_ROOT
envrec CLAUDE_PLUGIN_DATA
envrec CLAUDE_PROJECT_DIR
envrec CLAUDE_SKILL_DIR
envrec CLAUDE_PLUGIN_OPTION_QZ_TOKEN
envrec CLAUDE_PLUGIN_OPTION_qz_token
envrec TMPDIR
# Names only (no values) of every CLAUDE*/…SANDBOX… variable this process sees.
rec "env.names" "$(env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | grep -E '^CLAUDE|SANDBOX' | sort | tr '\n' ' ')"

# Which data folder path do we know, and who told us?
DATA=""
DATA_SRC="none"
case "$ARG_DATA" in
  /*) DATA="$ARG_DATA"; DATA_SRC="arg" ;;
esac
if [ -z "$DATA" ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  DATA="$CLAUDE_PLUGIN_DATA"
  DATA_SRC="env"
fi
if [ -z "$DATA" ]; then
  DATA="$HOME/.claude/plugins/data/qzprobe-inline"
  DATA_SRC="guess"
fi
DATA="${DATA%/}"
rec "data.path" "$DATA"
rec "data.path_source" "$DATA_SRC"
if [ -d "$DATA" ]; then
  rec "data.exists_before" "yes"
else
  rec "data.exists_before" "no"
fi

try_write() {
  # try_write <label> <dir> <file>
  _label="$1"
  _dir="$2"
  _file="$3"
  rec "write.$_label.path" "$_dir/$_file"
  _e="$( { mkdir -p "$_dir"; } 2>&1 )"
  _rc=$?
  rec "write.$_label.mkdir" "rc=$_rc $_e"
  _e="$( { printf '%s\n' "$TOKEN" > "$_dir/$_file"; } 2>&1 )"
  _rc=$?
  rec "write.$_label.write" "rc=$_rc $_e"
  _back=""
  if [ -r "$_dir/$_file" ]; then
    _back="$(head -n 1 "$_dir/$_file" 2>/dev/null)"
  fi
  if [ "$_rc" -eq 0 ] && [ "$_back" = "$TOKEN" ]; then
    rec "write.$_label.verdict" "ok"
  else
    rec "write.$_label.verdict" "fail"
  fi
}

try_read() {
  # try_read <label> <file>
  _label="$1"
  _path="$2"
  rec "read.$_label.path" "$_path"
  _e="$( { head -n 1 "$_path"; } 2>&1 )"
  _rc=$?
  rec "read.$_label.result" "rc=$_rc $_e"
}

PARENT="$(dirname "$CWD")"

try_write cwd "$OUT" "pos-$MODE-$N.txt"
if [ -n "${TMPDIR:-}" ]; then
  try_write tmp "${TMPDIR%/}" "qzp-$RUN_ID-$MODE-$N.txt"
  rm -f "${TMPDIR%/}/qzp-$RUN_ID-$MODE-$N.txt" 2>/dev/null
else
  rec "write.tmp.verdict" "skipped-no-TMPDIR"
fi
try_write data "$DATA" "script-$RUN_ID-$MODE-$N.txt"
try_write outside "$PARENT/outside" "script-$MODE-$N.txt"
if [ -d "$PARENT/allowed" ]; then
  try_write allowed "$PARENT/allowed" "script-$MODE-$N.txt"
else
  rec "write.allowed.verdict" "skipped-no-dir"
fi

# Leave one stable file in the data folder for the read steps of later runs.
if [ -d "$DATA" ] && [ ! -e "$DATA/qzp-seed.txt" ]; then
  printf '%s\n' "QZP7-SEED-DATA" > "$DATA/qzp-seed.txt" 2>/dev/null
fi

try_read outside "$PARENT/outside/seed.txt"
try_read data_seed "$DATA/qzp-seed.txt"

rec "done" "yes"
echo "QZP7-PROBE-RAN mode=$MODE n=$N"
exit 0
````

#### `plugin/qzprobe/scripts/qzp-hook.sh`

````bash
#!/bin/bash
# qzp-hook.sh <event> — hook recorder for the qzprobe kit.
# Appends one line per hook run to <project>/qzp-out/hooks.tsv:
#   ts <TAB> event <TAB> key=value ...
# Prints nothing (SessionStart and UserPromptSubmit stdout would enter the context).
# Always exits 0.
set -u

EVENT="${1:-unknown}"
INPUT="$(cat 2>/dev/null || true)"

BASE="${CLAUDE_PROJECT_DIR:-$(pwd -P)}"
OUT="$BASE/qzp-out"
mkdir -p "$OUT" 2>/dev/null || exit 0

show() {
  # show <NAME> — "set:<value>" or "unset"
  eval "_isset=\${$1+x}"
  if [ -n "$_isset" ]; then
    eval "_val=\${$1}"
    printf 'set:%s' "$_val"
  else
    printf 'unset'
  fi
}

PMODE="$(printf '%s' "$INPUT" | tr '\n' ' ' | sed -n 's/.*"permission_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
DATA="${CLAUDE_PLUGIN_DATA:-}"
DATA_DIR="no"
if [ -n "$DATA" ] && [ -d "$DATA" ]; then
  DATA_DIR="yes"
fi

printf '%s\t%s\troot=%s\tdata=%s\toption=%s\tdata_dir_exists=%s\tpermission_mode=%s\n' \
  "$(date +%s)" "$EVENT" \
  "$(show CLAUDE_PLUGIN_ROOT)" "$(show CLAUDE_PLUGIN_DATA)" \
  "$(show CLAUDE_PLUGIN_OPTION_QZ_TOKEN)" "$DATA_DIR" "$PMODE" \
  >> "$OUT/hooks.tsv" 2>/dev/null

# Only in runs that ask for it: can a hook process write into the data folder?
if [ "$EVENT" = "SessionStart" ] && [ -e "$BASE/.qzp-hook-data-write" ]; then
  RUN_ID="norunid"
  if [ -r "$BASE/.qzp-run-id" ]; then
    RUN_ID="$(head -n 1 "$BASE/.qzp-run-id")"
  fi
  if [ -n "$DATA" ]; then
    _e="$( { mkdir -p "$DATA" && printf '%s\n' "QZP7-HOOKW-$RUN_ID" > "${DATA%/}/hook-$RUN_ID.txt"; } 2>&1 )"
    _rc=$?
    printf 'path=%s\trc=%s\t%s\n' "${DATA%/}/hook-$RUN_ID.txt" "$_rc" \
      "$(printf '%s' "$_e" | tr '\n\t' '  ')" >> "$OUT/hook-data-write.tsv" 2>/dev/null
  else
    printf 'path=\trc=nodata\tCLAUDE_PLUGIN_DATA is unset in the hook process\n' \
      >> "$OUT/hook-data-write.tsv" 2>/dev/null
  fi
fi

exit 0
````

#### `plugin/qzprobe/skills/qz-fence/SKILL.md`

````markdown
---
name: qz-fence
description: qzprobe measurement fixture. Runs one fixed probe command and reads one support file. Use only when the qzprobe kit invokes it by name.
disable-model-invocation: true
---

This is a measurement fixture, not a task. Do exactly the three steps below, in order, and nothing else.
If a step is denied or fails, do not retry it, do not work around it, and go on to the next step.
Never set `dangerouslyDisableSandbox`.

## Step 1

Run this command with the Bash tool, once, exactly as written here (same quotes, nothing added):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/qzp.sh" fence 'QZP_ROOT=${CLAUDE_PLUGIN_ROOT}' 'QZP_DATA=${CLAUDE_PLUGIN_DATA}' 'QZP_CFG=${user_config.qz_token}' 'QZP_SKILLDIR=${CLAUDE_SKILL_DIR}' 'QZP_PROJ=${CLAUDE_PROJECT_DIR}'
```

## Step 2

Read this file with the Read tool, once: `${CLAUDE_PLUGIN_ROOT}/skills/qz-fence/support.md`

## Step 3

Reply with exactly `QZP7-FENCE-END` and nothing else.
````

#### `plugin/qzprobe/skills/qz-fence/support.md`

````markdown
# qzprobe support file

QZP7-SUPPORT-LINE QZP_SUP_ROOT=${CLAUDE_PLUGIN_ROOT} QZP_SUP_DATA=${CLAUDE_PLUGIN_DATA} QZP_SUP_CFG=${user_config.qz_token}

This file carries no instruction. Reading it once is all that is needed.
````

#### `plugin/qzprobe/skills/qz-inject/SKILL.md`

````markdown
---
name: qz-inject
description: qzprobe measurement fixture. Carries one pre-executed shell line. Use only when the qzprobe kit invokes it by name.
disable-model-invocation: true
allowed-tools: Bash(bash *)
---

This is a measurement fixture, not a task. The text between the two marker lines below was filled in before you saw it.

QZP7-INJECT-BEGIN
!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/qzp.sh" inject 'QZP_ROOT=${CLAUDE_PLUGIN_ROOT}' 'QZP_DATA=${CLAUDE_PLUGIN_DATA}' 'QZP_CFG=${user_config.qz_token}' 'QZP_SKILLDIR=${CLAUDE_SKILL_DIR}' 'QZP_PROJ=${CLAUDE_PROJECT_DIR}'`
QZP7-INJECT-END

Do not call any tool. Reply with exactly `QZP7-INJECT-SAW: ` followed by the text you see between the two marker lines, copied character for character.
````

#### `plugin/qzprobe/skills/qz-outside/SKILL.md`

````markdown
---
name: qz-outside
description: qzprobe measurement fixture. Tries nine fixed reads and writes inside and outside the working directory. Use only when the qzprobe kit invokes it by name.
disable-model-invocation: true
argument-hint: <outside-dir> <run-id>
---

This is a measurement fixture, not a task. Do the nine steps below in order, one tool call per step, and nothing else.
Every step is independent: if a step is denied or fails, do not retry it, do not work around it, do not ask, and go on to the next step.
Never set `dangerouslyDisableSandbox`. Use the exact tool each step names.

1. Read tool: read the file `$0/seed.txt`
2. Write tool: create the file `$0/tool-write.txt` with the single line `QZP7-TOOLWRITE-$1`
3. Bash tool: run exactly `cat "$0/seed.txt"`
4. Bash tool: run exactly `printf 'QZP7-REDIRECT-$1\n' > "$0/bash-redirect.txt"`
5. Read tool: read the file `${CLAUDE_PLUGIN_DATA}/qzp-seed.txt`
6. Write tool: create the file `${CLAUDE_PLUGIN_DATA}/tool-write-$1.txt` with the single line `QZP7-DATAWRITE-$1`
7. Bash tool: run exactly `bash "${CLAUDE_PLUGIN_ROOT}/scripts/qzp.sh" outside 'QZP_ROOT=${CLAUDE_PLUGIN_ROOT}' 'QZP_DATA=${CLAUDE_PLUGIN_DATA}' 'QZP_CFG=${user_config.qz_token}'`
8. Write tool: create the file `qzp-out/tool-write-cwd.txt` in the current working directory with the single line `QZP7-CWDWRITE-$1`
9. Read tool: read the file `${CLAUDE_PLUGIN_ROOT}/skills/qz-fence/support.md`

Then reply with exactly `QZP7-OUTSIDE-END` and nothing else.
````

#### `plugin/qzprobe/skills/qz-agent/SKILL.md`

````markdown
---
name: qz-agent
description: qzprobe measurement fixture. Starts one fixed subagent and relays its report. Use only when the qzprobe kit invokes it by name.
disable-model-invocation: true
argument-hint: <outside-dir> <run-id>
---

This is a measurement fixture, not a task. Do exactly the two steps below and nothing else.
If a step is denied or fails, do not retry it and do not work around it.

1. Use the Agent tool once to start the subagent `qzprobe:qz-reader` (subagent type `qzprobe:qz-reader`), in the foreground, with exactly this prompt: `QZP7-AGENT-GO $0 $1`
2. When it returns, reply with exactly `QZP7-AGENT-RELAY ` followed by the subagent's final message, unchanged. If step 1 did not run, reply with exactly `QZP7-AGENT-RELAY NOT-STARTED`.
````

#### `plugin/qzprobe/skills/qz-ping/SKILL.md`

````markdown
---
name: qz-ping
description: qzprobe measurement fixture. Answers with one fixed token. Use only when the qzprobe kit invokes it by name.
disable-model-invocation: true
---

This is a measurement fixture, not a task. Do not call any tool. Reply with exactly `QZP7-PING-58213` and nothing else.
````

#### `plugin/qzprobe/agents/qz-reader.md`

````markdown
---
name: qz-reader
description: qzprobe measurement fixture agent. Reads fixed files and reports one line. Use only when the qz-agent skill asks for it by name.
tools: Read, Bash
---

You are a measurement fixture, not an assistant with a task. Your prompt has the form `QZP7-AGENT-GO <outside-dir> <run-id>`.
Do the four steps below in order, one tool call per step, and nothing else.
Every step is independent: if a step is denied or fails, do not retry it, do not work around it, and go on to the next step.
Never set `dangerouslyDisableSandbox`. Use the exact tool each step names.

QZP7-AGENT-LINE QZP_AG_ROOT=${CLAUDE_PLUGIN_ROOT} QZP_AG_DATA=${CLAUDE_PLUGIN_DATA} QZP_AG_CFG=${user_config.qz_token}

1. Read tool: read the file `<outside-dir>/seed.txt`
2. Read tool: read the file `${CLAUDE_PLUGIN_DATA}/qzp-seed.txt`
3. Bash tool: run exactly `cat "${CLAUDE_PLUGIN_DATA}/qzp-seed.txt"`
4. Bash tool: run exactly `bash "${CLAUDE_PLUGIN_ROOT}/scripts/qzp.sh" agent 'QZP_ROOT=${CLAUDE_PLUGIN_ROOT}' 'QZP_DATA=${CLAUDE_PLUGIN_DATA}' 'QZP_CFG=${user_config.qz_token}'`

Your final message is exactly one line, built from what you observed:

`QZP7-AGENT-REPORT line=<the QZP7-AGENT-LINE line above, copied character for character> | s1=<first line you read, or DENIED, or ERROR> | s2=<same> | s3=<first line of output, or DENIED, or ERROR> | s4=<last line of output, or DENIED, or ERROR>`
````

## 옛 기록과 달라진 것

| # | 옛 기록 | 지금 확인한 것 | 처분 |
|---|---|---|---|
| 1 | 묶음 P1.md «cc-plugins-reference»(확인 2026-11-14): 설정 값이 「Bash 로 도는 스크립트에 환경변수로 실린다는 문장은 없다」 | 플러그인 경로 변수 셋에 대해서는 닿지 않는다는 문장이 있다 — 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 (https://code.claude.com/docs/en/plugins/manifest-reference). 설정 값의 환경변수(`CLAUDE_PLUGIN_OPTION_<KEY>`)는 「exported to hook processes」 로만 적혀 있어 묶음의 읽기와 같다 | 행 3-8 · 3-9 가 잰다 |
| 2 | 인터뷰 기록의 「확인하지 못한 것」: `enabledPlugins` 를 `--settings` 로 한 번 실행에만 덮을 수 있는지 | 문서가 적는다 — `enabledPlugins` 를 둘 수 있는 자리 표의 `flag` 행: 「The `--settings` value you pass at launch」 · 「This session only」 (https://code.claude.com/docs/en/plugins/loading) | 행 4-1 이 잰다. 진입 skill 을 한 번 실행에만 끄는 길의 후보다 |
| 3 | 묶음 P1.md «cc-sandboxing»: 샌드박스의 기본 쓰기 자리와 보호 경로 | 그대로다. 묶음에 없던 것 하나 — 샌드박스 안 명령의 자동 허용이 기본으로 꺼졌다(문서는 2.1.324, changelog 는 2.1.325). 샌드박스를 켜기만 한 세션에서는 Bash 명령이 다시 권한 판정을 탄다 | 행 2-6 이 잰다. 도구는 `autoAllowBashIfSandboxed` 를 밝혀서 건다 |
| 4 | 묶음 P1.md «cc-plugins-loading»: 「설정이나 디스크의 변경은 다시 불러오기 명령이나 새 세션 뒤에 닿는다」 | 그대로다. 더해진 것 — `/reload-plugins` 는 화면 없는 세션에서도 돈다(2.1.260 부터), 다만 「only when you type it into the session yourself」 (https://code.claude.com/docs/en/plugins/cli-reference) | 행 4-3 · 4-4 가 잰다 |
| 5 | 인터뷰 조사 14: 「Bash 에서 그 폴더 아래에 쓰는 쓰기가 성공했다」 — 샌드박스를 켜지 않은 세션의 값 | 다시 재지 않았다 | 행 1-1 이 다시 잰다 |
| 6 | 격리 설정 폴더(2026-10-09, 판 2.1.294): 내장 마켓플레이스 하나는 보인다 · 로그인이 없다 · `claude auth login` 은 된다 | 다시 재지 않았다 | 옛 기록 — 다시 확인 필요. 도구는 이 길을 쓰지 않는다 |
| 7 | 어제 실측(2026-11-14, 판 2.1.325): `--plugin-dir` 로 실은 플러그인의 skill 이 화면 없는 실행에서 슬래시로 돈다 · 묻는 도구가 없다 · 권한 모드를 주지 않으면 기계마다 갈린다 · 거부는 rc 가 아니라 스트림에 남는다 · 실행당 약 $0.13 | 전제로 썼다. 옵션 이름은 `claude --help` 로 다시 확인했다. 어제 쓴 `--max-turns` 는 도움말에 없어서 쓰지 않고 `--max-budget-usd` 로 상한을 건다 | 도구의 전제 |
| 8 | 어제 실측: 이 기계의 화면 없는 실행은 권한 플래그가 없으면 auto 로 시작한다 | 문서는 「In Claude Code v2.1.302 or later, `claude -p` and Agent SDK runs with no permission mode set start in Manual mode.」 라 적는다. 어긋나지 않는다 — 사용자 설정의 `defaultMode` 가 내장 기본값보다 먼저다(permission-modes 「Which mode a session starts in」) | 도구는 실행마다 모드를 밝힌다 |
| 9 | 묶음 P1.md RC273: 레포가 적어 둔 Claude Code 판은 2.1.303 | 지금 깔린 판은 2.1.325 다. F7 이 쓰려는 장치의 판은 «장치마다 필요한 판» 에 있다 | OQ38 의 재료 |

## 재지 못하는 것

- 대화형 화면에서만 보이는 것 — 권한 창의 선택지, `/plugin` 화면, 설정 값 받기 창. 화면 없는 실행은 「물었을 자리」 를 거부로만 보인다.
- macOS 밖 — 샌드박스는 Linux · WSL2 에서 bubblewrap 으로 돈다. 문서는 Linux 에서 「an entry for a path that doesn't exist yet has no effect」 라 적는다. 이 도구는 돌린 기계의 값만 낸다.
- 샌드박스에 막힌 명령을 샌드박스 밖에서 다시 돌리는 길 — 도구는 이 길을 막고 잰다. 누가 승인하는지는 문서의 표로만 안다(manual · acceptEdits 는 묻고, auto 는 분류기가 보고, dontAsk 는 거부한다).
- 모델에 따라 달라지는 것 — 시험용 skill 은 정해진 걸음만 밟게 썼지만 sonnet · effort medium 에서만 잰다. 걸음을 건너뛴 실행은 「재지 못함」 으로 나온다.
- 캐시에 복사된 설치본 — «선택 단계 설치본 끄기» 에 적었다.
- 조직 관리 설정(managed settings)이 걸린 기계.
- 설정 값 가운데 감춰야 하는 값(`sensitive`)과 `/config` 화면.

## 있는 것 검토

| 수단 | 자리 | 지금 확인한 것 | 이 조사에 쓰나 |
|---|---|---|---|
| 데이터 폴더 변수를 쓰는 레포 코드 | `plugins/` · `shared/` · `tools/` | `CLAUDE_PLUGIN_DATA` 가 0건이다(git grep) — RC274 그대로 | 없다 |
| 치환에 대한 레포의 전제 | `plugins/spec-distill/skills/pm-interview/SKILL.md` 56행 · 109행 | 펜스는 `SD="${CLAUDE_PLUGIN_ROOT}"` 의 글자 치환에 기대고, Read 로 여는 파일에 대해서는 「그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다」 고 적는다 — RC276 그대로 | 행 3-1 · 3-5 가 이 전제를 잰다 |
| 훅 실측 기록 | `shared/tests/fixtures/hookprobe/MEASUREMENT.md` · `shared/tests/fixtures/seamprobe/MEASUREMENT.md` | 훅 이벤트와 payload 를 잰 기록이다(2026-08-22, 판 2.1.239). 데이터 폴더 · 설정 값 · 샌드박스 · 플러그인 끄기는 재지 않았다 | 아니다 |
| 어제의 화면 없는 실행 실측 | 다른 로드맵의 지휘 폴더(추적되지 않는 파일) | 판 2.1.325, 실행 10회. 재는 방법(새 빈 폴더 · 권한 모드 명시 · 스트림에서 거부 읽기)을 그대로 따랐다 | 방법의 전제로 쓴다 |
| 공식 검증 명령 | `claude plugin validate <폴더>` | 시험용 플러그인이 통과한다. 설정을 바꾸지 않는다 | 도구를 만든 뒤 한 번 |

## 번호 대조

| 번호 | 반영/기각 | 자리 또는 이유 |
|---|---|---|
| D21 | 반영 | «무엇을 왜 재는가» — 옮길 대상(데이터 폴더 · 설정 값 · 플러그인 끄기)을 잰다. 옮기는 일은 F7 |
| D31 | 반영 | 실측 표 항목 1 — 샌드박스를 켠 세션에서 잰다(1-2 · 1-3 · 1-4 · 1-5) |
| D35 | 반영 | 실측 표 항목 2 — 작업 폴더 밖 읽기 · 쓰기의 승인과 하위 agent 의 읽기 |
| OQ12 | 기각(해결됨) | 방향은 사용자가 유지로 정했다(S13). 이 문서는 그 방향에 쓸 사실만 낸다 |
| OQ32 | 기각(F7) | 스위치 · 상태 파일마다의 처분은 F7 이 정한다. 재료는 실측 표 전체와 «문서 11» · «문서 13» |
| OQ37 | 기각(F7) | 막힐 때의 길은 F7 이 정한다. 재료는 행 1-2 – 1-5(쓰기 허용 설정 · 폴더 더하기 · 훅 프로세스) |
| OQ38 | 기각(F7) | 최소 판을 강제할지는 F7 이 정한다. 재료는 «장치마다 필요한 판» |
| OQ39 | 기각(해결됨) | 로드맵을 가르지 않기로 한 결정이다(S38). 조사의 범위 밖 |
| RC273 | 반영 | 문서에서 확인한 것 «장치마다 필요한 판» 의 끝 문단 · «옛 기록과 달라진 것» 9 |
| RC274 | 반영 | «있는 것 검토» 첫 행 — 지금 코드에서 다시 확인했다 |
| RC275 | 반영 | 실측 표 행 3-3 · 3-7 — 시험용 플러그인이 `userConfig` 를 선언해 잰다. 네 플러그인의 manifest 는 건드리지 않는다 |
| RC276 | 반영 | «있는 것 검토» 둘째 행 · 실측 표 행 3-1 · 3-5 |
| K10 | 반영 | 실측 표 항목 1 |
| K11 | 반영 | 실측 표 행 3-8 · 3-9 · 문서에서 확인한 것 «문서 2» · «문서 4» |
| S1 | 반영 | 문서에서 확인한 것 · 실측 표 — seed 의 「공식 자료와의 대조는 하지 않았다.」 를 이 에픽의 범위에서 메운다. 공식 자료는 기준이 아니라 참고 내용으로 읽는다 |
| S13 | 반영 | 무엇을 왜 재는가 — 「유지」: 방향을 다시 묻지 않고 사실만 잰다 |
| S27 | 반영 | 실측 표 항목 1 — 「설계 첫 걸음에서 샌드박스를 켠 세션으로 재고」 |
| S30 | 반영 | 실측 표 · 문서에서 확인한 것 — 「빈 곳 여덟은 「설계가 먼저 볼 것」으로 싣고」 가운데 이 에픽 몫(샌드박스 쓰기 · 설정 값이 닿는 길 · 최소 판) |
| S33 | 반영 | 실측 표 항목 2 — 「실측을 샌드박스 쓰기에서 작업 폴더 밖 읽기 · 쓰기 승인과 하위 agent 의 읽기까지 넓힌다」 |
| S38 | 기각(범위 밖) | 로드맵 구성에 대한 결정이다 |
| «cc-hooks» | 반영 | 문서에서 확인한 것 «문서 13» · 실측 표 행 4-5 |
| «cc-plugins-cli» | 반영 | 문서에서 확인한 것 «문서 11» · «문서 16» · 실측 표 행 4-6 |
| «cc-plugins-loading» | 반영 | 문서에서 확인한 것 «문서 12» · 실측 표 행 4-3 · 4-4 · «옛 기록과 달라진 것» 4 |
| «cc-plugins-reference» | 반영 | 문서에서 확인한 것 «문서 2» · «문서 4» · «옛 기록과 달라진 것» 1 |
| «cc-sandboxing» | 반영 | 문서에서 확인한 것 «문서 5» · «문서 6» · 실측 표 항목 1 · «옛 기록과 달라진 것» 3 |
| «cc-settings» | 반영 | 문서에서 확인한 것 «문서 7» · 재는 방법 — 도구가 실행마다 `--settings <파일>` 로만 설정을 건다 |
