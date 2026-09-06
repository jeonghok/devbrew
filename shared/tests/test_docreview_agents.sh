#!/usr/bin/env bash
# guards: shared/docreview/agents/*.md
#
# 두 리뷰어 agent 의 frontmatter 계약 — 도구 표면(AC16) · recritic 슬롯 셋(AC9) · model 키 부재(main 규약).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then git ls-files -- 'shared/docreview/agents/*.md'; exit 0; fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
A="$REPO_ROOT/shared/docreview/agents"
# eval() 은 이 파일 안에서 저자가 직접 적은 리터럴 파이썬 표현식만 받는다(외부·사용자
# 입력 없음) — 형제 test_docreview_profiles.sh:32 와 같은 관용구.
fm() { python3 -c 'import sys,yaml; t=open(sys.argv[1],encoding="utf-8").read(); print(eval(sys.argv[2]))' "$1" "$2"; }
for a in doc-critic doc-recritic; do
  f="$A/$a.md"
  assert_eq "$(fm "$f" 'yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["tools"]')" "Read, Grep, Glob" "$a: tools = Read, Grep, Glob (Write/Edit/Bash 없음, AC16)"
  assert_not_grep "$(sed -n '/^---$/,/^---$/p' "$f")" '^model:' "$a: frontmatter 에 model 키 없음(main 규약)"
  assert_grep "$(sed -n '/^---$/,/^---$/p' "$f")" '^name: '"$a"'$' "$a: name 일치"
done
# recritic 슬롯 정확히 셋 (AC9)
SL="$(fm "$A/doc-recritic.md" '[s["tag"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]]')"
assert_eq "$SL" "['document', 'findings', 'profile']" "doc-recritic: 입력 슬롯 정확히 셋 — dispatch 사유·이력·출처 라벨 슬롯 없음 (AC9)"
KINDS="$(fm "$A/doc-recritic.md" 'sorted(set(s["kind"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]))')"
assert_eq "$KINDS" "['artifact', 'repo_context']" "doc-recritic: kind 는 artifact·repo_context 만 (prior_verdict·orchestrator_framing 없음)"
# critic 은 문서·프로필·(선택)이력 셋
CS="$(fm "$A/doc-critic.md" '[s["tag"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]]')"
assert_eq "$CS" "['document', 'profile', 'prior_finding_ids']" "doc-critic: 문서·프로필·이력(선택) 슬롯"
finish
