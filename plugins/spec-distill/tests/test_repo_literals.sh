#!/usr/bin/env bash
# R5 AC29 — 지휘자 skill · reference · 새 스크립트 · 통합 리뷰어에 레포 전용 리터럴(기본 브랜치 이름 · 브랜치 접두 ·
# 레포 구조 경로 · 모델 이름)이 없다. 외부 도구 기본 경로와 자기 상태 경로는 repo_defaults.py 상수에만 있다.
# 이빨은 변이로 잰다 — 표기 · 값 · 위치 · 부정문 네 축, 그리고 대상 하나하나가 실제로 읽히는지.
# 알려진 한계(리뷰가 본다): 문자열 이어 붙이기(`"ori" + "gin/main"`) · 쪼갠 경로 조각 · main/master 가 아닌 다른
# 원격 · 브랜치 이름 · 목록에 없는 모델 표기.
# 면제는 줄 꼴 하나 — 처분 앵커 줄(`**처분** — consumer=<경로>`, 앞의 `//` · `#` 허용)의 consumer 값만 지우고 나머지는
# 스캔한다. 그 값은 레포 기준 추적 경로여야 하고 그 꼴은 shared/tests/test_dispatch_disposition.sh 가 집행한다.
# 펜스 꼴 축(R8 AC4): 해결자 값을 받는 줄은 `<V>="$(… get …)" || <V>=""` 이고 다음 비지 않은 줄이 빈 값을 확인한다.
# `git add --` 로 경로를 정하는 펜스는 add 앞에서 add 의 경로 변수마다 해결자 판정(check-path · roadmap-check, `|| … exit`)을
# 거친다 — 판정 줄이 그 변수를 직접 받거나, 그 변수가 판정받은 변수에서 명령 치환 없는 대입으로만 나온다. 로드맵 판정
# (check-path roadmaps_dir · roadmap-check)을 하나라도 부르는 펜스는 둘 다 부른다(자리와 표지는 다른 검사다).
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
judged_rx = re.compile(r'repo_defaults\.py" (check-path (\w+)|roadmap-check) "\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?"')
stop_rx = re.compile(r'\|\|.*\bexit\b')
use_rx = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)')


def assigns(line, name):
    return re.search(r'(?:^|[\s;)])' + name + '=', line) is not None


def refills(line, name):
    """빈 값이 아닌 대입 — `X=""` 는 add 범위를 좁힐 뿐이라 다시 대입으로 치지 않는다."""
    vals = re.findall(r'(?:^|[\s;)])' + name + r'=("[^"]*"|\'[^\']*\'|[^\s;]*)', line)
    return any(v not in ("", '""', "''") for v in vals)


def covered_vars(body, judged, barred=frozenset()):
    """판정받은 변수 + 명령 치환 없는 대입으로만 그것들에서 나온 변수(고정점). barred 는 덮지 않는다."""
    cov = set(judged)
    names = {m for l in body for m in re.findall(r'(?:^|[\s;)])([A-Za-z_][A-Za-z0-9_]*)=', l)}
    grew = True
    while grew:
        grew = False
        for v in names - cov - set(barred):
            lines = [l for l in body if assigns(l, v) and set(use_rx.findall(l)) - {v}]
            if lines and all("$(" not in l and "`" not in l and set(use_rx.findall(l)) - {v} <= cov for l in lines):
                cov.add(v)
                grew = True
    return cov
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
        elif not stop_rx.search(nxt):
            print("%s:%d: 해결자 값이 비면 셸을 멈추지 않는다(|| … exit 없음)" % (path, i + 1))
    for start, _end, body in bash_fences("\n".join(lines)):
        if not any(add_rx.search(l) for l in body):
            continue
        n_add += 1
        first_add = next(i for i, l in enumerate(body) if add_rx.search(l))
        judges = [l for l in body if judge_rx.match(l)]
        if not judges:
            print("%s:%d: git add 로 경로를 정하는 펜스가 check-path · roadmap-check 를 부르지 않는다" % (path, start))
            continue
        if not all(stop_rx.search(l) for l in judges):
            print("%s:%d: git add 로 경로를 정하는 펜스의 경로 판정이 거부되어도 셸을 멈추지 않는다(|| … exit 없음)" % (path, start))
        kinds, judged = set(), {}
        for i, l in enumerate(body[:first_add]):
            if judge_rx.match(l) and stop_rx.search(l):
                for m in judged_rx.finditer(l):
                    kinds.add(m.group(2) or "roadmap-check")
                    judged.setdefault(m.group(3), i)
        reassigned = {v for v, i in judged.items() if any(refills(l, v) for l in body[i + 1:first_add])}
        if kinds & {"roadmaps_dir", "roadmap-check"} and not {"roadmaps_dir", "roadmap-check"} <= kinds:
            print("%s:%d: 로드맵 폴더를 더하는 펜스가 check-path roadmaps_dir 와 roadmap-check 를 함께 부르지 않는다" % (path, start))
        cov = covered_vars(body, set(judged) - reassigned, reassigned)
        added = {v for l in body if add_rx.search(l) for v in use_rx.findall(l.split(" add --", 1)[1])}
        for v in sorted(added - cov):
            if v in reassigned:
                print("%s:%d: git add 경로 $%s 를 판정 뒤 다시 대입한다" % (path, start, v))
            else:
                print("%s:%d: git add 경로 $%s 를 add 앞에서 판정하지 않는다" % (path, start, v))
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
shape_mut "$RF_T" 's/^\[ -n "\$IDIR" \] || .*$/[ -n "$IDIR" ] || true/' "비면 셸을 멈추지 않는다" "빈 값 확인을 || true 로"
shape_mut "$RF_T" 's/^\(python3 .*repo_defaults\.py" check-path interview_dir "\$AUDIT"\) || .*$/\1/' "거부되어도 셸을 멈추지 않는다" "handoff check-path 의 rc 처리 지움"
shape_mut "$RF_T" 's/^\(python3 .*repo_defaults\.py" check-path interview_dir "\$AUDIT"\) || .*$/\1 || true/' "거부되어도 셸을 멈추지 않는다" "handoff check-path 를 || true 로"
shape_mut "$RF_T" '/repo_defaults\.py" check-path interview_dir "\$AUDIT"/d' "경로 \$AUDIT 를 add 앞에서 판정하지 않는다" "handoff 펜스의 AUDIT 판정 지움"
shape_mut "$RF_T" 's/^python3 \(.*repo_defaults\.py" check-path interview_dir "\$AUDIT"\)/# \1/' "경로 \$AUDIT 를 add 앞에서 판정하지 않는다" "handoff 펜스의 AUDIT 판정을 주석으로"
shape_mut "$RF_T" '/repo_defaults\.py" check-path interview_dir /d' "check-path · roadmap-check 를 부르지 않는다" "handoff 펜스의 판정 줄 둘 다 지움"
shape_mut "$RF_T" '/repo_defaults\.py" check-path interview_dir "\$SEED"/d' "경로 \$SEED 를 add 앞에서 판정하지 않는다" "handoff 펜스의 SEED 판정 지움"
shape_mut "$RF_T" '/^git add -- "\$AUDIT"/{h;s/.*/AUDIT="$SEED"/;G;}' "git add 경로 \$AUDIT 를 판정 뒤 다시 대입한다" "handoff 펜스의 판정과 add 사이 AUDIT 재대입"
shape_mut "$RF_T" '/^git add -- "\$AUDIT"/{h;s/.*/AUDIT="$(printf %s x)"/;G;}' "git add 경로 \$AUDIT 를 판정 뒤 다시 대입한다" "handoff 펜스의 판정과 add 사이 AUDIT 명령 치환 재대입"
rf_pre="$T/shape-pre-$(basename "$RF_T")"
sed '/check-path interview_dir "\$AUDIT"/{h;s/.*/AUDIT="$SEED"/;G;}' "$SD/$RF_T" > "$rf_pre"
if cmp -s "$SD/$RF_T" "$rf_pre"; then no "음성 대조(판정 앞 대입): 사본이 그대로다 — 판정이 공허하다"
else
  case "$(shape "$rf_pre")" in *"다시 대입한다"*|*"판정하지 않는다"*) no "음성 대조(판정 앞 대입): 판정 앞의 대입을 잘못 잡는다" ;;
    *) ok "음성 대조(판정 앞 대입): 판정 앞의 대입은 잡지 않는다" ;; esac
