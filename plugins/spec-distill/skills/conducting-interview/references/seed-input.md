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
- **seed 에는 태그가 없다.** seed 게이트가 막는 `[open:`/`[추론:`/`[외부:` 구분을 seed
  에서 읽으려 하지 말 것 — Phase 0 이 전문을 사용자 확정으로 만들었으므로 전부 사용자
  **출처**(provenance)다. 이것은 출처일 뿐 **상태**(status)가 아니다 — `status` 는
  하류 규약대로 전부 `provisional` 로 시작하고, `confirmed` 로의 전이는 오직 Step B-0
  사용자 확인에서만 일어난다.
- **seed 를 뒤집을 수 있다**(P23). 인터뷰 중 사용자가 seed 의 확정을 뒤집으면 **새 발화가
  이긴다** — 그리고 그 뒤집음을 **audit §6** 에 새 `S<N>` 으로 추가하고(payload §6은 `S1`
  으로 불변이므로 새 앵커는 audit에만 붙는다) §5 `기각` 에 *원래 / 재결정 / 근거* 로 남긴다.
  조용히 덮어쓰지 않는다.
- **seed 가 아닌 입력도 그대로 받는다.** `/interview` 는 호환을 유지한다 — 조언 한 줄을
  내되 **차단하지 않는다**.
