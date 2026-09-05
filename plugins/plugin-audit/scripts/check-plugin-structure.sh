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

# validate-agent.sh — color/model required 필터 (거짓 증거 주입 금지)
#   · `model` 누락 «단독»은 devbrew 규약 준수다 (docs/plugin-authoring.md: frontmatter 에
#     model 키를 두지 않는다) — 기록하지 않는다. degrade 로 적으면 리포트가 거짓을 말한다.
#   · `color` 누락 단독은 plugin-dev-ism — 기존대로 degrade 로 남긴다 (사실 아님, 생략 공시).
#   · plugin-dev validate-agent.sh 는 model 키가 아예 없는 agent 에서 ⚠️ 경고는 내지만
#     "Missing required field: model" 즉 ❌ 줄에는 도달하지 못하고 rc=1 로 죽는다 — devbrew
#     전 agent 가 model-less 규약이라 이게 상시·전수 발생한다. per-agent degrade 로 적으면
#     agent 수만큼의 노이즈이므로 플러그인당 집계 1줄로 묶는다 (loud 이되 noisy 는 아니게).
has_model_key() {  # $1 = agent file — frontmatter window(첫 두 --- 사이)에 model 키가 있는지
  awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1" | grep -qE "^[\"']?model[\"']?[[:space:]]*:"
}
if [ -n "$VA" ]; then
  modelless_crash=0
  for a in "$TARGET"/agents/*.md; do
    [ -f "$a" ] || continue
    out=$(bash "$VA" "$a" 2>&1); rc=$?
    errs=$(echo "$out" | grep -E '❌|error' || true)
    real=$(echo "$errs" | grep -viE 'color|model' || true)
    color_only=$(echo "$errs" | grep -iE 'color' || true)
    if [ $rc -ne 0 ] && [ -z "$real" ]; then
      if [ -n "$color_only" ]; then
        add_degr "validate-agent.sh($(basename "$a")): color required는 plugin-dev-ism — 필터(devbrew 불변식 아님)"
      elif [ -z "$errs" ]; then
        if has_model_key "$a"; then
          add_degr "validate-agent.sh($(basename "$a")) 스퓨리어스 exit $rc — 사실 생략 (C14)"
        else
          modelless_crash=$((modelless_crash+1))
        fi
      fi
      # model 누락 단독: 규약 준수 — 아무것도 남기지 않는다
    elif [ -n "$real" ]; then
      add_fact "$(python3 -c "import json,sys; print(json.dumps({'validator':'validate-agent.sh','target':sys.argv[1],'fact':sys.argv[2][:400],'verifier_ok':True}))" "$a" "$real")"
    fi
  done
  if [ "$modelless_crash" -gt 0 ]; then
    add_degr "validate-agent.sh: model 키 없는 agent ${modelless_crash}개에서 ❌ 없이 exit — plugin-dev 검증기가 model 부재를 처리 못 함, 검증 생략(devbrew 규약 준수)"
  fi
fi

# quick_validate.py (skill 검증기) — 이 plugin-dev 빌드에 부재 → 상시 degrade
if [ -z "$(resolve quick_validate.py)" ]; then
  add_degr "quick_validate.py 부재 — skill frontmatter 심층 검증 생략 (F가 cost_class 커버)"
fi

python3 -c "import json,sys; print(json.dumps({'structure_facts': json.loads(sys.argv[1]), 'degraded': json.loads(sys.argv[2])}, ensure_ascii=False))" "$facts" "$degraded"
exit 0
