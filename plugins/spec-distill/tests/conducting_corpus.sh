#!/usr/bin/env bash
# 테스트 도우미 — 지휘 지시서(차례 `references/conducting.md` 와 차례가 이름 붙인 파일)를 테스트가 읽는 꼴로 낸다.
# 셸 테스트가 assert.sh 다음에 `. "$ROOT/plugins/spec-distill/tests/conducting_corpus.sh"` 로 읽는다($ROOT 필요).
# 파일 목록은 `scripts/conductor_toc.py files --kind …` 가 정한다 — 읽어 들일 때 이 셸에서 한 번 읽고(실패는 `no` 로 센다),
# 뒤의 함수는 그 값을 낸다(명령 치환 안에서 부른 `no` 는 셈이 사라지므로).
#   cd_files [all|step|extra|manual]  — 절대경로 한 줄씩(all 은 차례가 맨 앞)
#   cd_all                            — cd_files all 의 파일을 차례대로 이은 글
#   cd_loop                           — 차례의 `## 지휘 순환` 절 + 걸음 지시서 일곱 + 끊고 잇기 지시서
#   cd_manual_file · cd_team_file · cd_resume_file — 그 파일의 절대경로

_CD_TOC_PY="$ROOT/plugins/spec-distill/scripts/conductor_toc.py"

_cd_read() {  # _cd_read <kind> — conductor_toc.py files 의 출력. 실패 · 빈 출력이면 rc 1
  local out rc
  out="$(python3 "$_CD_TOC_PY" files --kind "$1" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ -n "$out" ] || { printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out"
}

for _cd_k in all step extra manual; do
  if _cd_out="$(_cd_read "$_cd_k")"; then
    eval "_CD_FILES_${_cd_k}=\"\$_cd_out\""
  else
    no "차례를 읽지 못했다 — ${_cd_out}"
    eval "_CD_FILES_${_cd_k}=''"
  fi
done
unset _cd_k _cd_out

cd_files() {  # cd_files [all|step|extra|manual]
  local k="${1:-all}" v
  case "$k" in all|step|extra|manual) ;; *) no "cd_files: 모르는 종류 — $k"; return 1 ;; esac
  eval "v=\"\$_CD_FILES_${k}\""
  if [ -z "$v" ]; then
    no "차례를 읽지 못했다 — $(_cd_read "$k")"
    return 1
  fi
  printf '%s\n' "$v"
}

_cd_named() {  # _cd_named <kind> <파일 이름> — 그 종류 목록에서 이름이 같은 경로 하나
  cd_files "$1" | while IFS= read -r p; do [ "${p##*/}" = "$2" ] && printf '%s\n' "$p"; done
}

cd_all() {
  cd_files all | while IFS= read -r p; do cat "$p"; done
}

cd_loop() {
  local toc
  toc="$(cd_files all | head -1)"
  awk '$0=="## 지휘 순환"{f=1} f&&/^## /&&$0!="## 지휘 순환"{exit} f' "$toc"
  cd_files step | while IFS= read -r p; do cat "$p"; done
  cat "$(cd_resume_file)"
}

cd_manual_file() { cd_files manual; }
cd_team_file() { _cd_named extra conducting-team.md; }
cd_resume_file() { _cd_named extra conducting-resume.md; }
