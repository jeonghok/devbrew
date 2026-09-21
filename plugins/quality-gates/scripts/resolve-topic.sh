#!/usr/bin/env bash
# resolve-topic.sh — 선언(`Spec:` 커밋 트레일러) → 커밋 집합 → 경계 · 끝점.
#   (설계 2026-09-21 §6.2, AC3·AC4·AC5·AC15·AC16)
#
# Subcommands:
#   resolve <topic-key>   -> key: value 요약 9줄
#   commits <topic-key>   -> T 의 커밋 SHA (topo-order), 한 줄에 하나
#
# **사실만 낸다 — 판정하지 않는다.** `resolve-baseline.sh` 와 같은 계약이다:
# 고정 키 집합 · 없는 값은 `-`. `resolve` 는 정상 경로에서 언제나 exit 0(판정은 `status:`
# 값으로 낸다) — `commits` 는 다르다, status != ok 이면 fail-closed 로 exit 3 이다(:47–53).
# `not-certified` 같은 판정 어휘는 이 층에 없다 — 소비자(PR4)가 `status:` 를 판정으로 옮긴다.
#
#   status: ok                  선언 경로로 진행
#   status: no-declaration      선언 0 — 기존 세 모드로 fallback (판정 아님)
#   status: declaration-invalid 선언이 깨졌다 (경로 부재 · 한 브랜치에 여러 키)
#   status: base-unresolved     base_ref 미해결 — 기준선 축을 세울 수 없다
#
# **토픽 키는 트레일러 값 «전체»다 — 조각(`#pr1`)까지 포함한다.** 조각을 무시하는
# 질의를 쓰면 여러 PR 이 한 토픽으로 합쳐진다(설계 §6.2.1 · §16).
#
# **`tips:` 는 콤마-구분이다.** `combine-tips.sh` 에 그대로 넘기지 않는다 — 그쪽은
# 공백-구분 인자를 받는다. 호출부가 변환한다(예: `tr ',' ' '`).
#
# bash 3.2 호환: 배열 대신 공백 구분 문자열을 쓴다.
set -u

die() { echo "resolve-topic: $*" >&2; exit 2; }

SUB="${1:-}"; TOPIC="${2:-}"
case "$SUB" in
  resolve|commits) ;;
  *) die "usage: resolve-topic.sh {resolve|commits} <topic-key>" ;;
esac
[ -n "$TOPIC" ] || die "empty topic key"

SEAL=""
if [ "${3:-}" = "--seal" ]; then
  SEAL="${4:-}"
  [ -n "$SEAL" ] || die "--seal needs a commit"
  git rev-parse --verify --quiet "$SEAL^{commit}" >/dev/null 2>&1 || die "not a commit: $SEAL"
elif [ -n "${3:-}" ]; then
  die "unknown option: $3"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

DECLARED="-"; BRANCHES="-"; BOUNDARY="-"; TIPS="-"; NCOMMITS="-"; BASE_REF="-"

