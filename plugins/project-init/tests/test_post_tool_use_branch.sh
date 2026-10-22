#!/usr/bin/env bash
# project-init 훅 — Bash · EnterWorktree 뒤 새 브랜치를 reflog 로 관찰한다 (AC13 · RC82).
# 임시 레포 + 훅 입력 JSON. 규칙 파일은 기본 브랜치(origin/HEAD) 판에서 읽는다.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd -P)
HOOK="$ROOT/plugins/project-init/hooks/post-tool-use.py"
HOOKS_JSON="$ROOT/plugins/project-init/hooks/hooks.json"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }

unset DEVBREW_PROJECT_INIT_DISABLE DEVBREW_SKIP_HOOKS
REAL_GIT=$(command -v git)
T=$(mktemp -d) || exit 1
[ -d "$T" ] || exit 1
T=$(cd "$T" && pwd -P)
[ -z "$(ls -A "$T")" ] || { echo "임시 폴더가 비어 있지 않다: $T"; exit 1; }
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_NOSYSTEM=1 HOME="$T/home"
mkdir -p "$HOME"
git config --global user.email t@example.com
git config --global user.name t
git config --global init.defaultBranch main
git config --global advice.detachedHead false

RULE='^(feature|fix)/[a-z0-9][a-z0-9.-]*$'
SRC="$T/src"
git init -q "$SRC"
mkdir -p "$SRC/docs/git-workflow"
printf '# Branch Strategy\n\n```regex\n%s\n```\n' "$RULE" > "$SRC/docs/git-workflow/branch-strategy.md"
git -C "$SRC" add -A
git -C "$SRC" commit -q -m init

NORULE="$T/norule-src"
git init -q "$NORULE"
echo x > "$NORULE/README"
git -C "$NORULE" add -A
git -C "$NORULE" commit -q -m init

N=0
fresh() { # 새 작업 레포(origin/HEAD = main)를 만들고 경로를 W 에 둔다
  N=$((N + 1))
  W="$T/w$N"
  git clone -q "$SRC" "$W"
}

hook() { # $1 tool_name, $2 cwd, [$3 command] — 출력은 OUT
  OUT=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_name": sys.argv[1], "cwd": sys.argv[2], "tool_input": {"command": sys.argv[3]}}))' "$1" "$2" "${3:-}" \
    | CLAUDE_PROJECT_DIR="$2" python3 "$HOOK")
}

field() { # $1 key in OUT → stdout
  printf '%s' "$OUT" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
k = sys.argv[1]
if k == "ac":
    print(d.get("hookSpecificOutput", {}).get("additionalContext", ""))
else:
    print(d.get(k, ""))' "$1"
}

alerted() { # $1 이름, $2 label
  sm=$(field systemMessage); ac=$(field ac)
  case "$sm" in *"이름 규칙에 맞지 않는다 — \"$1\""*) ;; *) no "$2: 사람 채널에 규칙 밖 알림이 없다 — $OUT"; return ;; esac
  case "$ac" in *"git branch -m $1 "*) ok "$2" ;; *) no "$2: 모델 채널에 이름 바꾸기 명령이 없다 — $OUT" ;; esac
}

quiet() { # $1 label
  [ "$OUT" = "{}" ] && ok "$1" || no "$1: 조용해야 한다 — $OUT"
}

age_reflog() { # $1 repo, $2 branch, $3 seconds ago — 마지막 줄의 시각을 고친다
  python3 -I - "$1" "$2" "$3" <<'PY'
import subprocess, sys, time, os
repo, br, ago = sys.argv[1], sys.argv[2], int(sys.argv[3])
cd = subprocess.run(["git", "-C", repo, "rev-parse", "--git-common-dir"], capture_output=True, text=True).stdout.strip()
p = os.path.join(repo, cd, "logs", "refs", "heads", br)
lines = open(p, encoding="utf-8").read().splitlines()
head, msg = lines[-1].split("\t", 1)
parts = head.split(" ")
parts[-2] = str(int(time.time()) - ago)
lines[-1] = " ".join(parts) + "\t" + msg
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

echo "matcher"
m=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]["PostToolUse"][0]["matcher"])' "$HOOKS_JSON")
[ "$m" = "Bash|EnterWorktree" ] && ok "hooks.json matcher 가 Bash|EnterWorktree" || no "hooks.json matcher = $m"

echo "다섯 명령 뒤 규칙 밖 이름 → 알림"
fresh; git -C "$W" worktree add -q -b Bad1 "$T/wt1"
hook Bash "$W" "git worktree add -b Bad1 ../wt1"; alerted Bad1 "git worktree add -b"
fresh; git -C "$W" branch tmpa; age_reflog "$W" tmpa 3600; git -C "$W" branch -m tmpa Bad2
hook Bash "$W" "git branch -m tmpa Bad2"; alerted Bad2 "git branch -m"
fresh; git -C "$W" checkout -q -B Bad3
hook Bash "$W" "git checkout -B Bad3"; alerted Bad3 "git checkout -B"
fresh; git -C "$W" switch -q --create Bad4
hook Bash "$W" "git switch --create Bad4"; alerted Bad4 "git switch --create"
fresh; git -C "$W" branch Bad5
hook Bash "$T" "git -C w$N branch Bad5"; quiet "레포 밖 cwd 는 관찰하지 않는다(레포 아님)"
hook Bash "$W" "git -C $W branch Bad5"; alerted Bad5 "git -C <dir> branch"

