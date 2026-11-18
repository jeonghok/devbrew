#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md
#
# 끝맺음의 첫 칸 규약과 비밀값 멈춤(원자료 정본 사슬 AC8 · AC23).
#   finishing.md Step A 절(줄 이음한 글) — seed 로 시작한 인터뷰의 S1 은 seed 가 아니라 원자료이고,
#   `raw_source.py place` 가 싣는다. 그대로 싣지 못함 · 찾지 못함 갈래의 앵커 라벨은 raw_source 모듈의
#   상수와 글자가 같다. 싣기 전에 비밀값으로 보이는 값에서 멈추고 묻는다 — 기록부터 가리고 첫 칸에서만
#   가리는 길은 없다. 가린 기록 파일은 커밋 펜스가 결과물과 같은 커밋에 넣는다.
#   brief 템플릿 §6 안내가 같은 규약을 가리킨다.
#   변이 — 각 단언을 하나씩 깨 그 이름이 실패로 나오는지 본다(변이 자리가 없으면 그것도 실패다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/pm-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"; exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
FIN="$SD/skills/pm-interview/references/finishing.md"
TPL="$SD/templates/interview-brief-template.md"
W="$(mktemp -d)"; [ -n "$W" ] && [ -d "$W" ] || { echo "mktemp 실패"; exit 1; }
trap 'rm -rf "$W"' EXIT

# finishing_fails <finishing.md> <brief 템플릿> → 실패한 단언 이름을 한 줄씩(통과면 빈 출력)
finishing_fails() {
  python3 -I -B - "$1" "$2" "$SD/scripts" <<'FIRST_CELL_PY'
import re
import sys

fin_path, tpl_path, scripts = sys.argv[1:4]
sys.path.insert(0, scripts)
import raw_source as rs  # noqa: E402


def joined(text):
    return re.sub(r"\n[ \t]*", " ", text)


fin = open(fin_path, encoding="utf-8").read()
tpl = open(tpl_path, encoding="utf-8").read()
a0 = fin.find("### Step A — brief 작성")
a1 = fin.find("### Step A.5", a0 + 1)
A = joined(fin[a0:a1]) if 0 <= a0 < a1 else ""
c0 = fin.find("<!-- interview-commit:begin -->")
c1 = fin.find("<!-- interview-commit:end -->", c0 + 1)
fence_lines = fin[c0:c1].split("\n") if 0 <= c0 < c1 else []
t0 = tpl.find("\n## 6.")
t1 = tpl.find("\n## ", t0 + 1)
T6 = joined(tpl[t0:t1]) if 0 <= t0 < t1 else ""


def has(*needles):
    return bool(A) and all(n in A for n in needles)


def in_order(text, start, *needles):
    pos = start
    for n in needles:
        pos = text.find(n, pos)
        if pos < 0:
            return False
        pos += len(n)
    return True


def line_has(marker, token):
    rows = [ln for ln in fence_lines if marker in ln]
    return bool(rows) and all(token in ln for ln in rows)


checks = []
checks.append(("s1_not_seed", has("**seed 로 시작한 인터뷰의 `S1` 은 seed 가 아니라 원자료다.**",
                                  "본문을 손으로 옮겨 치지 않는다")))
checks.append(("labels", has(rs.anchor_line(rs.LABEL_UNLOADABLE), rs.anchor_line(rs.LABEL_LOST),
                             "「" + rs.LABEL_RAW + "」")))
checks.append(("place_cmd", has('raw_source.py" place --interview', 'raw_source.py" locate --interview',
                                "--absolute")))
checks.append(("unloadable_notice", has("원자료를 그대로 싣지 못했다 — 결과물 문법이 받지 않는 줄 <n>개",
                                        "원문의 글자를 고쳐 싣지 않는다", "한 절만 싣지도 않는다")))
checks.append(("secret_stop", has("**싣지 않고 멈춘다**", "값 자체는 보이지 않고",
                                  "그대로 싣지 못하는 갈래로 갈 글이어도 이 확인이 먼저다")))
anchor = A.find("**비밀값 확인 — 싣기 전에, 갈래를 가르기 전에.**")
opts = ("「기록부터 가린다 (권장)」(얻음:", "「비밀값이 아니다 — 그대로 싣는다」(얻음:", "「멈춘다」(얻음:")
checks.append(("secret_options", anchor >= 0 and in_order(A, anchor, *opts)
               and "「비밀값이 아니다 — 그대로 싣는다 (권장)」" not in A and "「멈춘다 (권장)」" not in A))
checks.append(("secret_order", in_order(A, 0, "framing 기록 파일의 그 값을 먼저",
                                        "같은 값이 seed 파일이나 상태 파일의 `## 풀린 입력` 블록에 있으면 같은 표시로 함께 가린 뒤",
                                        "그 뒤에 `place` 를 돌린다")))
checks.append(("secret_same_commit", has("결과물과 같은 커밋에 넣는다")
               and line_has('git -C "$top" add', "RAW_A") and line_has("commit -q --only", "RAW_A")))
checks.append(("secret_history", has("이 값은 git 이력의 옛 커밋에 남아 있다 — 값을 폐기하고 바꾸는 것이 먼저다")))
checks.append(("no_first_cell_only", has("첫 칸에서만 가리는 길은 없다") and "첫 칸에서만 가린다" not in A))
checks.append(("old_rule_gone", has("**최초 요청 원문은 `S1`이다.**")
               and "그때도 같은 규칙이 그대로 적용됩니다" not in joined(fin)))
checks.append(("template", bool(T6) and "손으로 옮겨 치지 않는다" in T6 and "앵커 라벨로 밝힌다" in T6))
for name, passed in checks:
    if not passed:
        print(name)
FIRST_CELL_PY
}

