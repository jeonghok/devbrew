#!/usr/bin/env bash
# R5 AC29 — 지휘자 skill · reference · 새 스크립트 · 통합 리뷰어에 레포 전용 리터럴(기본 브랜치 이름 · 브랜치 접두 ·
# 레포 구조 경로 · 모델 이름)이 없다. 외부 도구 기본 경로와 자기 상태 경로는 repo_defaults.py 상수에만 있다.
# 이빨은 변이로 잰다 — 표기 · 값 · 위치 · 부정문 네 축, 그리고 대상 하나하나가 실제로 읽히는지.
# 알려진 한계(리뷰가 본다): 문자열 이어 붙이기(`"ori" + "gin/main"`) · 쪼갠 경로 조각 · main/master 가 아닌 다른
# 원격 · 브랜치 이름 · 목록에 없는 모델 표기.
# 면제는 줄 꼴 하나 — 처분 앵커 줄(`**처분** — consumer=<경로>`, 앞의 `//` · `#` 허용)의 consumer 값만 지우고 나머지는
# 스캔한다. 그 값은 레포 기준 추적 경로여야 하고 그 꼴은 shared/tests/test_dispatch_disposition.sh 가 집행한다.
# 펜스 꼴 축(R8 AC4): 해결자 값을 받는 줄은 `<V>="$(… get …)" || <V>=""` 이고 다음 비지 않은 줄이 빈 값을 확인한다.
# `git add --` 로 경로를 정하는 펜스는 해결자의 check-path 또는 roadmap-check 를 부른다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_repo_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
TARGETS="skills/epic-conductor/SKILL.md references/conducting.md references/conductor-dispatch.md scripts/merge_check.py scripts/conductor_ledger.py agents/integration-reviewer.md agents/relay-checker.md skills/request-framing/SKILL.md skills/pm-interview/SKILL.md skills/pm-interview/references/finishing.md skills/pm-interview/references/state-file.md skills/spec-review/SKILL.md references/redecompose.md scripts/control_plane.py scripts/state_path.py scripts/roadmap_status.py"
scan() {  # scan <파일...> — 걸린 줄을 `<파일>:<줄>: <종류>` 로
  SCAN_DEPS="$SD/scripts" PYTHONIOENCODING=utf-8 python3 -I - "${SCAN_DEFS:-$SD/scripts}" "$@" <<'PY'
import os, re, sys
sys.path.insert(0, os.environ["SCAN_DEPS"])  # 사본 모듈이 import 하는 이웃 모듈(roadmap_model 등)
sys.path.insert(0, sys.argv[1])
import repo_defaults as R
consts = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)
bare = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and v and "/" not in v)
bare_rx = [(v, re.compile("[\"']" + re.escape(v) + "[\"']")) for v in bare]
const_rx = [(c, re.compile(r"(?<![\w/.-])" + re.escape(c)) if c.endswith("/") else re.compile(re.escape(c))) for c in consts]
git_rx = re.compile(r"(?<![\w/.-])(?:main|master)(?![\w/.-])")
if not consts:
    print("상수 없음 — 허용 목록이 비었다(락이 공허하다)")
rules = [
    ("기본 브랜치 이름", re.compile(r"origin/(?:main|master)(?![\w-])|refs/heads/(?:main|master)(?![\w-])|[\"'`](?:main|master)[\"'`]|(?<![\w/.-])(?:main|master)\.\.\.?")),
    ("브랜치 접두", re.compile(r"(?<![\w/.-])(?:feature|fix)/")),
    ("레포 구조 경로", re.compile(r"docs/superpowers|\.superpowers|plugins/spec-distill|\.claude/worktrees")),
    ("모델 이름", re.compile(r"(?i)(?<![a-z])(?:opus|sonnet|haiku|fable)(?![a-z])|gpt-")),
]
anchor_rx = re.compile(r"^(\s*(?:(?://|#)\s*)?\*\*처분\*\* — consumer=)\S+")
for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = anchor_rx.sub(r"\1", line)
            for kind, rx in rules:
                if rx.search(line):
                    print("%s:%d: %s" % (path, n, kind))
            if "git " in line and git_rx.search(line):
                print("%s:%d: git 명령의 기본 브랜치 이름" % (path, n))
            for v, brx in bare_rx:
                if brx.search(line):
                    print("%s:%d: 상수 %s" % (path, n, v))
            for c, crx in const_rx:
                if crx.search(line):
                    print("%s:%d: 상수 %s" % (path, n, c))
PY
}
files=()
for t in $TARGETS; do
  [ -f "$SD/$t" ] && ok "대상이 있다: $t" || no "대상이 없다: $t"
  files+=("$SD/$t")
