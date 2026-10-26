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
    | PATH="${HOOK_PATH:-$PATH}" CLAUDE_PROJECT_DIR="$2" python3 "$HOOK")
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

elsewhere() { # $1 이름, $2 작업 트리 경로, $3 label
  sm=$(field systemMessage); ac=$(field ac)
  case "$sm" in *"이름 규칙에 맞지 않는다 — \"$1\""*"다른 작업 트리($2)"*) ;; *) no "$3: 사람 채널에 알림 · 작업 트리 경로가 없다 — $OUT"; return ;; esac
  case "$ac" in *"git branch -m $1 "*) no "$3: 다른 작업 트리 브랜치에 이름 바꾸기 명령을 냈다 — $OUT"; return ;; esac
  case "$ac" in *"브랜치 $1(작업 트리 $2)이 규칙 밖이다 — 다른 작업 트리에서 쓰는 중이라 이름 바꾸기 명령을 내지 않는다"*) ok "$3" ;;
    *) no "$3: 모델 채널에 명령 없는 알림 줄이 없다 — $OUT" ;; esac
}

noted() { # $1 이름, $2 label — 알리기만 하고 이름 바꾸기 명령은 없다(이 명령이 만들었다는 근거 없음)
  sm=$(field systemMessage); ac=$(field ac)
  case "$sm" in *"이름 규칙에 맞지 않는다 — \"$1\""*"이름을 바꾸라고 하지 않는다"*) ;; *) no "$2: 사람 채널에 근거 없음 알림이 없다 — $OUT"; return ;; esac
  case "$ac" in *"git branch -m $1 "*) no "$2: 근거 없이 이름 바꾸기 명령을 냈다 — $OUT" ;; *) ok "$2" ;; esac
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
hook Bash "$W" "git worktree add -b Bad1 ../wt1"; elsewhere Bad1 "$T/wt1" "git worktree add -b(다른 작업 트리에서 쓰는 브랜치)"
fresh; git -C "$W" checkout -q -b tmpa; age_reflog "$W" tmpa 3600; git -C "$W" branch -m tmpa Bad2
hook Bash "$W" "git branch -m tmpa Bad2"; alerted Bad2 "git branch -m(지금 브랜치의 이름 바꾸기)"
fresh; git -C "$W" checkout -q -B Bad3
hook Bash "$W" "git checkout -B Bad3"; alerted Bad3 "git checkout -B"
fresh; git -C "$W" switch -q --create Bad4
hook Bash "$W" "git switch --create Bad4"; alerted Bad4 "git switch --create"
fresh; git -C "$W" checkout -q -b Bad5
hook Bash "$W" "git -C $W checkout -b Bad5"; alerted Bad5 "git -C <dir> checkout -b"
fresh; git -C "$W" branch Plain5
hook Bash "$W" "git branch Plain5"; noted Plain5 "만들기만 하고 옮겨 가지 않은 브랜치 → 지금 브랜치가 아니라 알림만(명령 없음)"
fresh; git -C "$W" checkout -q -b Bad15; git -C "$W" commit -q --allow-empty -m x
case "$(tail -n 1 "$W/.git/logs/refs/heads/Bad15")" in *"	commit: x") ;; *) no "픽스처 전제: Bad15 reflog 마지막 줄이 커밋이 아니다" ;; esac
hook Bash "$W" 'git checkout -b Bad15 && git commit -m "x"'; alerted Bad15 "git checkout -b && git commit 한 명령(reflog 마지막 줄이 커밋)"

