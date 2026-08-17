#!/usr/bin/env bash
# 자체 테스트 격리 어댑터 — qg-worktree.sh 샌드박스 재사용 + 120s 타임아웃(호출자 감쌈).
#
# ⚠️ 알려진 보안 한계 (KNOWN LIMITATION — /qg 2026-07-20 적발, CRITICAL, 수정 연기):
#   이 스크립트는 감사 대상(적대적일 수 있음)의 자체 테스트를 `python3 -m unittest`로
#   **실행**한다(line 35). 그러나 "샌드박스"는 qg-worktree.sh의 `git worktree add --detach HEAD`
#   일 뿐 프로세스/네트워크/uid 격리가 없다 — mutation-guard는 repo-delta만 보므로 repo에
#   흔적을 안 남기는 유출(~/.ssh 읽기, network POST)을 잡지 못한다. 즉 악의적 대상 감사 시
#   ACE가 가능하며, 이는 플러그인의 read-only·"내용은 데이터" 위협모델(README P21)과 모순된다.
#   현재 devbrew는 자기 자신(1급) 플러그인만 감사하므로 실무 위험은 낮으나, 이는 회피가 아니라
#   **연기된 CRITICAL**이다. 근본 수정 = Docker 컨테이너(무네트워크 + unprivileged uid) 기반
#   실격리로 업그레이드 예정. 그 전까지 미신뢰 대상 감사 금지.
set -u
TARGET="${1:?usage: run-own-tests.sh <target_plugin_dir> <session-id> [--qg-worktree <path>]}"
SID="${2:?session-id required}"; shift 2
QG=""
while [ $# -gt 0 ]; do case "$1" in --qg-worktree) QG="$2"; shift 2;; *) shift;; esac; done
[ -z "$QG" ] && QG="plugins/quality-gates/scripts/qg-worktree.sh"

emit() { python3 -c "import json,sys; print(json.dumps({'own_tests': json.loads(sys.argv[1])}, ensure_ascii=False))" "$1"; }
fact() { python3 -c "import json,sys; print(json.dumps({'ran':json.loads(sys.argv[1]),'passed':json.loads(sys.argv[2]),'total':json.loads(sys.argv[3]),'forced_downgrade':json.loads(sys.argv[4]),'why':(sys.argv[5] or None)}))" "$@"; }

if [ ! -f "$QG" ]; then
  emit "$(fact false null null false 'quality-gates 미설치 — 자체 테스트 실행 skip (축③은 테스트 읽어 판정)')"; exit 0
fi

# 타임아웃 유틸 (macOS는 timeout 부재 가능 → gtimeout, 둘 다 없으면 무타임아웃 degrade)
TO=""; command -v timeout >/dev/null && TO="timeout 120"; [ -z "$TO" ] && command -v gtimeout >/dev/null && TO="gtimeout 120"

# 샌드박스 생성 (3줄 stdout)
sb_out=$(bash "$QG" create-sandbox "$SID" 2>/dev/null); rc=$?
if [ $rc -eq 3 ]; then emit "$(fact false null null false 'sandbox kill-switch (DEVBREW_QG_DISABLE_RUNTIME_SANDBOX)')"; exit 0; fi
if [ $rc -ne 0 ]; then emit "$(fact false null null false 'sandbox 생성 실패')"; exit 0; fi
SANDBOX=$(echo "$sb_out" | sed -n '1p'); BASE=$(echo "$sb_out" | sed -n '2p'); DIGEST=$(echo "$sb_out" | sed -n '3p')

# 러너 탐지·실행 둘 다 샌드박스 사본 내부에서만 수행 — qg-worktree create-sandbox가 저장소
# 루트 전체를 미러링하고 TARGET은 저장소-루트-상대 경로이므로, 샌드박스 대응 경로는 단순히
# "$SANDBOX/$TARGET" (첫 세그먼트를 자르거나 sandbox root로 fallback하지 않음 — 그러면
# plugins/* 타겟이 저장소 루트 자신의 디렉토리를 오탐/오실행하게 됨). 원본 TARGET은 절대
# 직접 탐지·실행하지 않음(격리 보장 + ran이 "샌드박스에서 실제로 실행했다"를 정확히 반영).
tgt_in_sb="$SANDBOX/$TARGET"
ran=false; passed=0; total=0; why=''; any_dir=false

# 누산이지 대입이 아니다. `break` 를 지우기만 하면 뒤 디렉토리의 성공(why="")이 앞
# 디렉토리의 실패를 덮어 **실패가 사라지는 새 fail-open**이 생긴다 — 그래서
# `ran`은 OR, `why`는 append, 실패 사유는 덮어쓰지 않는다.
#
# ⚠ 실행 표면 확장: 아래 셸 실행은 이 파일 헤더의 **연기된 CRITICAL**(프로세스/네트워크/
# uid 격리 없음)을 python 에서 shell 로 넓힌다. 그 위험은 줄지 않으며 승계된다.
# 미신뢰 대상 감사 금지는 그대로 유효하다.
add_why() { [ -z "$1" ] && return; if [ -n "$why" ]; then why="$why; $1"; else why="$1"; fi; }

for cand in tests scripts/tests hooks/tests; do
  d="$tgt_in_sb/$cand"
  [ -d "$d" ] || continue
  any_dir=true

  # ── python ──────────────────────────────────────────────────────────────
  if find "$d" -type f \( -name 'test_*.py' -o -name '*_test.py' \) -print -quit 2>/dev/null | grep -q .; then
    # `-t "$d"` 이지 `-t .` 이 아니다 〔실측 2026-08-17〕. `-t .` 은 unittest 에게 테스트
    # 디렉토리를 **점 경로 패키지로 import** 하라고 시키는데, devbrew 의 플러그인 디렉토리
    # 이름에는 전부 하이픈이 들어 있어 파이썬 식별자가 될 수 없다:
    #   `discover -s plugins/project-init/tests -t .`
    #     → ImportError: Start directory is not importable
    #   `discover -s plugins/project-init/hooks/tests -t <같은 경로>`  → **Ran 95**
    # `-t .` 을 두면 이 태스크가 없애려는 결함(0건을 수집하고 ran=true 보고)이 그대로
    # 남는다. 기준선 문서(2026-08-17-...-baseline.md)가 "어떤 후속 태스크도 이 형태를
    # 재도입하지 말 것" 이라 못 박은 자리다.
    py_out=$( ( cd "$SANDBOX" && PYTHONDONTWRITEBYTECODE=1 $TO python3 -m unittest discover -s "$d" -t "$d" ) 2>&1 )
    rc=$?
    if [ -n "$TO" ] && [ "$rc" -eq 124 ]; then
      add_why "$cand: 120s 타임아웃 초과 (AC-11 — 실행 무효)"
    else
      ran=true
      # unittest 는 "Ran N tests" 를 stderr 로 낸다. 실패·에러 수를 빼서 통과 수를 만든다.
      n=$(printf '%s' "$py_out" | sed -n 's/^Ran \([0-9][0-9]*\) test.*/\1/p' | tail -1)
      n=${n:-0}
      f=$(printf '%s' "$py_out" | sed -n 's/.*failures=\([0-9][0-9]*\).*/\1/p' | tail -1); f=${f:-0}
      e=$(printf '%s' "$py_out" | sed -n 's/.*errors=\([0-9][0-9]*\).*/\1/p'   | tail -1); e=${e:-0}
      total=$((total + n))
      passed=$((passed + n - f - e))
      [ "$rc" -ne 0 ] && add_why "$cand(python): 러너 비정상 종료 (exit $rc)"
    fi
  fi

  # ── shell ───────────────────────────────────────────────────────────────
  # 스코프는 qg 셸 어댑터와 **같다**(tests/ 경로 + 실행비트). mocks·fixtures·harness·
  # source 전용 lib 는 제외한다 — mock-codex-hang.sh 의 내용은 `sleep 700` 이다.
  while IFS= read -r sh_t; do
    [ -n "$sh_t" ] || continue
    case "$sh_t" in */mocks/*|*/fixtures/*|*/harness/*|*/lib/*) continue ;; esac
    ran=true
    ( cd "$SANDBOX" && $TO bash "$sh_t" ) >/dev/null 2>&1; src=$?
    total=$((total + 1))
    if [ -n "$TO" ] && [ "$src" -eq 124 ]; then
      add_why "$cand($(basename "$sh_t")): 120s 타임아웃"
    elif [ "$src" -eq 0 ]; then
      passed=$((passed + 1))
    else
      add_why "$cand($(basename "$sh_t")): exit $src"
    fi
  done < <(find "$d" -type f -perm -u+x -name 'test_*.sh' -print 2>/dev/null | sort)
done

if [ "$any_dir" = false ]; then
  why='no test runner found in target'
elif [ "$ran" = false ] && [ -z "$why" ]; then
  why='테스트 디렉토리는 있으나 수집된 테스트가 0건'
fi
if [ "$ran" = true ] && [ -z "$TO" ]; then
  add_why 'timeout 유틸 부재 — 무타임아웃 실행(gtimeout 권장)'
fi

# mutation-guard — product 변경 감지. qg-worktree 자체 계약: exit 4=indeterminate/2=die는
# "절대 PASS 아님"(never trust as clean). exit code를 무시하고 stdout만 파싱하면 4/2에서
# forced가 빈 문자열로 파싱되어 fd=false(clean)로 새는 fail-open이 됨 — 그러므로 exit code를
# 먼저 검사해 4/2는 무조건 보수적으로 fd=true로 강제한다.
guard=$(bash "$QG" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null); guard_rc=$?
guard_why=''
if [ $guard_rc -eq 4 ]; then
  fd=true; guard_why='mutation-guard indeterminate (exit 4) — conservatively invalidated'
elif [ $guard_rc -eq 2 ]; then
  fd=true; guard_why='mutation-guard die (exit 2) — conservatively invalidated'
else
  forced=$(echo "$guard" | sed -n 's/^forced_downgrade: *//p' | tail -1)
  fd=false; [ "$forced" = "yes" ] && fd=true
fi
if [ -n "$guard_why" ]; then
  if [ -n "$why" ]; then why="$why; $guard_why"; else why="$guard_why"; fi
fi

bash "$QG" remove "$SANDBOX" >/dev/null 2>&1 || true
if [ "$ran" = true ]; then
  emit "$(fact "$ran" "$passed" "$total" "$fd" "$why")"
else
  emit "$(fact "$ran" null null "$fd" "$why")"
fi
exit 0