fi
FIN_T=skills/pm-interview/references/finishing.md
shape_mut "$FIN_T" '/repo_defaults\.py" check-path /d;/repo_defaults\.py" roadmap-check /d' "check-path · roadmap-check 를 부르지 않는다" "끝내기 커밋 펜스의 판정 줄 지움"
shape_mut "$FIN_T" '/repo_defaults\.py" check-path interview_dir "\$BRIEF"/d' "경로 \$BRIEF 를 add 앞에서 판정하지 않는다" "끝내기 커밋 펜스의 인터뷰 폴더 판정 지움"
shape_mut "$FIN_T" '/repo_defaults\.py" check-path roadmaps_dir "\$RDIR"/d' "함께 부르지 않는다" "끝내기 커밋 펜스의 로드맵 폴더 판정 지움"
shape_mut "$FIN_T" '/repo_defaults\.py" roadmap-check "\$r7"/d' "함께 부르지 않는다" "끝내기 커밋 펜스의 roadmap-check 지움"
shape_mut "$FIN_T" '/repo_defaults\.py" check-path roadmaps_dir /d;/repo_defaults\.py" roadmap-check /d' "경로 \$RDIR 를 add 앞에서 판정하지 않는다" "끝내기 커밋 펜스의 로드맵 판정 둘 다 지움"
shape_mut "$FIN_T" 's/^\( *python3 .*repo_defaults\.py" check-path roadmaps_dir "\$RDIR".*\) || {.*$/\1 || true/' "거부되어도 셸을 멈추지 않는다" "끝내기 커밋 펜스의 로드맵 폴더 판정을 || true 로"
shape_mut "$FIN_T" 's/^AUDIT_F="\${stem}\.audit\.md"$/AUDIT_F="$(printf %s "${stem}").audit.md"/' "경로 \$AUDIT_F 를 add 앞에서 판정하지 않는다" "끝내기 커밋 펜스의 audit 경로를 명령 치환으로"
shape_mut "$FIN_T" '/check-path interview_dir "\$BRIEF"/{h;d;};/ add -- "\$BRIEF"/G' "경로 \$BRIEF 를 add 앞에서 판정하지 않는다" "끝내기 커밋 펜스의 인터뷰 폴더 판정을 add 뒤로"
# 판정 뒤 `RDIR=""`(범위를 좁힘)는 지금 문서에 있고 위 펜스 꼴 단언이 통과시킨다 — 같은 자리에 빈 값이 아닌 값을 넣으면 잡는다
shape_mut "$FIN_T" 's/^    RDIR=""$/    RDIR="$r7"/' "git add 경로 \$RDIR 를 판정 뒤 다시 대입한다" "끝내기 커밋 펜스의 판정 뒤 빈 값 대입을 다른 경로로"
finish
