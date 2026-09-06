#!/usr/bin/env bash
# codex-stub.sh — 락 test_docreview_codex.sh 전용 가짜 codex. 실제 codex 는 절대 부르지
# 않는다(락 규약) — 이 스텁이 그 자리를 대신해 배선(프로필 rubric 침투 · 웹 인자 · keyset
# 변환)을 잰다.
#
# argv 는 `$DOCREVIEW_CODEX_ARGV_FILE`(웹 인자 검사용)에, stdin(조립된 프롬프트 전체)은
# `$DOCREVIEW_CODEX_CAPTURE`(프로필 rubric 침투 검사용)에 저장한 뒤 고정 JSONL 한 줄을
# 낸다. 둘 다 **파일로** 남기는 이유는 stderr 로만 내면 안 되기 때문이다 — 러너
# (run_docreview_codex_reviewer.sh)가 `codex exec ... 2>"$STDERR_FILE"` 로 codex 의
# stdout·stderr 를 전부 스크래치 디렉토리 파일로 가두고 그 디렉토리를 종료 시 지운다.
# 즉 이 스텁이 자기 stderr 에 argv 를 적어도 그것은 러너 자신의 stderr 로 전달되지
# 않는다(실측 — 처음엔 stderr 로만 냈다가 락에서 항상 빈 문자열을 읽어 P11 양성 대조가
# false negative 로 RED 였다). 그래서 호출자가 지정한 파일 경로로 직접 쓴다.
if [ -n "${DOCREVIEW_CODEX_ARGV_FILE:-}" ]; then
  printf '%s\n' "$*" > "$DOCREVIEW_CODEX_ARGV_FILE"
fi
if [ -n "${DOCREVIEW_CODEX_CAPTURE:-}" ]; then
  cat > "$DOCREVIEW_CODEX_CAPTURE"
else
  cat > /dev/null
fi
cat <<'J'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\":[{\"ref\":\"x1\",\"layer\":1,\"category\":\"goal_fit\",\"anchor\":\"#2-goals\",\"disposition\":\"decide\",\"summary\":\"stub\",\"edit_scope\":\"#2-goals\",\"blocks\":[],\"evidence\":\"e\"}]}\n```"}}
J
