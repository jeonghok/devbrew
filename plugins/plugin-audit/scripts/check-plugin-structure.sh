#!/usr/bin/env bash
# E — plugin-dev 검증기 wrapper. 출력은 evidence pack의 *사실*. C14: 검증기를 먼저 검증.
set -u
set +B  # bash 3.2 (macOS): disable brace expansion — nested "$(python3 -c "...{'k':v,...}...")"
        # double-quote-in-double-quote triggers spurious {a,b,c} brace-splitting of the python
        # one-liner into N broken invocations, silently emptying stdout. Verified footgun, not cosmetic.
TARGET="${1:?usage: check-plugin-structure.sh <plugin_dir> [--plugin-dev-root <dir>]}"; shift || true
PDEV_ROOT=""
while [ $# -gt 0 ]; do case "$1" in --plugin-dev-root) PDEV_ROOT="$2"; shift 2;; *) shift;; esac; done

facts='[]'; degraded='[]'
add_fact() { facts=$(python3 -c "import json,sys; a=json.loads(sys.argv[1]); a.append(json.loads(sys.argv[2])); print(json.dumps(a))" "$facts" "$1"); }
add_degr() { degraded=$(python3 -c "import json,sys; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$degraded" "$1"); }

# 검증기 경로 해석: --plugin-dev-root 우선, 없으면 캐시 glob (unversioned → 파일 존재로 탐지)
resolve() {  # $1 = script basename
  if [ -n "$PDEV_ROOT" ]; then
    find "$PDEV_ROOT" -name "$1" -type f 2>/dev/null | head -1
  else
    ls ~/.claude/plugins/cache/*/plugin-dev/*/skills/*/scripts/"$1" 2>/dev/null | sort | tail -1
  fi
}

VA=$(resolve validate-agent.sh); VH=$(resolve validate-hook-schema.sh); HL=$(resolve hook-linter.sh)
if [ -z "$VA$VH$HL" ]; then
  add_degr "⚠ plugin-dev 미설치 — 심층 구조 검사 생략 (core는 F가 커버)"
  python3 -c "import json,sys; print(json.dumps({'structure_facts': json.loads(sys.argv[1]), 'degraded': json.loads(sys.argv[2])}, ensure_ascii=False))" "$facts" "$degraded"
  exit 0
fi

# hook-linter.sh (정상 동작 — 사실로) — .sh 훅이 실제로 있을 때만 호출.
# 없으면 (예: python-only hooks) unguarded glob이 literal "*.sh" 문자열로 linter에 전달되어
# 거짓 fact를 남길 수 있음 (non-nullglob bash). compgen -G로 존재 확인 후에만 호출.
if [ -n "$HL" ] && compgen -G "$TARGET/hooks/*.sh" >/dev/null 2>&1; then
  out=$(bash "$HL" "$TARGET"/hooks/*.sh 2>&1); rc=$?
  if [ $rc -le 1 ]; then
    add_fact "$(python3 -c "import json,sys; print(json.dumps({'validator':'hook-linter.sh','target':sys.argv[1],'fact':sys.argv[2][:400],'verifier_ok':True}))" "$TARGET" "$out")"
  else
    add_degr "hook-linter.sh 스퓨리어스 exit $rc — 사실 생략 (C14)"
  fi
fi

# validate-hook-schema.sh — devbrew wrapper에 exit 5 (Cannot index object) 알려진 비호환 → degrade, finding 아님
if [ -n "$VH" ] && [ -f "$TARGET/hooks/hooks.json" ]; then
  out=$(bash "$VH" "$TARGET/hooks/hooks.json" 2>&1); rc=$?
  if [ $rc -eq 5 ] || echo "$out" | grep -q "Cannot index object with number"; then
    add_degr "validate-hook-schema.sh: devbrew {description,hooks} wrapper 비호환(exit 5) — 검증기 결함, 감사 발견 아님"
  elif [ $rc -le 1 ]; then
    add_fact "$(python3 -c "import json,sys; print(json.dumps({'validator':'validate-hook-schema.sh','target':sys.argv[1],'fact':sys.argv[2][:400],'verifier_ok':True}))" "$TARGET/hooks/hooks.json" "$out")"
  else
    add_degr "validate-hook-schema.sh 스퓨리어스 exit $rc — 사실 생략 (C14)"
  fi
fi

# validate-agent.sh — color/model required false-fail 필터 (거짓 증거 주입 금지)
if [ -n "$VA" ]; then
  for a in "$TARGET"/agents/*.md; do
    [ -f "$a" ] || continue
    out=$(bash "$VA" "$a" 2>&1); rc=$?
    # color/model 누락만이 원인인 실패는 plugin-dev-ism → 필터
    real=$(echo "$out" | grep -E '❌|error' | grep -viE 'color|model' || true)
    if [ $rc -ne 0 ] && [ -z "$real" ]; then
      add_degr "validate-agent.sh($(basename "$a")): color/model required는 plugin-dev-ism — 필터(devbrew 불변식 아님)"
    elif [ -n "$real" ]; then
      add_fact "$(python3 -c "import json,sys; print(json.dumps({'validator':'validate-agent.sh','target':sys.argv[1],'fact':sys.argv[2][:400],'verifier_ok':True}))" "$a" "$real")"
    fi
  done
fi

# quick_validate.py (skill 검증기) — 이 plugin-dev 빌드에 부재 → 상시 degrade
if [ -z "$(resolve quick_validate.py)" ]; then
  add_degr "quick_validate.py 부재 — skill frontmatter 심층 검증 생략 (F가 cost_class 커버)"
fi

python3 -c "import json,sys; print(json.dumps({'structure_facts': json.loads(sys.argv[1]), 'degraded': json.loads(sys.argv[2])}, ensure_ascii=False))" "$facts" "$degraded"
exit 0