echo "다른 작업 트리가 쓰는 브랜치 — 이름 바꾸기 명령을 내지 않는다"
fresh; git -C "$W" worktree add -q -b BadB "$T/wtB$N"; git -C "$W" checkout -q -b BadPlain
hook Bash "$W" "git worktree add -b BadB $T/wtB$N && git checkout -b BadPlain"
elsewhere BadB "$T/wtB$N" "작업 트리 B 에서 쓰는 규칙 밖 브랜치 → 사람 채널에 B 경로 · 모델 채널에 명령 없음"
alerted BadPlain "이 작업 트리의 지금 브랜치인 규칙 밖 브랜치 → 이름 바꾸기 명령(양성 짝)"
fresh; git -C "$W" checkout -q -b BadMain; git -C "$W" worktree add -q --detach "$W/.claude/worktrees/x"
hook Bash "$W/.claude/worktrees/x" "git checkout -b BadMain && git worktree add --detach .claude/worktrees/x"
elsewhere BadMain "$W" "안에 중첩된 detached 작업 트리가 cwd · 바깥 main 작업 트리가 쓰는 규칙 밖 브랜치 → 명령 없음"
mkdir -p "$T/wtfail"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = worktree ] && exit 1; done\nexec "%s" "$@"\n' "$REAL_GIT" > "$T/wtfail/git"
chmod +x "$T/wtfail/git"
# 만드는 명령이어야 이름 바꾸기 명령의 후보가 된다 — 작업 트리 목록 실패가 그 명령을 빼는지 잰다.
HOOK_PATH="$T/wtfail:$PATH" hook Bash "$W" "git checkout -b BadMain"
sm=$(field systemMessage); ac=$(field ac)
case "$ac" in *"작업 트리 목록을 읽지 못해 규칙 밖 브랜치에 이름 바꾸기 명령을 내지 않았다"*) ok "작업 트리 목록 실패 → 모델 채널에 명령 없는 알림 줄" ;; *) no "작업 트리 목록 실패를 모델 채널에 알리지 않았다 — $OUT" ;; esac
case "$ac" in *"git branch -m"*) no "작업 트리 목록을 못 읽었는데 이름 바꾸기 명령을 냈다 — $OUT" ;; *)
  case "$sm" in *"작업 트리 목록을 읽지 못해 이름 바꾸기 명령은 내지 않는다"*"이름 규칙에 맞지 않는다"*|*"이름 규칙에 맞지 않는다"*"작업 트리 목록을 읽지 못해 이름 바꾸기 명령은 내지 않는다"*)
    ok "작업 트리 목록 실패 → 명령 없이 알리고 그 사실을 적는다" ;; *) no "작업 트리 목록 실패 안내가 없다 — $OUT" ;; esac ;; esac

hook_ew() { # $1 cwd, $2 tool_input.name — EnterWorktree 의 실제 입력 꼴({"name": …})
  OUT=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_name": "EnterWorktree", "cwd": sys.argv[1], "tool_input": {"name": sys.argv[2]}}))' "$1" "$2" \
    | CLAUDE_PROJECT_DIR="$1" python3 "$HOOK")
}

echo "EnterWorktree"
fresh; git -C "$W" worktree add -q -b worktree-x "$W/.claude/worktrees/x"
hook_ew "$W/.claude/worktrees/x" x; alerted worktree-x "EnterWorktree 뒤 worktree-x(cwd = 새 작업 트리)"
fresh; git -C "$W" worktree add -q -b worktree-y "$W/.claude/worktrees/y"
hook_ew "$W" y; elsewhere worktree-y "$W/.claude/worktrees/y" "EnterWorktree 뒤 worktree-y(cwd = 옮기기 전 레포) → 이름 y 의 작업 트리 브랜치로 잡고 명령 없이 알림"
# 레포 기록의 실제 꼴은 이름 feature/x → 작업 트리 .claude/worktrees/feature+x · 브랜치 worktree-feature+x 다.
fresh; git -C "$W" worktree add -q -b worktree-a+b "$W/.claude/worktrees/a+b"
hook_ew "$W" a/b; elsewhere worktree-a+b "$W/.claude/worktrees/a+b" "EnterWorktree 이름에 / 가 든 경우(작업 트리 경로 a+b — 기록된 꼴)"
fresh; git -C "$W" worktree add -q -b worktree-c+d "$W/.claude/worktrees/c/d"
hook_ew "$W" c/d; elsewhere worktree-c+d "$W/.claude/worktrees/c/d" "EnterWorktree 이름에 / 가 든 경우(작업 트리 경로 c/d — 하위 폴더 꼴)"
mkdir -p "$T/wtfail2"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = worktree ] && exit 1; done\nexec "%s" "$@"\n' "$REAL_GIT" > "$T/wtfail2/git"
chmod +x "$T/wtfail2/git"
fresh; git -C "$W" worktree add -q -b worktree-e "$W/.claude/worktrees/e"
OUT=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_name": "EnterWorktree", "cwd": sys.argv[1], "tool_input": {"name": "e"}}))' "$W" \
  | PATH="$T/wtfail2:$PATH" CLAUDE_PROJECT_DIR="$W" python3 "$HOOK")