emit() {   # <status> <reason>
  # `commits` 는 fail-closed 다 — status != ok 이면 stdout 에 «아무것도» 내지 않는다.
  # 이 검사는 echo 들보다 «앞» 이어야 한다. 뒤에 두면 9줄이 이미 나간 뒤라
  # 소비자가 `$(… commits …)` 로 받을 때 SHA 아닌 9줄을 순회한다.
  if [ "$SUB" = "commits" ] && [ "$1" != "ok" ]; then
    echo "resolve-topic: status=$1 (${2:--}) — no commit set" >&2
    exit 3
  fi
  echo "topic_key: $TOPIC"
  echo "status: $1"
  echo "reason: ${2:--}"
  echo "declared: $DECLARED"
  echo "branches: $BRANCHES"
  echo "boundary: $BOUNDARY"
  echo "tips: $TIPS"
  echo "commits: $NCOMMITS"
  echo "base_ref: $BASE_REF"
  exit 0
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit base-unresolved "not a git work tree"

# base_ref 는 기존 모듈이 푼다 — 후보 체인을 두 벌 두지 않는다.
BASE_REF=$(bash "$SCRIPT_DIR/resolve-baseline.sh" | awk -F': ' '/^base_ref:/{print $2}')
[ -n "$BASE_REF" ] && [ "$BASE_REF" != "-" ] || { BASE_REF="-"; emit base-unresolved "resolve-baseline.sh degraded"; }

# ── C = 선언 커밋 ──────────────────────────────────────────────────────────
# git 의 `--grep` 은 기본이 BRE 다. 토픽 키에 `.` 가 흔하므로 메타문자를 이스케이프한다.
# 이스케이프를 빼면 `x-design.md` 의 `.` 가 임의 문자가 되어 다른 토픽을 삼킨다.
esc=$(printf '%s' "$TOPIC" | sed 's/[][\.*^$\\]/\\&/g')
C=$(git log --all --grep="^Spec: ${esc}\$" --format='%H' 2>/dev/null)
DECLARED=$(printf '%s\n' "$C" | grep -c . )
[ "$DECLARED" -gt 0 ] || { DECLARED=0; emit no-declaration "no commit carries this topic key"; }

# ── 선언이 가리키는 경로가 실재하는가 (AC16) ────────────────────────────────
# 토픽 키에서 조각(`#…`)을 떼면 리포-상대 경로다. working tree 기준으로 본다 —
# 선언은 «지금» 무엇을 가리키는가의 문제다.
#
# 존재 검사는 리포-루트 상대다 — cwd 상대(`[ -e "$path" ]`)는 하위 디렉터리에서
# 부른 호출자에게 거짓 declaration-invalid 를 낸다(설계 §6.2.1: 트레일러 값은
# 리포-상대 경로).
path="${TOPIC%%#*}"
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || emit base-unresolved "not a git repo"
[ -e "$repo_root/$path" ] || emit declaration-invalid "declared path does not exist: $path"

# ── B_t 1단계: 살아 있는 ref ───────────────────────────────────────────────
# `git branch --contains` 를 쓰지 않는다 — 머지된 커밋에 대해 main 과 후손 전부를
# 돌려줘 끝점을 식별할 수 없다(설계 §7-C).
BR_NAMES=""; BR_TIPS=""
for ref in $(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null); do
  tip=$(git rev-parse "$ref" 2>/dev/null) || continue
  # base_ref 의 조상인 ref(= main 자신 · 이미 머지돼 tip 이 안 움직인 브랜치)는 뺀다.
  git merge-base --is-ancestor "$tip" "$BASE_REF" 2>/dev/null && continue
  for c in $C; do
    if git merge-base --is-ancestor "$c" "$tip" 2>/dev/null; then
      BR_NAMES="$BR_NAMES $ref"; BR_TIPS="$BR_TIPS $tip"; break
    fi
  done
done

# ── B_t 2단계: 머지된 구성원 ───────────────────────────────────────────────
# 발동 조건은 **「1단계가 낸 B_t 에 들어가지 않으면」** 이다 — 「어느 살아 있는 ref
# 에도 안 걸리면」이 아니다. 머지됐는데 ref 는 살아 있는(가장 흔한) 경로가 그 차이로
# 고아가 되어 AC4 가 깨진다.
ORPHANS=""
for c in $C; do
  in_bt=no
  for tip in $BR_TIPS; do
    git merge-base --is-ancestor "$c" "$tip" 2>/dev/null && { in_bt=yes; break; }
  done
  [ "$in_bt" = yes ] && continue
  m=$(git rev-list --ancestry-path --merges "$c..$BASE_REF" 2>/dev/null | tail -1)
  [ -n "$m" ] || { ORPHANS="$ORPHANS $c"; continue; }
  # 주제 쪽 부모 — `^2` 로 단정하지 않고 c 를 포함하는 부모를 고른다.
  side=""
  for p in $(git rev-list --parents -n 1 "$m" 2>/dev/null | cut -d' ' -f2-); do
    git merge-base --is-ancestor "$c" "$p" 2>/dev/null && { side="$p"; break; }
  done
  [ -n "$side" ] || { ORPHANS="$ORPHANS $c"; continue; }
  dup=no
  for t in $BR_TIPS; do [ "$t" = "$side" ] && { dup=yes; break; }; done
  [ "$dup" = yes ] && continue
  BR_NAMES="$BR_NAMES merged:$side"; BR_TIPS="$BR_TIPS $side"
  # 경계 계산이 쓸 mainline 부모를 짝지어 기억한다.
  MERGED_MAINLINE="${MERGED_MAINLINE:-} $side:$(git rev-parse "$m^1")"
done

# 1·2 가 둘 다 답을 못 낸 선언 커밋은 고아다 (설계 §6.2.2 3단계).
if [ -n "$ORPHANS" ]; then
  first=$(printf '%s' "$ORPHANS" | awk '{print $1}')
  emit declaration-invalid "orphan declaration commit (no containing branch, no merge): ${first:0:8}"
fi

BRANCHES=$(printf '%s\n' $BR_NAMES | sort -u | paste -sd, -)
[ -n "$BRANCHES" ] || BRANCHES="-"

# ── 경계 = fork 들의 merge-base (§6.2.3 · AC5) ─────────────────────────────
# 머지된 구성원에는 merge-base(base_ref, tip) 을 쓸 수 없다 — 그것은 tip 자신을
# 돌려주고, 그러면 그 브랜치 전체가 경계 뒤로 숨는다〔실측 2〕. 대신 그 브랜치를
# 받아들인 머지 커밋의 mainline 부모와의 merge-base 가 진짜 분기점이다〔실측 3〕.
FORKS=""
for tip in $BR_TIPS; do
  ml=""
  for pair in ${MERGED_MAINLINE:-}; do
    case "$pair" in "$tip:"*) ml="${pair#*:}"; break ;; esac
  done
  if [ -n "$ml" ]; then
    f=$(git merge-base "$tip" "$ml" 2>/dev/null)
  else
    f=$(git merge-base "$BASE_REF" "$tip" 2>/dev/null)
  fi
  [ -n "$f" ] || emit base-unresolved "cannot compute fork for ${tip}"
  FORKS="$FORKS $f"
