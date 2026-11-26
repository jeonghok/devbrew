**PR 과 머지.** 지휘자는 로드맵을 기본 브랜치에서 읽는다 — 브랜치에만 있는 로드맵은 상태를 셀 수 없고, 에픽 worktree 도 기본 브랜치에서 갈라져 묶음 파일이 없다. 그래서 이 단계가 커밋 뒤 PR 을 열고 머지를 묻는다. PR 을 열지 묻는 조건은 이 단계가 로드맵을 커밋했는가 하나다 — `## 6. 커밋` 의 커밋 펜스가 「로드맵 폴더 · 상태 파일을 커밋했다」 줄이나 「로드맵 폴더 · 상태 파일은 이미 커밋돼 있다」 줄(앞서 끊긴 로드맵 잡기가 커밋해 둔 것)을 냈을 때만 돈다. 그 줄이 아니면(커밋하지 않음 · 실패) 이 절을 건너뛰고 아래 지휘자 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다. PR 에는 앞 단계(컨텍스트 쌓기)가 커밋한 결과물 · audit 과 이 단계가 커밋한 로드맵 폴더 · 상태 파일이 함께 실린다. 펜스는 모두 마지막 줄이 판결이고, 판결 줄 없이 끝나면(시간 초과 · 끊김 포함) `NONE` 으로 읽는다 — 하나만 다르다: 머지 펜스의 출력에 판결 줄이 없고 `roadmap-merge-requested:` 표시 줄이 있으면 `NONE` 으로 읽지 않고 3 의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 이 절의 펜스는 gh 를 직접 찾거나 부르지 않고 `gh_repo.py` 의 하위 명령으로만 부른다 — 그 모듈이 gh 를 찾고 origin 레포를 명시한다.

**머지 뒤.** 머지가 확인되면 언제나 지휘자를 부르는 명령 줄을 보이고 턴을 끝낸다 — 마지막 줄이 `roadmap-merge: MERGED` 인 턴이다(다시 확인 펜스의 `MERGED` 도 같다). 같은 턴에 지휘자를 부르지 않는다. `MERGED` 여도 출력에 「머지 뒤 origin 을 받지 못했다」 줄이 있으면 그 줄을 함께 보인다(받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다). 그 밖(이 절을 건너뜀 · `roadmap-pr: NONE` · `roadmap-merge: NONE` · 「직접 머지」)에는 PR 주소(있으면)와 아래 지휘자 줄을 보이고, 그 커밋이 기본 브랜치에 머지된 뒤 그 줄을 입력하라고 알린 뒤 턴을 끝낸다.

1. **PR 열기.** 아래 펜스의 `BRIEF` 자리표를 결과물 절대경로로 바꿔 돌리고 나온 `[spec-distill]` 줄을(그 아래 파일 줄까지) 그대로 보인다. 펜스는 그 브랜치에서 기본 브랜치로 가는 이 레포 안 브랜치의 열린 PR 을 찾고, 브랜치를 push 한 뒤, 찾은 PR 이 있으면 그것을, 없으면 새 PR 을 연다. 이어서 그 PR 이 바꾸는 파일 가운데 의도 폴더 바로 아래(결과물이 옛 의도 폴더에 있으면 그 결과물 · audit · 상태 파일만 — 옛 폴더는 통째로 빼지 않는다)도 brief §7 의 로드맵 폴더도 원자료(framing 기록 · seed — 옛 의도 폴더에 있어도)도 아닌 것을 세어 `roadmap-pr-files:` 줄로 낸다 — `ONLY`(그런 파일이 없다) · `MIXED`(있다 — 목록을 보인다) · `UNKNOWN`(세지 못했다). 두 폴더와 원자료 두 파일은 커밋 펜스와 같은 판정(`check-path`)을 통과한 것만 빼고 센다 — 통과하지 못한 폴더 · 파일은 밖의 파일로 센다. push 한 끝 커밋은 `roadmap-pr-head: <커밋>` 줄로 낸다 — 3 의 머지가 이 커밋에 묶인다. `roadmap-pr: OPEN <PR 주소>` 면 2 로, `roadmap-pr: NONE` 이면 지휘자 줄 앞에 지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.

