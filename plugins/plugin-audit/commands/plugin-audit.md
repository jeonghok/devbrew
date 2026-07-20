---
description: "Read-only multi-agent audit of a devbrew plugin (6-axis discovery → adversarial refute → codex co-audit → gap report). Usage: /plugin-audit <target> [--seed <path>]."
argument-hint: "<target> [--seed <path>]"
---

# plugin-audit

`$ARGUMENTS`를 파싱한다: 첫 토큰 = `<target>` 플러그인 이름, optional `--seed <path>`.

**바로 `auditing-plugins` skill을 invoke한다.** skill이 지출 동의 게이트(cost_class: high)·pre-0
정적 게이트·Workflow·post-1 조립을 소유한다. 이 command는 인자 파싱과 skill 진입만 담당하는
얇은 진입점이다 (오케스트레이션 로직을 여기 복제하지 않는다).

- `<target>`이 비었으면: "감사할 플러그인 이름이 필요합니다 — `/plugin-audit <target>`"로 안내하고 중단.
- 그 외: `Skill(auditing-plugins)`를 target·seedPath 인자와 함께 호출.