got="$(finishing_fails "$FIN" "$TPL")"
for n in s1_not_seed labels place_cmd unloadable_notice secret_stop secret_options secret_order \
         secret_same_commit secret_history no_first_cell_only old_rule_gone template; do
  if grep -qx -- "$n" <<<"$got"; then no "끝맺음 첫 칸 — ${n}"; else ok "끝맺음 첫 칸 — ${n}"; fi
done
[ -z "$got" ] || printf '      실패 이름: %s\n' "$(tr '\n' ' ' <<<"$got")"

# 변이 — 사본 하나의 첫 자리를 바꿔(new 가 비면 지운다) 단언 하나가 이름으로 실패하는지 본다.
# breaks <깰 이름> <fin|tpl> <old> <new>
breaks() {
  local want="$1" which="$2" mf="$W/fin.md" mt="$W/tpl.md" out
  cp "$FIN" "$mf"; cp "$TPL" "$mt"
  local target="$mf"; [ "$which" = tpl ] && target="$mt"
  if ! python3 -I -B -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8").read()
if old not in s:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))' "$target" "$3" "$4"; then
    no "변이 자리 없음 — ${want}: 「${3}」"; return
  fi
  out="$(finishing_fails "$mf" "$mt")"
  if grep -qx -- "$want" <<<"$out"; then ok "변이가 ${want} 를 깬다"; else no "변이가 ${want} 를 깨지 못했다 (실패: $(tr '\n' ' ' <<<"$out"))"; fi
}
breaks secret_stop fin '**싣지 않고 멈춘다**' '**싣고 알린다**'
breaks secret_options fin ' · 「멈춘다」(얻음: 아무것도 싣지 않고 끝맺음을 멈춘다 · 내줌: 결과물이 완성되지 않아 값을 처리한 뒤 다시 끝맺어야 한다)' ''
breaks secret_options fin '「비밀값이 아니다 — 그대로 싣는다」(얻음:' '「비밀값이 아니다 — 그대로 싣는다 (권장)」(얻음:'
breaks secret_order fin '그 값을 먼저' '그 값을'
breaks secret_same_commit fin '상태 기록" -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"} ${RAW_A:+"$RAW_A"}' '상태 기록" -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"}'
breaks secret_same_commit fin 'add -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"} ${RAW_A:+"$RAW_A"}' 'add -- "$BRIEF" "$AUDIT_F" "$STATE_F" ${RDIR:+"$RDIR"}'
breaks labels fin '원자료를 찾지 못함 — 모델이 줄인 글' '원자료를 찾지 못함 — 사용자 원문'
breaks old_rule_gone fin '그대로다(첫 입력이 곧 원자료다):' '그대로다. 그때도 같은 규칙이 그대로 적용됩니다:'
breaks no_first_cell_only fin '첫 칸에서만 가리는 길은 없다' '첫 칸에서만 가린다'
breaks template tpl '앵커 라벨로 밝힌다' '라벨로 적는다'
finish