<!-- roadmap-pr:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
none() { echo "[spec-distill] PR 을 열지 않았다 — $1. 브랜치를 push 하고 PR 을 직접 열어 머지한 뒤 지휘자를 부른다."; echo "roadmap-pr: NONE"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다(결과물 절대경로로 바꿔 다시 돌려라)" ;; esac
cwd_l="$(pwd -L)"
case "$BRIEF" in "$cwd_l"/*) BRIEF="$(pwd -P)/${BRIEF#"$cwd_l"/}" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] && [ "$cur" != "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
url="$(python3 "$SD/scripts/gh_repo.py" pr-open --head "$cur" --base "$def" --root "$top")" || none "열린 PR 을 찾지 못했다(위 사유)"
head_sha="$(git -C "$top" rev-parse --verify -q "refs/heads/${cur}^{commit}")" || head_sha=""
[ -n "$head_sha" ] || none "지금 브랜치의 끝 커밋을 읽지 못했다"
git -C "$top" push -q -u origin "$cur" || none "push 가 실패했다(위 사유)"
# 원자료를 알 때만 framing 기록 · seed 를 댄다(PR 본문 · 파일 세기) — seed 경로는 상태 파일의 seed 값(레포 상대)이고 기록 경로에서 짓지 않는다.
RAW_A=""
RAW_S=""
rv="$(python3 "$SD/scripts/raw_source.py" locate --interview "$BRIEF" --absolute 2>/dev/null)" || rv=""
case "$rv" in "raw-source: FOUND "*)
  RAW_A="${rv#raw-source: FOUND }"
  sv="$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^seed:/{sub(/^seed:[ \t]*/,""); print; exit}' "${BRIEF%.md}.state.md" 2>/dev/null | tr -d "\"'")" || sv=""
  case "$sv" in ""|"없음") ;; *) RAW_S="${top}/${sv}" ;; esac ;;
esac
if [ -z "$url" ]; then
  bf="$(mktemp)" || none "PR 본문 임시 파일을 만들지 못했다"
  rel="${BRIEF#"$top"/}"
  case "$rel" in /*) rel="$(basename -- "$BRIEF")" ;; esac
  more=""
  [ -z "$RAW_A" ] || more="${more} · framing 기록 \`${RAW_A#"$top"/}\`"
  [ -z "$RAW_S" ] || more="${more} · seed \`${RAW_S#"$top"/}\`"
  printf '## Summary\n- 결과물 · audit · 상태 파일과 로드맵 폴더를 올린다(앞 단계의 커밋과 로드맵 잡기의 커밋이 함께 실린다): `%s`%s\n- 머지되면 지휘자(`/spec-distill:epic-conductor`)가 이 로드맵을 기본 브랜치에서 읽어 에픽을 시작한다.\n' "$rel" "$more" > "$bf"
  url="$(python3 "$SD/scripts/gh_repo.py" pr-create --head "$cur" --base "$def" --title "$(git -C "$top" log -1 --format=%s)" --body-file "$bf" --root "$top")" || url=""
  rm -f "$bf"
  case "$url" in https://*/pull/[0-9]*) ;; *) none "PR 을 만들지 못했다(위 사유)" ;; esac
  echo "[spec-distill] PR 을 열었다 — $url"
else
  echo "[spec-distill] 이 브랜치의 열린 PR 을 쓴다 — $url"