done
FORKS=$(printf '%s\n' $FORKS | sort -u | tr '\n' ' ')
set -- $FORKS
BOUNDARY="$1"; shift
for f in "$@"; do
  BOUNDARY=$(git merge-base "$BOUNDARY" "$f" 2>/dev/null) \
    || emit base-unresolved "merge-base of forks failed"
done
[ -n "$BOUNDARY" ] || emit base-unresolved "empty boundary"

# ── 끝점 = (tips ∪ {봉인}) 의 극대원소 (§6.2.4 · AC6) ──────────────────────
# 「치환」이 아니라 «먼저 넣고 계산»이다. 스택에서 현재 브랜치가 다른 구성원의
# 조상이면 치환할 자리가 없어 미커밋 변경이 조용히 사라진다〔실측 10〕.
CANDS=$(printf '%s\n' $BR_TIPS $SEAL | grep -v '^$' | sort -u)
MAXIMAL=""
for a in $CANDS; do
  is_anc=no
  for b in $CANDS; do
    [ "$a" = "$b" ] && continue
    git merge-base --is-ancestor "$a" "$b" 2>/dev/null && { is_anc=yes; break; }
  done
  [ "$is_anc" = no ] && MAXIMAL="$MAXIMAL $a"
done
[ -n "$MAXIMAL" ] || emit base-unresolved "no maximal endpoint"

# 순서 결정론 — **두 단계다.** `rev-list --topo-order --no-walk` 의 출력은 인자
# 순서에 의존하므로〔실측 8〕, 먼저 집합을 사전순으로 정규화한 뒤 topo-order 를
# 건다. 한 단계로 줄이면 발견 순서가 결과에 새어 들어가 결정론이 조용히 사라진다.
MAXIMAL=$(printf '%s\n' $MAXIMAL | sort -u | tr '\n' ' ')
TIPS=$(git rev-list --topo-order --no-walk $MAXIMAL 2>/dev/null | paste -sd, -)
[ -n "$TIPS" ] || TIPS="-"

# ── T = 끝점들에서 경계를 뺀 합집합 ────────────────────────────────────────
TSET=$(git rev-list --topo-order $MAXIMAL "^$BOUNDARY" 2>/dev/null)
# 봉인(`--seal`)은 tips 의 끝점 자격은 갖지만(§6.2.4) T 의 원소는 아니다 — ref 없는
# 합성 커밋이라 GC 에 사라지고, 어떤 파생 해석에서도 「토픽의 커밋」이 아니다. tips 를
# 통해 HEAD 축에는 그대로 도달한다(트리 내용) — T 에서 빼는 것은 SHA 하나를 목록에서
# 제거하는 것이지 작업물을 버리는 게 아니다.
[ -z "$SEAL" ] || TSET=$(printf '%s\n' "$TSET" | grep -v -x -F "$SEAL")
NCOMMITS=$(printf '%s\n' "$TSET" | grep -c .)

# ── AC16 나머지 절반: T 가 서로 다른 토픽 키를 함께 담는가 ──────────────────
# 조상 전체가 아니라 **T 위에서** 센다 — 조상을 훑으면 main 에 이미 머지된 앞
# 토픽의 키까지 세어 거짓 양성이 난다.
#
# 트레일러 atom(`%(trailers:key=Spec,valueonly)`) 대신 C(:76)와 같은 --grep 계열
# 원시-메시지 추출을 쓴다(설계 §6.2.2 는 C 커맨드를 리터럴로 고정 — 반대쪽을 맞춘다).
# 이 둘은 실제로 갈린다: atom 은 키를 대소문자 무시로 매치해 `spec:` 소문자 트레일러까지
# 세어 거짓 declaration-invalid 를 내고, 거꾸로 GitHub squash-merge 가 흔히 만드는
# 본문(body)의 `Spec: ` 줄(트레일러 블록 밖)은 트레일러가 아니라서 못 세어 C 가 이미 잡은
# 커밋을 놓친다. `--grep` 과 같은 원시-텍스트 매치는 둘 다 피한다.
nkeys=$(git log --format='%B' $MAXIMAL "^$BOUNDARY" 2>/dev/null \
        | grep -E '^Spec: ' | sed -E 's/^Spec: //' | sort -u | grep -c .)
if [ "$nkeys" -gt 1 ]; then
  emit declaration-invalid "topic commit set carries $nkeys distinct Spec keys"
fi

# ── commits 서브커맨드 ─────────────────────────────────────────────────────
if [ "$SUB" = "commits" ]; then
  printf '%s\n' "$TSET"
  exit 0
fi
emit ok "-"
