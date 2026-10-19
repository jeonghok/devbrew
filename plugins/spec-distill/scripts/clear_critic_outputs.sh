#!/usr/bin/env bash
# clear_critic_outputs.sh <상태 폴더> — 직전 라운드의 critic 출력(critic.txt · critic-<번호>.txt)을 비운다.
# 그 이름을 빈 파일로 바꾼다 — 내용을 잘라 내지 않으니 하드 링크로 이어진 폴더 밖 파일에 닿지 않는다. 없던 파일은 만들지 않는다. 링크와 파일이 아닌 것은 비우지 않고 알린다(rc 1). 결과는 stderr 한 줄로 알리고 stdout 에는 아무것도 쓰지 않는다.
# rc 0 = 다 비웠다(비울 파일이 없던 때 포함) · 1 = 비우지 못한 파일이 있다(목록을 못 읽은 때 포함) · 2 = 상태 폴더가 없다.
# bash 3.2 와 zsh 어느 쪽으로 돌려도 같게 동작한다 — 글롭을 쓰지 않고, 목록을 단어로 쪼개지 않는다.
set -u

dir="${1:-}"
if [ -z "$dir" ] || [ ! -d "$dir" ]; then
  echo "[spec-distill] critic 출력 파일을 비우지 않았다 — 상태 폴더가 없다: '${dir}'" >&2
  exit 2
fi

left=""
# empty_one <이름> — 보통 파일만 비운다. 링크는 따라가지 않고(폴더 밖 파일을 비우게 된다), 파일이 아닌 것은
# 건드리지 않는다 — 둘 다 비우지 못한 것으로 적어 알린다. 지운 뒤 noclobber 로 새로 만든다 — 그 사이 보통 파일
# (하드 링크 · 보통 파일로 가는 링크 포함)이 다시 심기면 noclobber 가 열지 않아 만들기가 실패한다. noclobber 는 보통
# 파일이 아닌 것(폴더 · 장치 · FIFO, 그리로 가는 링크)은 막지 않는다 — 만든 뒤 그 이름이 링크 아닌 보통 파일인지 다시
# 보고, 아니면 비우지 못한 것으로 알린다. 다시 심긴 FIFO 는 쓰기 열기에서 멈출 수 있다.
empty_one() {
  if [ -L "$dir/$1" ]; then left="$left $dir/$1(링크)"; return 0; fi
  if [ ! -f "$dir/$1" ]; then left="$left $dir/$1(파일이 아님)"; return 0; fi
  { rm -f "$dir/$1" && ( set -C; : > "$dir/$1" ) && [ -f "$dir/$1" ] && [ ! -L "$dir/$1" ]; } 2>/dev/null \
    || left="$left $dir/$1"
}
if [ -e "$dir/critic.txt" ] || [ -L "$dir/critic.txt" ]; then empty_one critic.txt; fi
# 번호 붙은 출력은 ls 목록을 한 줄씩 읽는다 — 맞는 파일이 없는 글롭은 zsh 를 멈추고, 단어로 쪼갠 목록은 이름을 가른다.
names="$(cd "$dir" 2>/dev/null && ls 2>/dev/null)" \
  || { echo "[spec-distill] 상태 폴더의 파일 목록을 읽지 못했다: $dir" >&2; left="$left $dir/critic-<번호>.txt(목록을 읽지 못함)"; }
while IFS= read -r name; do
  case "$name" in critic-[0-9]*.txt) ;; *) continue ;; esac
  { [ -e "$dir/$name" ] || [ -L "$dir/$name" ]; } || continue
  empty_one "$name"
done <<NAMES
$names
NAMES

if [ -z "$left" ]; then
  echo "[spec-distill] critic 출력 파일($dir 의 critic.txt · critic-<번호>.txt)을 비웠다." >&2
  exit 0
fi
echo "[spec-distill] critic 출력 파일을 비우지 못했다:${left} — 5단계가 라운드 시작보다 오래된 그 파일을 부재로 읽는다(critic_predates_round)." >&2
exit 1