fi
# 이 PR 이 바꾸는 파일 가운데 의도 폴더 바로 아래도 brief §7 의 로드맵 폴더도 원자료 두 파일도 아닌 것. 두 폴더와 원자료는 커밋 펜스와 같은 판정을 통과한 것만 뺀다.
# 끝내기 커밋 펜스가 같은 키로 이미 보인 「값의 출처」 줄만 뺀다 — 그 호출의 사유 · 알림 · 경고 줄과 종료 코드는 그대로다.
nosrc() {
  nf="$(mktemp)" || nf=""
  [ -n "$nf" ] || { "$@"; return; }
  n_rc=0
  "$@" 2> "$nf" || n_rc=$?
  grep -v '^\[spec-distill\] 값의 출처: ' "$nf" >&2
  rm -f "$nf"
  return "$n_rc"
}
idir=""
ob=""
if nosrc python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$BRIEF" --root "$top"; then
  # 그 폴더가 새 꼴 이름도 받는 정해진 의도 폴더면 폴더째 뺀다. 옛 꼴 이름만 받는 옛 의도 폴더면 결과물 짝 세 파일만 하나씩 뺀다.
  if python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$(dirname -- "$BRIEF")/probe-context.md" --root "$top" 2>/dev/null; then
    idir="$(dirname -- "$BRIEF")"
  else
    ob="${BRIEF%.md}"
  fi
else
  echo "[spec-distill] brief 가 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다."