case "$(field systemMessage)" in *"작업 트리 목록을 읽지 못해"*) ok "EnterWorktree · 작업 트리 목록 실패 → 조용히 빠지지 않고 알림" ;; *) no "EnterWorktree · 작업 트리 목록 실패를 알리지 않았다 — $OUT" ;; esac
case "$(field ac)" in *"git branch -m"*) no "EnterWorktree · 작업 트리 목록 실패인데 이름 바꾸기 명령 — $OUT" ;; *) ok "EnterWorktree · 작업 트리 목록 실패 → 명령 없음" ;; esac
hook_ew0() { # $1 cwd — name 없이 부른 EnterWorktree(하니스가 무작위 이름을 고른다)
  OUT=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_name": "EnterWorktree", "cwd": sys.argv[1], "tool_input": {}}))' "$1" \
    | CLAUDE_PROJECT_DIR="$1" python3 "$HOOK")
}
fresh; git -C "$W" worktree add -q -b worktree-happy-cat "$W/.claude/worktrees/happy-cat"
hook_ew0 "$W/.claude/worktrees/happy-cat"; alerted worktree-happy-cat "name 없는 EnterWorktree · cwd = 새 작업 트리 → 이 호출이 만든 브랜치로 알림 · 명령"
fresh; git -C "$W" worktree add -q -b worktree-calm-owl "$W/.claude/worktrees/calm-owl"; git -C "$W" branch OtherSession
hook_ew0 "$W/.claude/worktrees/calm-owl"; alerted worktree-calm-owl "name 없는 EnterWorktree · cwd = 새 작업 트리 + 무관한 새 브랜치 → 이 호출의 브랜치로 알림 · 명령"
case "$(field systemMessage)" in *"EnterWorktree 에 name 이 없어"*) no "name 없는 EnterWorktree · 브랜치를 가렸는데 「가리지 못했다」 알림이 함께 나왔다 — $OUT" ;; *) ok "name 없는 EnterWorktree · cwd = 새 작업 트리 → 「가리지 못했다」 알림 없음" ;; esac
hook_ewp() { # $1 cwd = tool_input.path — 이미 있는 작업 트리로 들어간 EnterWorktree
  OUT=$(python3 -I -c 'import json,sys; print(json.dumps({"tool_name": "EnterWorktree", "cwd": sys.argv[1], "tool_input": {"path": sys.argv[1]}}))' "$1" \
    | CLAUDE_PROJECT_DIR="$1" python3 "$HOOK")
}
fresh; git -C "$W" worktree add -q -b BadP "$W/.claude/worktrees/p"
hook_ewp "$W/.claude/worktrees/p"; noted BadP "EnterWorktree 가 path 로 남이 방금 만든 작업 트리에 들어감 → 이 호출이 만든 것이 아니라 명령 없음"
fresh; git -C "$W" worktree add -q -b worktree-sly-fox "$W/.claude/worktrees/sly-fox"
hook_ew0 "$W"
case "$(field systemMessage)" in *"EnterWorktree 에 name 이 없어 새 작업 트리의 브랜치를 가리지 못했다"*"fail-open"*) ok "name 없는 EnterWorktree · cwd = 옮기기 전 레포 → 조용히 빠지지 않고 알림" ;; *) no "name 없는 EnterWorktree · 옮기기 전 레포에서 조용히 빠졌다 — $OUT" ;; esac
case "$(field ac)" in *"git branch -m"*) no "name 없는 EnterWorktree · 옮기기 전 레포인데 이름 바꾸기 명령 — $OUT" ;; *) ok "name 없는 EnterWorktree · 옮기기 전 레포 → 명령 없음" ;; esac
fresh; git -C "$W" worktree add -q -b OldWtBad "$W/.claude/worktrees/oldwt"; git -C "$W" worktree add -q -b worktree-new "$W/.claude/worktrees/new"
python3 -I - "$W/.git/worktrees/oldwt/logs/HEAD" <<'PY'
import sys, time
p = sys.argv[1]; lines = open(p, encoding="utf-8").read().splitlines()
head, sep, msg = lines[0].partition("\t"); parts = head.split(" "); parts[-2] = str(int(time.time()) - 3600)
lines[0] = " ".join(parts) + sep + msg; open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
hook_ew0 "$W/.claude/worktrees/oldwt"; noted OldWtBad "name 없는 EnterWorktree · cwd = 한 시간 전에 만든 작업 트리(옮기기 전) → 그 브랜치에 명령 없음"
fresh; git -C "$W" checkout -q -b SharedBad
hook_ew "$W" "$(basename "$W")"; noted SharedBad "EnterWorktree name 이 메인 체크아웃 폴더 이름과 같음 · cwd = 메인 체크아웃 → 링크된 작업 트리가 아니라 명령 없음"
fresh; git -C "$W" branch Echo1
hook Bash "$W" "echo git branch Echo1"; noted Echo1 "글로만 쓴 git 명령(echo) → 지금 브랜치가 아니라 명령 없음"
fresh; git -C "$W" branch HereBad
hook Bash "$W" "git commit -m \"\$(cat <<'EOF'
fix: x

