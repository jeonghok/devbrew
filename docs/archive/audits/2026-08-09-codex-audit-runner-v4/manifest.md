# V4 — plugin-audit codex 러너 실동작 (1단계 게이트)

- 대상 커밋: `2493a0a916f134d66672942d96f8ff79f24cc314`
- codex: `codex-cli 0.145.0`
- 실제 codex 호출: **1회** (상태 (3) 만. (1)·(2)는 codex 에 도달하지 않는다)
- 러너 sha256: `10c32bbdc044bb7ab558581ec43af8e4466d913fb50b7bbd2ab0148f9689502b`
- 추출기 sha256: `54e497d7f1f0c7948e94a02f7532a79920128912e0427e873bf3f1b327f1148c`
- detect sha256: `15d430c9d821db70c0aff5c66a01c727aea01062eea590fd8e0ddbbd0ff1b5d1`

이 manifest 의 해시가 현재 소스와 다르면 이 증거는 **stale** 이다.

## 판정

| 상태 | 관측 | 판정 |
|---|---|---|
| 미실행(kill switch) | `codex_available: false` · `skip_reason: kill_switch` | PASS |
| 실행-실패 | `rc=0` · `meta.codex_failed: true` · `reason: axis_file_missing` | PASS |
| 실행-성공 | `rc=0` · `meta.codex_failed: false` · 네 키 전부 존재 · `findings` 는 list | PASS |
| assemble 소비 | `assemble rc=0` · `meta.codex = {ran: true, failed: false}` · **B7 거짓 RED 없음** | PASS |

assemble 검증에서 `validate-audit-data.py` 는 exit 1 을 냈으나 그 사유는
`meta.consent.approved != true` · `meta.consent.at 없음` 둘뿐이다 — 이 probe 가
합성한 최소 `meta.json` 에 consent 블록을 넣지 않았기 때문이고, B7 계열 오류는
**0건**이다. V4 가 재려던 축(실행-실패에 B7 거짓 RED가 나지 않는가)은 통과했다.

## 보존하지 않는 것 (P21)

원시 프롬프트와 JSONL 전문은 남기지 않는다. 남기는 것은 위 해시·판정과
아래 `meta:` 블록뿐이다.