done
main_out="$(scan "${files[@]}")"; main_rc=$?
assert_eq "${main_rc}:${main_out}" "0:" "대상 전부에 레포 전용 리터럴이 없다(스캔 종료 코드 0)"
# 양성 대조 · 변이 — 대상마다 사본에 한 줄을 넣으면 잡힌다(대상이 실제로 읽힌다)
mut() {  # mut <대상> <넣을 줄> — 사본에 줄을 넣고 그 사본만 스캔
  local c="$T/$(basename "$1").mut"
  cp "$SD/$1" "$c" && printf '\n%s\n' "$2" >> "$c" && scan "$c"
}
for t in $TARGETS; do
  [ -n "$(mut "$t" 'x origin/main y')" ] && ok "변이(대상 ${t}): 넣은 줄을 잡는다" || no "변이(대상 ${t}): 못 잡는다 — 이 대상은 스캔되지 않는다"
done
# 한 번의 전체 스캔이 모든 사본을 다 읽는다
mkdir "$T/six" && six=()
for t in $TARGETS; do
  d="$T/six/$(echo "$t" | tr '/' '_')"
  cp "$SD/$t" "$d" && printf '\n%s\n' 'x origin/main y' >> "$d" && six+=("$d")
done
six_out="$(scan "${six[@]}")"; six_rc=$?
assert_eq "$six_rc" "0" "전체 한 번 스캔의 종료 코드"
for d in "${six[@]}"; do
  case "$six_out" in *"$d:"*) ok "전체 한 번 스캔: $(basename "$d") 를 읽는다" ;; *) no "전체 한 번 스캔: $(basename "$d") 를 못 읽는다" ;; esac
done
# 상수 반복의 양성 대조 — 정규식 규칙과 겹치지 않는 가짜 상수를 심은 모듈로 잡힌다
mkdir "$T/shim" && cp "$SD/scripts/repo_defaults.py" "$T/shim/repo_defaults.py" && printf '\nZZ_PROBE = "zz-probe/dir/"\nZZ_BARE = "zz-bare"\n' >> "$T/shim/repo_defaults.py"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'see zz-probe/dir/x here')"
[ -n "$probe" ] && ok "변이: 가짜 상수(슬래시 있음)를 잡는다" || no "변이: 상수 반복에 이빨이 없다"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'x = "zz-bare"')"
[ -n "$probe" ] && ok "변이: 가짜 상수(슬래시 없음, 따옴표 꼴)를 잡는다" || no "변이: 슬래시 없는 상수 반복에 이빨이 없다"
probe="$(SCAN_DEFS="$T/shim" mut skills/epic-conductor/SKILL.md 'zz-bare prose')"
[ -z "$probe" ] && ok "음성 대조: 따옴표 없는 zz-bare 는 잡지 않는다" || no "음성 대조: 따옴표 없는 zz-bare 를 잘못 잡는다"
for line in 'git diff main...HEAD' 'git merge-base main HEAD' '"main...HEAD"' '.superpowers' 'docs/superpowers' 'x = "conductor"' "d = 'merge-check'" \
            'git diff origin/main...HEAD' 'refs/heads/master' 'branch == "main"' "base = 'master'" 'feature/epic-x' 'x = "feature/y"' 'fix/typo' \
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
# 처분 앵커 줄 — consumer 값만 면제다. 앵커 밖의 같은 경로 · 앵커 줄의 나머지는 잡는다.
anchor_path='plugins/spec-distill/scripts/docreview_route.py'
for line in "see ${anchor_path}" "**처분** — consumer=${anchor_path} · fail-open · disclosure=docs/superpowers/x" \
            "consumer=${anchor_path}" "- **처분** — consumer=${anchor_path} · fail-open"; do
  [ -n "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "앵커 면제 밖: 「${line}」 를 잡는다" || no "앵커 면제 밖: 「${line}」 를 못 잡는다"
done
for line in "  // **처분** — consumer=${anchor_path} · fail-open · disclosure=x" "**처분** — consumer=${anchor_path} · fail-closed" \
            "# **처분** — consumer=${anchor_path} · fail-open"; do
  [ -z "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "앵커 면제: 「${line}」 는 잡지 않는다" || no "앵커 면제: 「${line}」 를 잘못 잡는다"
done

# ── 펜스 꼴(R8 AC4) — 해결자 값의 rc · 빈 값 확인, git add 범위 펜스의 경로 판정 ─────────────
shape() {  # shape <파일...> — 어긋난 자리를 `<파일>:<줄>: <사유>` 로, 끝 줄은 `세었다: get <n> · add <m>`
  SHAPE_TESTS="$SD/tests" PYTHONDONTWRITEBYTECODE=1 PYTHONIOENCODING=utf-8 python3 -I - "$@" <<'PY'
import os, re, sys
sys.path.insert(0, os.environ["SHAPE_TESTS"])
from test_finishing_block_scope import bash_fences
GET = 'repo_defaults.py" get '
assign_rx = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)="\$\(.*repo_defaults\.py" get [^)]*\)" \|\| \1=""\s*$')
add_rx = re.compile(r"git( -C \S+)? add --")
judge_rx = re.compile(r'^\s*[^#\s].*repo_defaults\.py" (?:check-path|roadmap-check) ')
n_get = n_add = 0
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    for i, line in enumerate(lines):
        if GET not in line:
            continue
        n_get += 1
        m = assign_rx.match(line)
        if not m:
            print("%s:%d: 해결자 값 줄이 rc 확인 꼴이 아니다" % (path, i + 1))
            continue
        v = m.group(1)
        nxt = next((l for l in lines[i + 1:] if l.strip()), "")
        if ('[ -n "$%s" ]' % v) not in nxt and ('[ -n "${%s}" ]' % v) not in nxt:
            print("%s:%d: 해결자 값 뒤 첫 줄이 빈 값을 확인하지 않는다" % (path, i + 1))
    for start, _end, body in bash_fences("\n".join(lines)):
        if not any(add_rx.search(l) for l in body):
            continue
        n_add += 1
        if not any(judge_rx.match(l) for l in body):
            print("%s:%d: git add 로 경로를 정하는 펜스가 check-path · roadmap-check 를 부르지 않는다" % (path, start))
