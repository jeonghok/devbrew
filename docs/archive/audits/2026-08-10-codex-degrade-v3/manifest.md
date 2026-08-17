# V3 — degrade 실동작 (문구 grep은 필요조건, 이 실행이 충분조건)

- 대상 커밋: `d8b22778eb8cc33bf154b312b63136d5b684f010`
- 실행일: 2026-08-10
- 실제 codex 호출: **0회** — 방법은 아래 "codex 호출 0회 확인 방법" 절.

## Step 1 — 관측된 6경로

| 경로 | 관측된 skip_reason / meta | 배너 문구 문서화 | 브리프 예측과 일치? |
|---|---|---|---|
| kill switch | `skip_reason: kill_switch` | silent (설계상) — **재확인**: `scripts/`·`hooks/` 전체에 skip_reason 분기 배너 코드 0건(grep), `test_skill_codex_skip_prose.sh`의 AC20이 SKILL.md에 kill_switch용 actionable 문구가 없음을 PASS로 확정 | 일치 |
| 미설치 | `skip_reason: not_installed` | ✓ 문서에 있음 | 일치 |
| auth 실패 | `skip_reason: auth_missing` | ✓ 문서에 있음 | 일치 |
| 버전 바닥 미달 | `skip_reason: version_below_floor` / `detected_version: codex-cli 0.117.0` / `required_version: 0.118.0` | ✓ 문서에 있음 | 일치 — **Task 2 신설 경로, 이 실행이 사이클 최초 end-to-end 실행** |
| 버전 판독 불가 | `skip_reason: version_unreadable` / `detected_version: codex-cli (dev build)` | ✓ 문서에 있음 | 일치 — **Task 2 신설 경로, 이 실행이 사이클 최초 end-to-end 실행** |
| 추출기 실패(러너 자신의 degrade) | `codex_failed: true` / `exit_code: 0` / `reason: extract_failed` + stderr: `[quality-gates] codex 추출 실패 — 빈 산출물 대신 codex_failed를 기록한다 (리뷰어 1명 손실, degrade)` | ✓ (결과 판정 절차, SKILL.md `#### codex 결과 판정`) | 일치 |

6경로 전부 브리프 예측과 **완전히 일치**했다. 특히 Task 2가 새로 만든 두 경로
(`version_below_floor`·`version_unreadable`)도 이 사이클에서 처음 end-to-end로
태워졌는데 편차 없이 예측대로 나왔다 — 보고할 발견(finding)은 없다.

### codex 호출 0회 확인 방법

- (1)·(2): `command -v codex`를 `PATH="$V3/bin:/usr/bin:/bin"`(실제 `codex`가 있는
  `/opt/homebrew/bin` 미포함)로 직접 질의해 `NONE`을 확인. (1) kill switch는 이 확인과
  별개로 `emit_skip 'kill_switch'`가 `command -v codex` 호출보다 앞에서 조기 반환하므로
  코드 경로상 도달 자체가 불가능(`detect_codex.sh:12-15`) — PATH 제한과 이중으로 막았다.
- (3)~(5): PATH 최상단에 얹은 `codex`는 devbrew 리포 자체의 정적 bash mock
  (`tests/mocks/{safe-v1,below-floor,unreadable-version}/codex`) — 소스를 직접 읽어
  `--version`에 리터럴 문자열을 echo할 뿐 네트워크 호출이 없음을 확인했다.
- (6): PATH 최상단의 `codex`는 `tests/mocks/capture-codex/codex` — argv/stdin을
  파일로 캡처하고 고정 JSONL을 echo하는 정적 mock(소스 확인, 네트워크 호출 없음).
  게다가 이 서브스텝의 `PATH="$V3/bin:/usr/bin:/bin"` 자체가 `/opt/homebrew/bin`을
  포함하지 않으므로 실제 `codex` 바이너리는 애초에 PATH상에서 보이지 않는다.

## Step 2 — 배너 대조 (grep, 6종)

`not_installed` · `auth_missing` · `timeout_binary_missing` · `known_bad_version` ·
`version_below_floor` · `version_unreadable` — 전부 `문서에 있음`.

## Step 3 — 최종 baseline

측정 커밋: `d8b22778eb8cc33bf154b312b63136d5b684f010` / 2026-08-10

```
TOTAL 139
RED 2
RED plugins/quality-gates/tests/test_consent_marker_write_failure.sh
RED plugins/quality-gates/tests/test_security_reviewer_kill_switch.sh
```

python: spec-distill `Ran 202 tests ... OK (skipped=1)`, plugin-audit 전 파일 RED 0
(정상 실행 시 아무 것도 출력하지 않는 루프이므로 무출력이 곧 전부 통과).

남는 RED 2건(`test_consent_marker_write_failure.sh`, `test_security_reviewer_kill_switch.sh`)은
codex 무관 pre-existing이며 fingerprint 원장에 등재돼 있어 `test_codex_backward_compat.sh`는
**GREEN**이다 — 브리프의 "Expected: RED 2" 예측과 일치.

## 브리프 대비 관측된 편차 (조정하지 않고 기록)

- 브리프 self-review는 "늘어난 테스트 수(신규 7개)만큼 TOTAL도 올라간다"고 적었다.
  실측: 시작 baseline(TOTAL 133, commit `c3aeacc`)과 이번 측정(TOTAL 139, commit
  `d8b2277`)의 `git diff --name-status c3aeacc..HEAD -- 'plugins/*/tests/test_*.sh'`
  결과는 **추가 6개, 삭제 0개**다 — `test_codex_copies_agree.sh`,
  `test_codex_extractor_positive_marker.sh`, `test_codex_gate_observation.sh`,
  `test_codex_invocation_contract.sh`, `test_codex_prompt_untrusted_clause.sh`,
  `test_codex_result_banner.sh`. 브리프는 7이라 적었으나 실제는 6이다.
- 태스크 지시문의 독립 카운트("136 pass / 2 fail", 총 138)와 이 실행의 측정
  (TOTAL 139, RED 2 → PASS 137)이 총 1건 어긋난다. 원인을 추정해 조정하지 않고
  그대로 기록한다 — RED 2건의 신원(어느 두 파일이 RED인지)은 정확히 일치하므로
  degrade 판정 자체에는 영향이 없다.

실제 codex 호출 0회 — 전부 mock으로 재현했다.