git checkout -b HereBad
EOF
)\""; noted HereBad "커밋 메시지 heredoc 안의 git 명령 → 지금 브랜치가 아니라 명령 없음"
fresh; mkdir -p "$W/sub"; git -C "$W/sub" init -q; git -C "$W" branch Nest1
hook Bash "$W" "git -C sub branch Nest1"; noted Nest1 "안에 중첩된 다른 레포를 가리킨 명령 → 이 레포의 지금 브랜치가 아니라 명령 없음"
fresh; git -C "$W" worktree add -q -b worktree-xz "$W/.claude/worktrees/xz"
hook_ew "$W" z; quiet "EnterWorktree 이름 z · 새 브랜치는 작업 트리 xz 의 것 → 조용"
hook EnterWorktree "$W/.claude/worktrees/xz" 'git commit -m "add thing"'
case "$(field systemMessage)" in *"Conventional Commits"*) no "EnterWorktree 에서 커밋 검사가 돌았다" ;; *) ok "EnterWorktree 는 관찰만(커밋 검사 없음)" ;; esac
hook Bash "$W" 'git commit -m "add thing"'
case "$(field systemMessage)" in *"Conventional Commits"*) ok "Bash 는 커밋 검사도 한다(양성 짝)" ;; *) no "Bash 커밋 검사가 사라졌다 — $OUT" ;; esac

echo "규칙 안 이름 · 옛 브랜치"
fresh; git -C "$W" branch feature/ok
hook Bash "$W" "git branch feature/ok"; quiet "규칙 안 이름 → 조용"
fresh; git -C "$W" branch Old6; age_reflog "$W" Old6 61
hook Bash "$W" "git log Old6"; quiet "61초 전에 만든 규칙 밖 브랜치 → 다시 알리지 않음"
fresh; git -C "$W" branch Old7; age_reflog "$W" Old7 30
hook Bash "$W" "git log Old7"; noted Old7 "30초 전에 만든 규칙 밖 브랜치를 읽기 명령이 가리킴 → 알림(양성 짝) · 만든 근거가 없어 명령 없음"

echo "이 명령이 만들지 않은 브랜치 — 다른 세션의 것일 수 있어 다루지 않는다"
# 옛 Old7 은 `ls` 뒤에도 30초 전 브랜치를 알리고 이름 바꾸기 명령까지 냈다 — 공용 git 디렉토리를
# 보므로 다른 세션이 막 만든 브랜치의 이름을 이 세션 모델이 바꾸게 했다.
fresh; git -C "$W" branch Other1; age_reflog "$W" Other1 30
hook Bash "$W" "ls"; quiet "30초 전에 만든 규칙 밖 브랜치 · 이 명령은 가리키지 않음 · 지금 브랜치 아님 → 조용"
fresh; git -C "$W" branch Other2
hook Bash "$W" "git status"; quiet "방금 만든 규칙 밖 브랜치 · 이 명령과 무관(다른 세션) → 조용"
fresh; git -C "$W" worktree add -q -b Other3 "$T/wtO$N"
hook Bash "$W" "git status"; quiet "다른 작업 트리가 방금 만든 규칙 밖 브랜치 · 이 명령과 무관 → 조용"
fresh; git -C "$W" branch Other4; git -C "$W" checkout -q -b Mine4
hook Bash "$W" "git checkout -b Mine4"; alerted Mine4 "같은 때 둘 — 명령이 만든 Mine4 는 알림(양성 짝)"
case "$OUT" in *Other4*) no "같은 때 둘 — 명령과 무관한 Other4 를 다뤘다 — $OUT" ;; *) ok "같은 때 둘 — 명령과 무관한 Other4 는 다루지 않음" ;; esac
fresh; git -C "$W" branch Bad41
hook Bash "$W" "git branch Bad4"; quiet "이름이 앞부분만 겹치는 명령(Bad4 ≠ Bad41) → 조용"
fresh; git -C "$W" checkout -q -b Cur5; age_reflog "$W" Cur5 30
hook Bash "$W" "ls"; noted Cur5 "cwd 의 지금 브랜치(30초 전 만듦) → 명령 글에 없어도 알림 · 같은 체크아웃의 다른 세션 것일 수 있어 명령 없음"
fresh; git -C "$W" branch test
hook Bash "$W" "npm test"; noted test "다른 세션이 만든 브랜치 test · 이 명령은 같은 낱말일 뿐 → 명령 없음"
fresh; git -C "$W" branch Other8; git -C "$W" checkout -q -b fix/Other8
hook Bash "$W" "git checkout -b fix/Other8"; noted Other8 "다른 세션의 Other8 · 이 명령은 fix/Other8 을 만듦 → Other8 에 명령 없음"
fresh; git -C "$W" switch -q --create Mov9; age_reflog "$W" Mov9 3600; git -C "$W" commit -q --allow-empty -m y
hook Bash "$W" 'git commit -m "feat: y"'; quiet "마지막 줄이 커밋인 옛 브랜치 → 조용"