print("세었다: get %d · add %d" % (n_get, n_add))
PY
}
shape_out="$(shape "${files[@]}")"
assert_eq "$(printf '%s\n' "$shape_out" | grep -v '^세었다: ')" "" "펜스 꼴: 해결자 값은 rc · 빈 값을 확인하고, git add 범위 펜스는 경로를 판정한다"
get_n="$(printf '%s\n' "$shape_out" | sed -n 's/^세었다: get \([0-9]*\) · add [0-9]*$/\1/p')"
add_n="$(printf '%s\n' "$shape_out" | sed -n 's/^세었다: get [0-9]* · add \([0-9]*\)$/\1/p')"
[ "${get_n:-0}" -ge 1 ] && ok "펜스 꼴(양의 짝): 해결자 값 줄 ${get_n}개를 읽었다" || no "펜스 꼴(양의 짝): 해결자 값 줄이 없다 — 위 단언이 공허하다"
[ "${add_n:-0}" -ge 2 ] && ok "펜스 꼴(양의 짝): git add 범위 펜스 ${add_n}개를 읽었다" || no "펜스 꼴(양의 짝): git add 범위 펜스가 ${add_n:-0}개 — 위 단언이 공허하다"
shape_mut() {  # shape_mut <대상> <sed 식> <기대 사유> <라벨> [nocheck] — 사본을 바꿔 그 사유가 나오는지
  local c="$T/shape-$(basename "$1")"
  sed "$2" "$SD/$1" > "$c"
  if [ "${5:-}" != nocheck ] && cmp -s "$SD/$1" "$c"; then no "변이(${4}): 사본이 그대로다 — 판정이 공허하다"; return; fi
  case "$(shape "$c")" in *"$3"*) ok "변이(${4}): 잡는다" ;; *) no "변이(${4}): 못 잡는다" ;; esac
}
RF_T=skills/request-framing/SKILL.md
shape_mut "$RF_T" 's/ || IDIR=""$//' "rc 확인 꼴이 아니다" "rc 확인 지움"
shape_mut "$RF_T" '/^\[ -n "\$IDIR" \]/d' "빈 값을 확인하지 않는다" "빈 값 확인 지움"
shape_mut "$RF_T" '/repo_defaults\.py" check-path interview_dir "\$AUDIT"/d' "check-path · roadmap-check 를 부르지 않는다" "handoff 펜스의 check-path 지움"
shape_mut "$RF_T" 's/^python3 \(.*repo_defaults\.py" check-path interview_dir "\$AUDIT"\)/# \1/' "check-path · roadmap-check 를 부르지 않는다" "handoff 펜스의 check-path 를 주석으로"
# finishing 끝내기 커밋 펜스의 판정 줄은 Task 7 이 넣는다 — 그 전에는 사본이 그대로라 nocheck.
shape_mut skills/pm-interview/references/finishing.md '/repo_defaults\.py" \(check-path\|roadmap-check\) /d' "check-path · roadmap-check 를 부르지 않는다" "끝내기 커밋 펜스의 판정 줄 지움" nocheck
finish
