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

# 러너 탐지 (tests/·scripts/tests/·hooks/tests/) — 판정은 TARGET(원본, 읽기전용)에서;
# 실행은 반드시 샌드박스 사본에서만(격리 보장 — 원본 TARGET의 코드는 절대 직접 실행하지 않음).
tgt_in_sb="$SANDBOX/${TARGET#*/}"; [ -d "$tgt_in_sb" ] || tgt_in_sb="$SANDBOX"
ran=false; passed=null; total=null; why=
for cand in tests scripts/tests hooks/tests; do
  if [ -d "$TARGET/$cand" ]; then
    ran=true
    if [ -d "$tgt_in_sb/$cand" ]; then
      ( cd "$SANDBOX" && $TO python3 -m unittest discover -s "${tgt_in_sb#$SANDBOX/}/$cand" -t . ) >/dev/null 2>&1
    fi
    break
  fi
done
[ -z "$TO" ] && why='timeout 유틸 부재 — 무타임아웃 실행(gtimeout 권장)'

# mutation-guard — product 변경 감지
guard=$(bash "$QG" mutation-guard "$SANDBOX" "$BASE" "$DIGEST" 2>/dev/null)
forced=$(echo "$guard" | sed -n 's/^forced_downgrade: *//p' | tail -1)
fd=false; [ "$forced" = "yes" ] && fd=true

bash "$QG" remove "$SANDBOX" >/dev/null 2>&1 || true
emit "$(fact "$ran" "$passed" "$total" "$fd" "$why")"
exit 0