fi
# 원자료(framing 기록 · seed)는 판정을 통과한 파일만 하나씩 뺀다 — 옛 의도 폴더의 옛 꼴 seed 로 새로 시작한 일도 그 둘을 받는다. 이미 뺀 brief 폴더 안의 것은 다시 재지 않는다.
xa=""
xs=""
if [ -n "$RAW_A" ] && [ "$(dirname -- "$RAW_A")" != "$idir" ]; then nosrc python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$RAW_A" --root "$top" && xa="$RAW_A" || echo "[spec-distill] framing 기록 파일이 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유) — 그 파일도 밖의 파일로 센다."; fi
if [ -n "$RAW_S" ] && [ "$(dirname -- "$RAW_S")" != "$idir" ]; then nosrc python3 "$SD/scripts/repo_defaults.py" check-path intent_dir "$RAW_S" --root "$top" && xs="$RAW_S" || echo "[spec-distill] seed 파일이 정해진 의도 폴더(옛 꼴 파일은 옛 의도 폴더) 바로 아래가 아니다(위 사유) — 그 파일도 밖의 파일로 센다."; fi
r7="$(awk -v p='분해됨 — ' 'index($0,"## 7.")==1{f=1;next} f&&/^## /{exit} f{l=$0; sub(/^[ \t]*(- )?`?/,"",l); if(index(l,p)==1){l=substr(l,length(p)+1); sub(/`.*$/,"",l); sub(/[ \t]+$/,"",l); print l; exit}}' "$BRIEF" 2>/dev/null)" || r7=""
rdir=""
if [ -n "$r7" ]; then
  case "$r7" in "$cwd_l"/*) r7="$(pwd -P)/${r7#"$cwd_l"/}" ;; esac
  case "$r7" in /*) ;; *) r7="${top}/${r7}" ;; esac
  rdir="$(dirname -- "$r7")"
  nosrc python3 "$SD/scripts/repo_defaults.py" check-path roadmaps_dir "$rdir" --root "$top" || { echo "[spec-distill] brief §7 의 로드맵 폴더가 정해진 로드맵 폴더 바로 아래가 아니다(위 사유) — 그 폴더의 파일도 밖의 파일로 센다: ${rdir}"; rdir=""; }
fi
x_rc=0
extra="$(git -C "$top" -c core.quotePath=false diff --name-only "refs/remotes/origin/${def}...${head_sha}" -- . ${idir:+":(exclude,glob)${idir}/*"} ${ob:+":(exclude,literal)${ob}.md"} ${ob:+":(exclude,literal)${ob}.audit.md"} ${ob:+":(exclude,literal)${ob}.state.md"} ${rdir:+":(exclude)${rdir}"} ${xa:+":(exclude,literal)${xa}"} ${xs:+":(exclude,literal)${xs}"})" || x_rc=$?
if [ "$x_rc" -ne 0 ]; then
  echo "[spec-distill] 이 PR 에 담긴 파일을 세지 못했다(위 사유) — 머지하기 전에 PR 에서 직접 확인한다."
  echo "roadmap-pr-files: UNKNOWN"
elif [ -z "$extra" ]; then
  echo "[spec-distill] 이 PR 은 의도 폴더와 로드맵 폴더의 파일만 담는다."
  echo "roadmap-pr-files: ONLY"
else
  x_n="$(printf '%s\n' "$extra" | wc -l | tr -d ' ')"
  echo "[spec-distill] 이 PR 은 의도 폴더 · 로드맵 폴더 밖의 파일 ${x_n}개도 담는다(스무 개까지 보인다):"
  printf '%s\n' "$extra" | head -n 20 | sed 's/^/  - /'
  echo "roadmap-pr-files: MIXED"
fi
echo "roadmap-pr-head: $head_sha"
echo "roadmap-pr: OPEN $url"
```
<!-- roadmap-pr:end -->

2. **머지 묻기.** `AskUserQuestion` 하나 — 질문 「<주제> — 지휘자는 로드맵을 기본 브랜치에서 읽어, 이 PR(<PR 주소>)이 머지돼야 에픽을 시작할 수 있다. 지금 머지할까?」, 선택지 「머지 (권장)」(얻음: CI 검사 뒤 PR 을 기본 브랜치에 합치고 지휘자 줄을 바로 보인다 · 내줌: 합친 뒤에는 되돌리기 번거롭고 CI 를 기다리는 동안 턴이 끝난 채 멈춰 있다) · 「직접 머지」(얻음: 머지 시점과 방식을 내가 정한다 · 내줌: 머지한 뒤 지휘자 줄을 직접 입력해야 해서 한 단계가 사람 몫으로 남는다). 「(권장)」 꼬리는 1 의 펜스가 `roadmap-pr-files: ONLY` 를 냈을 때만 단다 — 그 두 폴더(의도 폴더 바로 아래 · 로드맵 폴더)의 파일만 바꾸는 PR 이라 머지를 권한다. `MIXED` 나 `UNKNOWN` 이면 꼬리를 떼어 「머지」 로 내고, 질문 앞 글에 1 의 펜스가 보인 파일 목록(세지 못했으면 그 줄)을 다시 보인다 — 무엇이 함께 머지되는지 보고 고르게 한다. 답은 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.
3. **머지.** 「머지」면 아래 펜스의 `BRIEF` 자리표를 1 과 같은 값으로, `URL` 자리표를 1 의 PR 주소로, `HEAD_SHA` 자리표를 1 의 `roadmap-pr-head:` 값으로 바꿔 Bash 도구의 백그라운드 실행으로 돌린다(CI 를 기다리는 동안 도구 시간 상한에 걸리지 않게 — 끝나면 알림이 온다). 띄운 턴에는 `[spec-distill] PR 머지를 기다린다 — CI 검사가 끝나면 머지하고 이어 간다(검사는 30분까지 기다린다): <PR 주소>` 한 줄을 보이고 턴을 끝낸다 — 지휘자 줄은 아직 보이지 않는다. 알림이 온 턴에 출력의 `[spec-distill]` 줄을 그대로 보이고 판결대로 잇는다. 알림보다 먼저 사용자가 말을 걸면 그 턴에 백그라운드 출력을 읽어, 판결 줄이 있으면 판결대로 잇고 없으면 아직 기다리는 중이라고 답한다. 사용자가 그만두라고 하면 그 백그라운드 작업을 끝낸다(작업을 끝내면 펜스가 기다리던 gh 도 함께 끝나 머지로 가지 않는다) — 끝낸 출력에 판결 줄이 이미 있으면 그 판결대로 잇는다. 판결 줄이 없고 `roadmap-merge-requested:` 표시 줄이 있으면 머지 요청이 이미 나갔을 수 있다 — `NONE` 으로 읽지 않고 머지 펜스 아래의 다시 확인 펜스를 돌려 그 판결대로 잇는다. 표시 줄도 없으면 `roadmap-merge: NONE` 으로 읽어 잇는다. 이 기다림은 polite stop 이 아니다 — 지휘자 줄을 보이고 턴을 끝내는 완료 동작은 판결을 받은 턴에 한다. 펜스는 PR 주소의 레포가 origin 인지 대조하고, 그 PR 이 열려 있고 이 레포 안의 지금 브랜치에서 기본 브랜치로 가는 PR 이며 끝 커밋이 1 에서 push 한 커밋 그대로인지 먼저 확인한다. 그 PR 이 이미 머지돼 있으면(상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR) 검사를 기다리지도 머지를 요청하지도 않고 머지됨으로 읽는다 — origin 을 받고 판결은 `MERGED` 다. 머지도 그 커밋에 묶어 요청한다 — 묻고 난 뒤(CI 를 기다리는 사이 포함) PR 에 다른 커밋이 올라오면 머지하지 않는다. 막 연 PR 은 CI 가 아직 붙지 않았을 수 있어 「검사 없음」을 1분 동안 다시 본 뒤에야 받아들이고, 검사가 있으면 끝나길 30분까지 기다린다 — 실패한 검사가 있거나 30분을 넘기면 머지하지 않는다. 머지 방식은 그 레포가 허용하는 것 가운데 merge commit → squash → rebase 순서로 시도하고, 하나가 거절되면(보호 규칙 등) 다음 것을 시도한다. 방식마다 요청을 보내기 직전에 표시 줄 `roadmap-merge-requested: <PR 번호>` 를 낸다. gh 의 머지 명령이 실패로 끝났어도 다시 읽은 PR 이 머지돼 있으면 다음 방식을 시도하지 않고 머지됨으로 읽는다. gh 가 머지를 받아들이면 PR 상태를 다시 읽는다 — 머지 대기열이나 자동 머지를 쓰는 레포에서는 gh 가 요청만 걸어 두고 성공으로 끝나므로, 상태가 `MERGED` 가 아니면 판결은 `NONE` 이다. `MERGED` 면 origin 을 받아 지휘자가 읽는 로컬의 기본 브랜치 ref 를 맞춘다 — 받지 못하면 그 사실을 알리고 판결은 `MERGED` 그대로다. 마지막 줄이 `roadmap-merge: MERGED` 면 지휘자 줄을 보이고 턴을 끝내며(머지 안내 없이), `roadmap-merge: NONE` 이거나 「직접 머지」면 지휘자 줄 앞에 PR 주소와 함께 지휘 세션을 이 PR 이 기본 브랜치에 머지된 뒤 열라고 한 줄로 알린다.

<!-- roadmap-merge:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
URL="<roadmap-pr 이 낸 PR 주소>"
HEAD_SHA="<roadmap-pr 이 낸 끝 커밋>"
none() { echo "[spec-distill] 머지하지 않았다 — $1. 직접 머지한 뒤 지휘자를 부른다: ${URL}"; echo "roadmap-merge: NONE"; exit 0; }
merged() { git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."; echo "roadmap-merge: MERGED"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
case "$HEAD_SHA" in ""|*[!0-9a-f]*) none "끝 커밋이 비었거나 자리표 그대로다" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || none "PR 을 읽지 못했다(위 사유)"
# 이미 머지된 PR — 상태가 머지됨이고 바탕 · 브랜치가 같은 이 레포의 PR 이면 머지됨으로 읽는다(끝 커밋은 대조하지 않는다).
case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] PR 이 이미 머지돼 있다 — ${URL}"; merged ;; esac
[ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "이 PR 은 열린, 이 레포의 ${cur} → ${def} PR 이 아니거나 끝 커밋이 물을 때(${HEAD_SHA})와 다르다(읽은 것: ${pr})"
out="$(mktemp)" || none "검사 출력 임시 파일을 만들지 못했다"
n=0
while :; do
  ck_rc=0
  python3 "$SD/scripts/gh_repo.py" pr-checks "$num" --root "$top" > "$out" 2>&1 || ck_rc=$?
  grep -q "no checks reported" "$out" || break
  n=$((n + 1))
  [ "$n" -lt 6 ] || break
  sleep 10
done
if ! grep -q "no checks reported" "$out"; then
  python3 "$SD/scripts/gh_repo.py" pr-checks "$num" --watch --interval 15 --root "$top" > "$out" 2>&1 &
  w=$!
  n=0
  while kill -0 "$w" 2>/dev/null; do
    [ "$n" -lt 120 ] || { kill "$w" 2>/dev/null; rm -f "$out"; none "CI 검사를 30분 기다려도 끝나지 않았다"; }
    sleep 15
    n=$((n + 1))
  done
  ck_rc=0
  wait "$w" || ck_rc=$?
  [ "$ck_rc" -eq 0 ] || { tail -n 20 "$out"; rm -f "$out"; none "CI 검사가 통과하지 않았다(rc ${ck_rc}, 위 목록)"; }
fi
rm -f "$out"
ways="$(python3 "$SD/scripts/gh_repo.py" merge-ways --root "$top")" || ways=""
[ -n "$ways" ] || none "레포가 허용하는 머지 방식을 읽지 못했다(위 사유)"
how=""
for how in --merge --squash --rebase; do
  case " $ways " in *" $how "*) ;; *) continue ;; esac
  # 요청을 보내기 직전의 표시 줄 — 판결 줄 없이 끝난 출력에 이 줄이 있으면 다시 확인 펜스가 돈다.
  echo "roadmap-merge-requested: $num"
  if python3 "$SD/scripts/gh_repo.py" pr-merge "$num" "$how" --match-head-commit "$HEAD_SHA" --root "$top"; then
    # gh 가 받아들였어도 머지 대기열 · 자동 머지면 아직 머지 전이다 — 상태를 다시 읽는다(15초까지).
    st=""
    n=0
    while :; do
      st="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || st=""
      st="${st%% *}"
      n=$((n + 1))
      [ "$st" != "MERGED" ] && [ "$n" -lt 4 ] || break
      sleep 5
    done
    if [ "$st" != "MERGED" ]; then
      echo "[spec-distill] gh 는 머지 요청을 받았지만 PR 이 아직 머지되지 않았다(읽은 상태: ${st:-읽지 못함}) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"
      echo "roadmap-merge: NONE"
      exit 0
    fi
    echo "[spec-distill] PR 을 머지했다(${how#--}) — ${URL}"
    merged
  fi
  pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
  case "$pr" in "MERGED $def $cur false "*) echo "[spec-distill] gh 의 머지 명령은 실패로 끝났지만(위 사유) PR 은 머지돼 있다 — ${URL}"; merged ;; esac
  [ "$pr" = "OPEN $def $cur false $HEAD_SHA" ] || none "머지가 거절됐고(위 사유) PR 이 물을 때와 달라졌다 — 끝 커밋이 바뀌었거나 닫혔다(읽은 것: ${pr:-읽지 못함} · 물을 때의 끝 커밋: ${HEAD_SHA})"
  echo "[spec-distill] ${how#--} 머지가 거절됐다(위 사유) — 다음 방식을 시도한다."
done
none "허용된 머지 방식이 모두 거절됐다(위 사유 — 충돌 · 보호 규칙 · 권한)"
```
<!-- roadmap-merge:end -->

**다시 확인 — 판결 줄 없이 끝난 머지 펜스의 출력에 `roadmap-merge-requested:` 표시 줄이 있을 때만.** 아래 펜스의 `BRIEF` · `URL` 자리표를 3 과 같은 값으로 바꿔 돌리고(백그라운드로 띄우지 않고 15초까지만 기다린다) 나온 `[spec-distill]` 줄을 그대로 보인 뒤 그 판결대로 잇는다. 펜스는 읽기만 한다 — 머지를 요청하지도 CI 검사를 기다리지도 않는다. PR 주소의 레포가 origin 인지 대조하고, PR 상태를 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수(5초 간격 네 번까지)로 읽는다. 상태가 머지됨이고 이 레포 안의 지금 브랜치에서 기본 브랜치로 간 PR 이면 origin 을 받고 `roadmap-merge: MERGED`, 끝까지 아니면 머지 요청이 나갔다는 사실과 PR 주소를 알리고 `roadmap-merge: NONE` 이다 — PR 상태를 끝까지 읽지 못했을 때(gh 인증 · 네트워크)도 머지됨으로 읽지 않고, 읽지 못했다는 사실을 따로 알린다.

<!-- roadmap-merge-recheck:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
BRIEF="<결과물 절대경로>"
URL="<roadmap-pr 이 낸 PR 주소>"
none() { echo "[spec-distill] 머지됐는지 다시 확인하지 못했다 — $1. 머지 요청은 나갔을 수 있다 — PR 에서 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"; echo "roadmap-merge: NONE"; exit 0; }
case "$BRIEF" in ""|*"<"*) none "BRIEF 가 비었거나 자리표 그대로다" ;; esac
case "$URL" in https://*/pull/[0-9]*) ;; *) none "PR 주소가 비었거나 자리표 그대로다" ;; esac
top="$(git -C "$(dirname -- "$BRIEF")" rev-parse --show-toplevel 2>/dev/null)" || top=""
[ -n "$top" ] || none "git 저장소가 아니다"
cur="$(git -C "$top" branch --show-current 2>/dev/null)" || cur=""
def="$(python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote --root "$top")" || def=""
[ -n "$cur" ] && [ -n "$def" ] || none "지금 브랜치(${cur:-없음})나 기본 브랜치(${def:-없음})를 가르지 못했다"
num="$(python3 "$SD/scripts/gh_repo.py" pr-number "$URL" --root "$top")" || none "PR 주소가 이 레포(origin)의 PR 이 아니다(위 사유)"
# 요청 직후에는 아직 열림으로 보일 수 있다 — 머지 펜스의 머지 뒤 상태 읽기와 같은 간격 · 횟수로 읽는다(15초까지).
pr=""
n=0
while :; do
  pr="$(python3 "$SD/scripts/gh_repo.py" pr-identity "$num" --root "$top")" || pr=""
  n=$((n + 1))
  case "$pr" in "MERGED $def $cur false "*) break ;; esac
  [ "$n" -lt 4 ] || break
  sleep 5