echo "규칙 파일은 기본 브랜치 판"
fresh; git -C "$W" switch -q --create feature/loose
printf '# Branch Strategy\n\n```regex\n^.*$\n```\n' > "$W/docs/git-workflow/branch-strategy.md"
git -C "$W" commit -q -am loosen
git -C "$W" checkout -q -b Bad10
hook Bash "$W" "git checkout -b Bad10"; alerted Bad10 "작업 브랜치에서 느슨하게 고친 규칙이 아니라 기본 브랜치 규칙으로 판정"

echo "fail-open"
fresh; git -C "$W" remote set-head origin -d; git -C "$W" branch Bad11
hook Bash "$W" "git branch Bad11"
case "$(field systemMessage)" in *"기본 브랜치(origin/HEAD)를 찾지 못해"*"브랜치 이름 검사를 건너뛴다(fail-open)"*"git remote set-head origin --auto"*) ok "기본 ref 없음 → 알리고 건너뜀 · set-head 안내" ;; *) no "기본 ref 없음 안내가 없다 — $OUT" ;; esac
W="$T/noorigin"; git clone -q "$SRC" "$W"; git -C "$W" remote remove origin; git -C "$W" branch Bad14
hook Bash "$W" "git branch Bad14"
sm=$(field systemMessage)
case "$sm" in *'`origin` 원격이 없어'*"브랜치 이름 검사를 건너뛴다(fail-open)"*)
  case "$sm" in *"set-head"*) no "origin 원격이 없는데 set-head 를 안내한다 — $OUT" ;; *) ok "origin 원격 없음 → 그 사실을 알리고 건너뜀" ;; esac ;;
  *) no "origin 원격 없음 안내가 없다 — $OUT" ;; esac
W="$T/norule"; git clone -q "$NORULE" "$W"
mkdir -p "$W/docs/git-workflow"; printf '```regex\n%s\n```\n' "$RULE" > "$W/docs/git-workflow/branch-strategy.md"
git -C "$W" branch Bad12
hook Bash "$W" "git branch Bad12"
case "$(field systemMessage)" in *"규칙을 찾지 못했다 — 브랜치 이름 검사를 건너뛴다(fail-open)"*) ok "기본 브랜치 판에 규칙 파일 없음 → 작업 트리 파일이 있어도 알리고 건너뜀" ;; *) no "규칙 파일 없음 안내가 없다 — $OUT" ;; esac

echo "git 이 멈추면 — 공유 시간 상한 안에 끝내고 커밋 검사는 낸다"
mkdir -p "$T/slowbin"
printf '#!/bin/sh\nsleep 30\n' > "$T/slowbin/git"
chmod +x "$T/slowbin/git"
t0=$(date +%s)
HOOK_PATH="$T/slowbin:$PATH" hook Bash "$W" 'git commit -m "add thing"'
el=$(( $(date +%s) - t0 ))
sm=$(field systemMessage)
case "$sm" in *"git 이 제시간에 끝나지 않아 새 브랜치 이름 검사를 건너뛴다(fail-open)"*"Conventional Commits"*) ok "시간 초과 → fail-open 안내 + 커밋 검사" ;; *) no "시간 초과 안내 · 커밋 검사가 없다 — $OUT" ;; esac
[ "$el" -lt 10 ] && ok "훅이 ${el}초에 끝났다(hooks.json timeout 10초 안)" || no "훅이 ${el}초 걸렸다 — 10초 timeout 을 넘는다"

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
