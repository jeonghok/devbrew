#!/usr/bin/env bash
# 자체 테스트 격리 어댑터 — qg-worktree.sh 샌드박스 재사용 + 120s 타임아웃(호출자 감쌈).
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
ran=false; passed=null; total=null; why='no test runner found in target'
for cand in tests scripts/tests hooks/tests; do
  if [ -d "$tgt_in_sb/$cand" ]; then
    ( cd "$SANDBOX" && $TO python3 -m unittest discover -s "$tgt_in_sb/$cand" -t . ) >/dev/null 2>&1
    ran=true; why=
    break
  fi
done
[ "$ran" = true ] && [ -z "$TO" ] && why='timeout 유틸 부재 — 무타임아웃 실행(gtimeout 권장)'

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
emit "$(fact "$ran" "$passed" "$total" "$fd" "$why")"
exit 0
