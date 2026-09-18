## seed 를 입력으로 받았을 때

`$ARGUMENTS` 가 `type: interview-seed` frontmatter 를 가진 문서면, 그것은 **Phase 0 에서
사용자가 확정한 메시지**다. Phase 0 은 사용자에게 `/interview @<seed 경로>` 를 치게 하고,
`/interview` 가 그 파일을 전문(frontmatter 포함)으로 풀어 이 skill 에 넘긴다(그 호출 모양의 정본은
`framing-requests` 의 「호출 모양」 절이다). 그 frontmatter 줄이 seed 를 알아보는 유일한 표지다 —
본문만 오면 seed 로 인식되지 않아 아래 규약이 발동하지 않는다.

- **§6 `S1` 은 `$ARGUMENTS` 원문 그대로다**(frontmatter 포함) — `finishing.md` 의 S1
  규약과 같은 값이다. 그것이 이 세션의 최초 사용자 발화다.
- **seed 의 마지막 문단 «다시 검증할 것 —»** 은 R1 의 «지금 이해»·질문의 재료이자 coverage-mapper 첫
  dispatch 의 입력이다. 문단이 없으면 seed 본문 전체를 그 입력으로 쓰되 무표시 문장은 전부 미확인이다.
- **seed 에는 태그가 없다.** seed 게이트가 막는 `[open:`/`[추론:`/`[외부:` 구분을 seed 에서 읽으려
  하지 말 것. 출처와 확인은 산문 표시 «(사용자 확인)» 과 audit 원문 대조로 가른다(아래 둘).
- **출처와 확인은 다른 축이다.** seed 의 문장은 누가 썼는가(출처)와 사용자가 확인했는가(확인)로 따로
  가른다:

  | seed 의 문장 | 출처 | 확인 |
  |---|---|---|
  | 사용자 발화를 그대로 옮긴 것 | 사용자 | 표시가 있으면 확인, 없으면 미확인 |
  | 저자가 풀어 쓴 것에 «(사용자 확인)» 이 붙은 것 | 사용자(확인으로 획득) | 확인 |
  | 그 밖의 저자 문장(«다시 검증할 것 —» 문단 포함) | Phase 0 저자 | 미확인 |

  셋째 줄은 brief §2 의 `user_sourced_items` 에 넣지 않는다. 첫째 줄은 사용자 출처로 넣되 확인 표시가
  없으면 재확인 대상이다 — 출처가 사용자여도 확인 표시가 없으면 묻는다. 출처는 **상태**(status)가 아니다 —
  `status` 는 하류 규약대로 전부 `provisional` 로 시작하고, `confirmed` 로의 전이는 오직 Step B-0 사용자
  확인에서만 일어난다.
- **가르는 것은 기계다.** `/interview` 가 인터뷰 진입 전에 낸 한 줄
  `[spec-distill] seed 원문 대조: seed=<seed 절대경로> · audit=<audit 절대경로>` 의 두 경로로 아래 펜스를
  돌려 문장마다 출처 · 확인을 받는다. 그 줄이 없으면(붙여넣기) 펜스를 돌리지 않고 전부 저자 · 미확인으로
  둔다 — `classify` 의 필수 인자 `seed` 가 파일 경로라 붙여넣은 텍스트로는 채울 수 없다(임시 파일을 만들어
  우회하지 않는다). `audit=없음(…)` 이면 `--audit` 을 빼고 돌린다 — 분류기가 전부 저자 · 미확인으로
  떨어뜨리고 `audit: unavailable` 을 낸다. `--audit` 을 넘겼어도 분류기가 `unavailable: …` 을 내면 같다 —
  전부 저자 · 미확인으로 둔다. 펜스가 0 이 아닌 rc 로 끝나거나 JSON 을 못 내면(예: seed 파일이 실행 사이에
  이동함) 그 출력을 그대로 R1 에 싣고 손으로 출처를 판정하지 않는다 — 이 경우도 전부 저자 · 미확인으로
  둔다. 그 사실과 `unavailable:` 사유를 R1 «지금 이해»에 한 줄로 밝힌다(침묵하지 않는다). seed
  frontmatter 의 `audit_file:` 은 따라가지 않는다. 문장에 겉보기 «(사용자 확인)» 표시가 있어도 분류기
  판정의 `basis` 가 `mark_invalid` 면 미확인이다 — 분류기 판정이 표시를 이긴다; `provenance: user` +
  `confirmed: false` 행이 재확인 대상이다.
- **seed 를 뒤집을 수 있다**(P23). 인터뷰 중 사용자가 seed 의 확정을 뒤집으면 **새 발화가
  이긴다** — 그리고 그 뒤집음을 **audit §6** 에 새 `S<N>` 으로 추가하고(payload §6은 `S1`
  으로 불변이므로 새 앵커는 audit에만 붙는다) §5 `기각` 에 *원래 / 재결정 / 근거* 로 남긴다.
  조용히 덮어쓰지 않는다.
- **seed 가 아닌 입력도 그대로 받는다.** `/interview` 는 호환을 유지한다 — 조언 한 줄을
  내되 **차단하지 않는다**.

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
python3 "$SD/scripts/seed_provenance.py" classify "<seed 절대경로>" --audit "<audit 절대경로>"
```
