#!/usr/bin/env bash
# R5 AC29 — 지휘자 skill · reference · 새 스크립트 · 통합 리뷰어에 레포 전용 리터럴(기본 브랜치 이름 · 브랜치 접두 ·
# 레포 구조 경로 · 모델 이름)이 없다. 외부 도구 기본 경로와 자기 상태 경로는 repo_defaults.py 상수에만 있다.
# 이빨은 변이로 잰다 — 표기 · 값 · 위치 · 부정문 네 축, 그리고 대상 일곱 하나하나가 실제로 읽히는지.
# 알려진 한계(리뷰가 본다): 문자열 이어 붙이기(`"ori" + "gin/main"`) · 쪼갠 경로 조각 · main/master 가 아닌 다른
# 원격 · 브랜치 이름 · 목록에 없는 모델 표기. 다른 파일의 레포 전용 값은 R8 몫이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_repo_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
TARGETS="skills/epic-conductor/SKILL.md references/conducting.md references/conductor-dispatch.md scripts/merge_check.py scripts/conductor_ledger.py agents/integration-reviewer.md agents/relay-checker.md"
scan() {  # scan <파일...> — 걸린 줄을 `<파일>:<줄>: <종류>` 로
  PYTHONIOENCODING=utf-8 python3 -I - "${SCAN_DEFS:-$SD/scripts}" "$@" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[1])
import repo_defaults as R
consts = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)
bare = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and v and "/" not in v)
bare_rx = [(v, re.compile("[\"']" + re.escape(v) + "[\"']")) for v in bare]
git_rx = re.compile(r"(?<![\w/.-])(?:main|master)(?![\w/.-])")
if not consts:
    print("상수 없음 — 허용 목록이 비었다(락이 공허하다)")
rules = [
    ("기본 브랜치 이름", re.compile(r"origin/(?:main|master)(?![\w-])|refs/heads/(?:main|master)(?![\w-])|[\"'`](?:main|master)[\"'`]|(?<![\w/.-])(?:main|master)\.\.\.?")),
    ("브랜치 접두", re.compile(r"(?<![\w/.-])(?:feature|fix)/")),
    ("레포 구조 경로", re.compile(r"docs/superpowers|\.superpowers|plugins/spec-distill|\.claude/worktrees")),
    ("모델 이름", re.compile(r"(?i)(?<![a-z])(?:opus|sonnet|haiku|fable)(?![a-z])|gpt-")),
]
for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for kind, rx in rules:
                if rx.search(line):
                    print("%s:%d: %s" % (path, n, kind))
            if "git " in line and git_rx.search(line):
                print("%s:%d: git 명령의 기본 브랜치 이름" % (path, n))
            for v, brx in bare_rx:
                if brx.search(line):
                    print("%s:%d: 상수 %s" % (path, n, v))
            for c in consts:
                if c.rstrip("/") in line:
                    print("%s:%d: 상수 %s" % (path, n, c))
PY
}
files=()
for t in $TARGETS; do
  [ -f "$SD/$t" ] && ok "대상이 있다: $t" || no "대상이 없다: $t"
  files+=("$SD/$t")
done
main_out="$(scan "${files[@]}")"; main_rc=$?
assert_eq "${main_rc}:${main_out}" "0:" "대상 일곱에 레포 전용 리터럴이 없다(스캔 종료 코드 0)"
# 양성 대조 · 변이 — 대상마다 사본에 한 줄을 넣으면 잡힌다(대상이 실제로 읽힌다)
mut() {  # mut <대상> <넣을 줄> — 사본에 줄을 넣고 그 사본만 스캔
  local c="$T/$(basename "$1").mut"
  cp "$SD/$1" "$c" && printf '\n%s\n' "$2" >> "$c" && scan "$c"
}
for t in $TARGETS; do
  [ -n "$(mut "$t" 'x origin/main y')" ] && ok "변이(대상 ${t}): 넣은 줄을 잡는다" || no "변이(대상 ${t}): 못 잡는다 — 이 대상은 스캔되지 않는다"
done
# 한 번의 일곱 파일 스캔이 일곱 사본을 다 읽는다
mkdir "$T/six" && six=()
for t in $TARGETS; do
  d="$T/six/$(echo "$t" | tr '/' '_')"
  cp "$SD/$t" "$d" && printf '\n%s\n' 'x origin/main y' >> "$d" && six+=("$d")
done
six_out="$(scan "${six[@]}")"; six_rc=$?
assert_eq "$six_rc" "0" "일곱 파일 한 번 스캔의 종료 코드"
for d in "${six[@]}"; do
  case "$six_out" in *"$d:"*) ok "일곱 파일 한 번 스캔: $(basename "$d") 를 읽는다" ;; *) no "일곱 파일 한 번 스캔: $(basename "$d") 를 못 읽는다" ;; esac
done
# 상수 반복의 양성 대조 — 정규식 규칙과 겹치지 않는 가짜 상수를 심은 모듈로 잡힌다
mkdir "$T/shim" && cp "$SD/scripts/repo_defaults.py" "$T/shim/repo_defaults.py" && printf '\nZZ_PROBE = "zz-probe/dir/"\nZZ_BARE = "zz-bare"\n' >> "$T/shim/repo_defaults.py"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'see zz-probe/dir here')"
[ -n "$probe" ] && ok "변이: 가짜 상수(슬래시 있음)를 잡는다" || no "변이: 상수 반복에 이빨이 없다"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'x = "zz-bare"')"
[ -n "$probe" ] && ok "변이: 가짜 상수(슬래시 없음, 따옴표 꼴)를 잡는다" || no "변이: 슬래시 없는 상수 반복에 이빨이 없다"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'zz-bare prose')"
[ -z "$probe" ] && ok "음성 대조: 따옴표 없는 zz-bare 는 잡지 않는다" || no "음성 대조: 따옴표 없는 zz-bare 를 잘못 잡는다"
for line in 'git diff main...HEAD' 'git merge-base main HEAD' '"main...HEAD"' '.superpowers' 'docs/superpowers' 'x = "conductor"' "d = 'merge-check'" \
            'git diff origin/main...HEAD' 'refs/heads/master' 'branch == "main"' "base = 'master'" 'feature/epic-x' 'fix/typo' \
            'docs/superpowers/specs/x.md' '.superpowers/sdd/p/progress.md' 'plugins/spec-distill/scripts' '.claude/worktrees/x' \
            'model: opus' 'Sonnet 으로' 'FABLE' 'haiku.' 'gpt-5' '# origin/main 을 쓰지 않는다' '```origin/master```'; do
  [ -n "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "변이: 「${line}」 를 잡는다" || no "변이: 「${line}」 를 못 잡는다"
done
for line in 'def main(' 'if __name__ == "__main__":' 'sys.exit(main())' 'superpowers:brainstorming' 'conductor 는 지휘한다' 'git config user.name=merge-check' '"conductor_ledger.py"' 'opusculum' 'mainline' 'domain/main.py' 'prefix/feature/x'; do
  [ -z "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "음성 대조: 「${line}」 는 잡지 않는다" || no "음성 대조: 「${line}」 를 잘못 잡는다"
done
# 허용 목록은 하나 — 상수 값 자체를 넣으면 잡힌다(상수 밖 같은 글자)
for c in $(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import repo_defaults as R
print(" ".join(sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)))' "$SD/scripts"); do
  [ -n "$(mut scripts/merge_check.py "X = \"$c\"")" ] && ok "변이: 상수 값 「${c}」 를 상수 밖에서 잡는다" || no "변이: 상수 값 「${c}」 를 못 잡는다"
done
finish