done
case "$pr" in
  "MERGED $def $cur false "*)
    echo "[spec-distill] 다시 확인하니 PR 이 머지돼 있다 — ${URL}"
    git -C "$top" fetch -q origin || echo "[spec-distill] 머지 뒤 origin 을 받지 못했다(위 사유) — 지휘자를 부르기 전에 git fetch origin 을 돌린다. 받기 전에는 지휘자가 이 로드맵을 기본 브랜치에서 찾지 못한다."
    echo "roadmap-merge: MERGED" ;;
  "MERGED "*)
    echo "[spec-distill] 머지 요청은 나갔지만 읽은 PR 이 이 레포의 ${cur} → ${def} PR 이 아니다(읽은 것: ${pr}) — PR 에서 직접 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "roadmap-merge: NONE" ;;
  "")
    echo "[spec-distill] 머지 요청은 나갔지만 PR 상태를 읽지 못했다(위 사유) — 머지됐는지 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "roadmap-merge: NONE" ;;
  *)
    st="${pr%% *}"
    echo "[spec-distill] 머지 요청은 나갔지만 PR 이 아직 머지되지 않았다(읽은 상태: ${st}) — 머지 대기열이나 자동 머지를 쓰는 레포면 조건이 채워진 뒤 머지된다. 머지된 것을 확인한 뒤 지휘자를 부른다: ${URL}"
    echo "roadmap-merge: NONE" ;;
esac
```
<!-- roadmap-merge-recheck:end -->
