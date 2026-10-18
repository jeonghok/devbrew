#!/usr/bin/env bash
# R5 AC29 — 지휘자 skill · reference · 새 스크립트 · 통합 리뷰어에 레포 전용 리터럴(기본 브랜치 이름 · 브랜치 접두 ·
# 레포 구조 경로 · 모델 이름)이 없다. 외부 도구 기본 경로와 자기 상태 경로는 repo_defaults.py 상수에만 있다.
# 이빨은 변이로 잰다 — 표기 · 값 · 위치 · 부정문 네 축, 그리고 대상 여섯 하나하나가 실제로 읽히는지.
# 한계: 글자를 쪼개 이어 붙인 것(`"ori" + "gin/main"`)은 잡지 못한다 — 리뷰가 본다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_repo_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
TARGETS="skills/epic-conductor/SKILL.md references/conducting.md references/conductor-dispatch.md scripts/merge_check.py scripts/conductor_ledger.py agents/integration-reviewer.md"
scan() {  # scan <파일...> — 걸린 줄을 `<파일>:<줄>: <종류>` 로
  PYTHONIOENCODING=utf-8 python3 -I - "$SD/scripts" "$@" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[1])
import repo_defaults as R
consts = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)
if not consts:
    print("상수 없음 — 허용 목록이 비었다(락이 공허하다)")
rules = [
    ("기본 브랜치 이름", re.compile(r"origin/(?:main|master)(?![\w-])|refs/heads/(?:main|master)(?![\w-])|[\"'`](?:main|master)[\"'`]")),
    ("브랜치 접두", re.compile(r"(?<![\w/.-])(?:feature|fix)/")),
    ("레포 구조 경로", re.compile(r"docs/superpowers/|\.superpowers/|plugins/spec-distill|\.claude/worktrees")),
    ("모델 이름", re.compile(r"(?i)(?<![a-z])(?:opus|sonnet|haiku|fable)(?![a-z])|gpt-")),
]
for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for kind, rx in rules:
                if rx.search(line):
                    print("%s:%d: %s" % (path, n, kind))
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
assert_eq "$(scan "${files[@]}")" "" "대상 여섯에 레포 전용 리터럴이 없다"
# 양성 대조 · 변이 — 대상마다 사본에 한 줄을 넣으면 잡힌다(대상이 실제로 읽힌다)
mut() {  # mut <대상> <넣을 줄> — 사본에 줄을 넣고 그 사본만 스캔
  local c="$T/$(basename "$1").mut"
  cp "$SD/$1" "$c" && printf '\n%s\n' "$2" >> "$c" && scan "$c"
}
for t in $TARGETS; do
  [ -n "$(mut "$t" 'x origin/main y')" ] && ok "변이(대상 ${t}): 넣은 줄을 잡는다" || no "변이(대상 ${t}): 못 잡는다 — 이 대상은 스캔되지 않는다"
done
for line in 'git diff origin/main...HEAD' 'refs/heads/master' 'branch == "main"' "base = 'master'" 'feature/epic-x' 'fix/typo' \
            'docs/superpowers/specs/x.md' '.superpowers/sdd/p/progress.md' 'plugins/spec-distill/scripts' '.claude/worktrees/x' \
            'model: opus' 'Sonnet 으로' 'FABLE' 'haiku.' 'gpt-5' '# origin/main 을 쓰지 않는다' '```origin/master```'; do
  [ -n "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "변이: 「${line}」 를 잡는다" || no "변이: 「${line}」 를 못 잡는다"
done
for line in 'opusculum' 'mainline' 'domain/main.py' 'prefix/feature/x'; do
  [ -z "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "음성 대조: 「${line}」 는 잡지 않는다" || no "음성 대조: 「${line}」 를 잘못 잡는다"
done
# 허용 목록은 하나 — 상수 값 자체를 넣으면 잡힌다(상수 밖 같은 글자)
for c in $(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import repo_defaults as R
print(" ".join(sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)))' "$SD/scripts"); do
  [ -n "$(mut scripts/merge_check.py "X = \"$c\"")" ] && ok "변이: 상수 값 「${c}」 를 상수 밖에서 잡는다" || no "변이: 상수 값 「${c}」 를 못 잡는다"
done
finish