echo "EnterWorktree"
fresh; git -C "$W" worktree add -q -b worktree-x "$W/.claude/worktrees/x"
hook EnterWorktree "$W/.claude/worktrees/x" 'git commit -m "add thing"'; alerted worktree-x "EnterWorktree 뒤 worktree-x"
case "$(field systemMessage)" in *"Conventional Commits"*) no "EnterWorktree 에서 커밋 검사가 돌았다" ;; *) ok "EnterWorktree 는 관찰만(커밋 검사 없음)" ;; esac
hook Bash "$W" 'git commit -m "add thing"'
case "$(field systemMessage)" in *"Conventional Commits"*) ok "Bash 는 커밋 검사도 한다(양성 짝)" ;; *) no "Bash 커밋 검사가 사라졌다 — $OUT" ;; esac

echo "규칙 안 이름 · 옛 브랜치"
fresh; git -C "$W" branch feature/ok
hook Bash "$W" "git branch feature/ok"; quiet "규칙 안 이름 → 조용"
fresh; git -C "$W" branch Old6; age_reflog "$W" Old6 61
hook Bash "$W" "ls"; quiet "61초 전에 만든 규칙 밖 브랜치 → 다시 알리지 않음"
fresh; git -C "$W" branch Old7; age_reflog "$W" Old7 30
hook Bash "$W" "ls"; alerted Old7 "30초 전에 만든 규칙 밖 브랜치 → 알림(양성 짝)"
fresh; git -C "$W" switch -q --create Mov9; age_reflog "$W" Mov9 3600; git -C "$W" commit -q --allow-empty -m y
hook Bash "$W" 'git commit -m "feat: y"'; quiet "마지막 줄이 커밋인 옛 브랜치 → 조용"

echo "규칙 파일은 기본 브랜치 판"
fresh; git -C "$W" switch -q --create feature/loose
printf '# Branch Strategy\n\n```regex\n^.*$\n```\n' > "$W/docs/git-workflow/branch-strategy.md"
git -C "$W" commit -q -am loosen
git -C "$W" branch Bad10
hook Bash "$W" "git branch Bad10"; alerted Bad10 "작업 브랜치에서 느슨하게 고친 규칙이 아니라 기본 브랜치 규칙으로 판정"

echo "fail-open"
fresh; git -C "$W" remote set-head origin -d; git -C "$W" branch Bad11
hook Bash "$W" "git branch Bad11"
case "$(field systemMessage)" in *"기본 브랜치(origin/HEAD)를 찾지 못해"*"브랜치 이름 검사를 건너뛴다(fail-open)"*) ok "기본 ref 없음 → 알리고 건너뜀" ;; *) no "기본 ref 없음 안내가 없다 — $OUT" ;; esac
W="$T/norule"; git clone -q "$NORULE" "$W"
mkdir -p "$W/docs/git-workflow"; printf '```regex\n%s\n```\n' "$RULE" > "$W/docs/git-workflow/branch-strategy.md"
git -C "$W" branch Bad12
hook Bash "$W" "git branch Bad12"
case "$(field systemMessage)" in *"규칙을 찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open)"*) ok "기본 브랜치 판에 규칙 파일 없음 → 작업 트리 파일이 있어도 알리고 건너뜀" ;; *) no "규칙 파일 없음 안내가 없다 — $OUT" ;; esac

echo "kill switch — git 을 부르기 전에 끝난다"
mkdir -p "$T/fakebin"
printf '#!/bin/sh\necho "$*" >> "%s/git.log"\nexec "%s" "$@"\n' "$T" "$REAL_GIT" > "$T/fakebin/git"
chmod +x "$T/fakebin/git"
fresh; git -C "$W" branch Bad13
run_ks() { # $1 env assignment or "", $2 label
  rm -f "$T/git.log"
  python3 -I -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":"git branch Bad13"}}))' "$W" > "$T/payload.json"
  OUT=$(env $1 PATH="$T/fakebin:$PATH" CLAUDE_PROJECT_DIR="$W" python3 "$HOOK" < "$T/payload.json")
}
run_ks "DEVBREW_NOOP=1" "양성 짝"
if [ -s "$T/git.log" ] && [ "$OUT" != "{}" ]; then ok "kill switch 없이는 가짜 git 이 불리고 알림이 난다(양성 짝)"; else no "가짜 git 계측이 죽었다 — $OUT"; fi
for ks in DEVBREW_PROJECT_INIT_DISABLE=1 DEVBREW_SKIP_HOOKS=project-init:post-tool-use DEVBREW_SKIP_HOOKS=project-init:PostToolUse; do
  run_ks "$ks" "$ks"
  if [ "$OUT" = "{}" ] && [ ! -e "$T/git.log" ]; then ok "$ks → {} · git 호출 없음"; else no "$ks → $OUT · git.log=$(cat "$T/git.log" 2>/dev/null)"; fi
done

exit $FAIL
