#!/usr/bin/env bash
# guards: plugins/** shared/**
#
# 새 중복의 **유입**을 막는다.
#
#   20줄 이상 완전히 같은 블록이 2개 이상 파일에 있는데, 그 파일들이 copy-of 로
#   설명되지 않으면 RED.
#
# 면제 술어 둘: ① 한쪽이 다른 쪽을 copy-of 로 가리킨다 ② **양쪽이 같은 정본을**
# **copy-of 로 가리킨다.** ②가 이 리포의 실제 형태다 — 정본이 shared/ 의 제3 파일이라
# 사본끼리는 서로를 가리키지 않는다. ①만 있으면 통합 후에도 사본군이 영원히 RED 다.
#
# **면제 술어는 마커의 *존재*만 본다.** 실제 동일성은 test_copy_of_contract.sh 의
# GREEN 에 기댄다 — 즉 이 락의 이빨은 그 락이 살아 있을 때만 유효하다. 두 락을 같은
# `# guards:` 로 두고 같은 지점에서 함께 돌리는 이유가 그것이다.
#
# 심볼릭 링크는 마커 술어를 그대로 못 쓴다: 파이썬의 open()/read_text() 는 링크를
# 투명하게 따라가 대상 내용을 반환하므로, 정본과 그 링크들이 "넷 다 같은 내용을 담은
# 별개 경로" 로 잡혀 락이 자기가 만든 통합에 걸린다. 그런데 링크에는 `copy-of:` 텍스트가
# 없다. 그래서 스캐너는 is_symlink() 로 링크를 식별하고 그 대상 경로를 "마커가 가리키는
# 경로" 와 **동등하게** 취급해 같은 면제 술어에 넣는다.
#
# 재지 않는 것: 파일 줄 수 · 파일/폴더 개수 · 폴더 모양 · 함수 분할 수 ·
# **유사도 퍼센트**. 여기서 보는 것은 "얼마나 비슷한가" 가 아니라 "완전히 같은 구간이
# 얼마나 긴가" 다. 모듈화는 보안도 정확성도 아닌 판단의 영역이라 결정론 게이트를 걸지 않는다.
#
# docs/ 는 코퍼스에 없다 — 아카이브를 들여와도 반응하지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# Task 34 가 실측으로 확정한 값(창 20줄·최소 200자 — 무릎에서 오탐 0, 22 로 올리면 진짜
# 양성이 사라진다). **env override 를 두지 않는다** — 설계 §12.4 가 임계값을 정직하게
# 만드는 근거로 든 것이 "값을 바꾸면 diff 에 한 줄로 드러난다" 인데, env 로 완화 가능하면
# 그 근거가 무너진다(완화가 diff 에 안 남는다). 임계를 조사하려면 부록 A.4 의 knee.py 를
# 쓴다 — 그것이 조사용 도구이고 이것은 집행 지점이다.
WINDOW=20
MIN_CHARS=200

# `--cached --others --exclude-standard` 다 — `git ls-files` 단독을 쓰지 않는다.
# 추적된 파일만 보면 **아직 스테이지되지 않은 새 파일이 코퍼스 밖**이다. 새 중복은
# 커밋 전에 잡아야 의미가 있고, mutation 으로 이 락을 검증할 때도 방금 만든 파일이
# 조용히 대상 밖이 되면 그 mutation 은 아무것도 재지 않는다(이 사이클에서 실측으로
# 물린 함정이다). .gitignore 는 그대로 존중한다.
CORPUS="$(git ls-files --cached --others --exclude-standard -- 'plugins/*' 'shared/*' \
  | grep -vE '/(fixtures|mocks|harness)/')"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

# 2026-08-17 라운드 3이 잡은 결함 — **원인 서술은 라운드 4가 실측으로 정정했다.**
# `printf ... | python3 - <<'PY'` 는 파이프와 히어닥을 같은 stdin 에 건다. 결과는
# **셸마다 다르다**:
#   - bash (이 파일의 shebang 이자 문서화된 유일한 실행 경로 `bash <script>`):
#     히어닥이 **마지막 리다이렉션**이라 파이프를 덮어쓴다. 파이썬 본문은 정상
#     로드·실행되지만 그 stdin 은 본문을 읽느라 이미 소진돼 `sys.stdin` 이
#     **0바이트**를 준다 → `SCANNED 0` · `WINDOWS 0`, stderr **0바이트**, 종료코드 0.
#     **조용한 실패다 — traceback 이 없다.**
#   - zsh (기본값 MULTIOS): 두 입력을 덮어쓰지 않고 **이어붙인다** — 파이프 내용
#     뒤에 히어닥이 붙어 파이썬이 $CORPUS(파일 경로 목록)까지 코드로 컴파일하다
#     죽는다(코퍼스 내용에 따라 `NameError` 또는 `SyntaxError`).
# 위험 등급은 요란한 크래시가 아니라 **조용한 빈 결과**라, 이 패턴을 다른 데서 만난
# 사람이 traceback 을 기다리면 알아보지 못한다. 여기서 유일한 탐지 수단은 아래 vacuous
# 가드다(당시엔 `scanned >= 50` 하나였고, 지금은 ∀-지배관계 + 붕괴 바닥 둘이다).
# 고침: 코퍼스를 파이프가 아니라 **임시 파일**로 넘겨 stdin 을 히어닥(파이썬 스크립트
# 본문) 전용으로 남긴다 — bash·zsh 양쪽에서 동일하게 동작한다.
CORPUS_FILE="$(mktemp -t nnd-corpus-XXXXXX)" || exit 1
trap 'rm -f "$CORPUS_FILE"' EXIT
printf '%s\n' "$CORPUS" > "$CORPUS_FILE"
OUT="$(python3 - "$WINDOW" "$MIN_CHARS" "$CORPUS_FILE" <<'PY'
import hashlib, os, pathlib, re, sys, collections

WINDOW   = int(sys.argv[1])
MIN_CHARS = int(sys.argv[2])
MARKER = re.compile(r'^\s*(#|//|<!--)\s*copy-of:\s*(\S+)')
HEAD_WINDOW = 20
ROOT = pathlib.Path.cwd()   # 셸이 이미 ROOT 로 cd 했다

with open(sys.argv[3], encoding="utf-8") as fh:
    files = [l.strip() for l in fh if l.strip()]

def symlink_target_of(p):
    """**이미 심볼릭 링크로 확인된** p 의 대상을 리포 루트 기준 상대 경로로.
    해석 실패면 None — 대상 부재는 OSError, 대상이 **리포 밖**이면 relative_to()
    가 ValueError 다.

    "링크가 아님" 은 이 함수의 반환값에 **없다.** 호출부가 is_symlink() 로 먼저
    갈라서 부른다 — 두 상태를 같은 None 에 섞으면 "링크인데 해석 실패" 가 마커
    폴백으로 흘러간다(2026-08-21 리뷰 L1, 실측 재현)."""
    try:
        target = (pathlib.Path(p).parent / os.readlink(p)).resolve()
        return str(target.relative_to(ROOT))
    except (OSError, ValueError):
        return None

def canonical_of(p):
    """이 파일이 가리키는 정본. 없으면 None.

    심볼릭 링크는 **분기 자체가 다르다 — 마커 폴백으로 내려가지 않는다.** 링크는
    애초에 마커를 가질 수 없는데 open() 은 링크를 투명하게 따라가 **대상**의 앞
    20줄을 읽는다. 대상이 리포 밖이면 거기서 우연히 마커처럼 보이는 줄이
    canonical 로 잡히고, 같은 문자열을 얻은 두 링크가 면제 술어 ②로 서로를
    지운다 — 그 마커의 진위는 아무도 재지 않는다(리포 밖 파일은
    test_copy_of_contract.sh 코퍼스에도 없다). 그래서 링크는 **해석에 성공했을
    때만** 면제 자격을 얻고, 실패하면 None 이라 면제 대상이 아니다(fail-closed).
    그 상태 자체는 무결성 락이 RED 로 잡는다."""
    if pathlib.Path(p).is_symlink():
        return symlink_target_of(p)
    try:
        with open(p, encoding="utf-8") as fh:
            for i, line in enumerate(fh):
                if i >= HEAD_WINDOW: break
                m = MARKER.match(line)
                if m: return m.group(2).rstrip("->").strip()
    except (OSError, UnicodeDecodeError):
        pass
    return None

canon, body, skipped = {}, {}, []
for p in files:
    try:
        t = pathlib.Path(p).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        skipped.append(p)  # 바이너리·비-UTF8·읽기 불가는 스캔 대상 밖. 조용히가 아니라 아래 SKIPPED 로 센다.
        continue
    canon[p] = canonical_of(p)
    # 정규화: 공백만인 줄 제거. 그 외 바이트 그대로.
    body[p] = [l for l in t.split("\n") if l.strip()]

wins = collections.defaultdict(set)
for p, ls in body.items():
    for i in range(len(ls) - WINDOW + 1):
        chunk = "\n".join(ls[i:i+WINDOW])
        if len(chunk) < MIN_CHARS: continue
        wins[hashlib.sha1(chunk.encode("utf-8")).hexdigest()].add(p)

def exempt(a, b):
    # ① 한쪽이 다른 쪽을 가리킨다
    if canon.get(a) == b or canon.get(b) == a: return True
    # ② 양쪽이 같은 정본을 가리킨다
    ca, cb = canon.get(a), canon.get(b)
    return ca is not None and ca == cb

violations = collections.defaultdict(set)
for h, ps in wins.items():
    if len(ps) < 2: continue
    ps = sorted(ps)
    for i in range(len(ps)):
        for j in range(i+1, len(ps)):
            if not exempt(ps[i], ps[j]):
                violations[(ps[i], ps[j])].add(h)

def bucket_of(p):
    """코퍼스 pathspec(`plugins/*` `shared/*`)이 도출하는 **기여 단위**.
    plugins 는 플러그인마다 하나씩, shared 는 통째로 하나."""
    parts = p.split("/")
    if parts[0] == "plugins" and len(parts) > 1:
        return "plugins/" + parts[1]
    return parts[0]

buckets = collections.Counter(bucket_of(p) for p in body)

print(f"LISTED {len(files)}")
print(f"SCANNED {len(body)}")
print(f"SKIPPED {len(skipped)}")
print(f"WINDOWS {sum(len(v) for v in wins.values())}")
for name in sorted(buckets):
    print(f"BUCKET {buckets[name]} {name}")
for p in sorted(skipped):
    print(f"SKIPPEDFILE {p}")
for (a, b), hs in sorted(violations.items()):
    print(f"VIOLATION {len(hs)} {a} {b}")
PY
)"

listed="$(printf '%s\n' "$OUT" | awk '$1=="LISTED"{print $2}')"
scanned="$(printf '%s\n' "$OUT" | awk '$1=="SCANNED"{print $2}')"
skipped="$(printf '%s\n' "$OUT" | awk '$1=="SKIPPED"{print $2}')"
windows="$(printf '%s\n' "$OUT" | awk '$1=="WINDOWS"{print $2}')"

# 양성(vacuous 아님) 그 첫째 — **∀-지배관계.** "위반 0"과 "아무것도 안 봄"을 가르는 데
# 총량 하한 하나로는 모자란다: 하한은 코퍼스의 *붕괴*만 잡고 *축소*는 못 잡는다.
# 2026-08-21 whole-branch 리뷰가 실측으로 보인 모양이 그것이다 — :46 의 pathspec 을
# `'plugins/*'` → `'plugins/quality-gates/*'` 로 좁히면 221파일이 남아 어떤 리터럴 하한도
# 여유롭게 넘는데, 나머지 네 플러그인 전체가 중복 스캔에서 조용히 빠진 채 락은 계속
# "vacuous 아님" 을 찍는다. 이 리포가 이미 문서화한 실패 클래스 그대로다 —
# docs/audits/2026-08-21-skill-split-lock-corpus-shrink.md §3 (코퍼스가 줄어도 락은 GREEN).
# 굳혀 둔 것이 임계값(WINDOW/MIN_CHARS)뿐이었고, 조용한 축소는 임계가 아니라 **코퍼스
# 도출**에서 일어난다.
#
# 그래서 기대치를 리터럴이 아니라 **파일시스템에서 도출**한다: `plugins/*/` 디렉토리
# **각각**과 `shared` 가 스캔 코퍼스에 **1건 이상** 기여해야 한다(∀). 리터럴 열거를 쓰지
# 않는 이유는 시간이다 — 내일 생길 플러그인을 오늘 열거할 수 없어 리터럴 목록은 **시간에
# 대해 fail-open** 이다(형제 락 test_copy_of_contract.sh 가 기대 최소치를 자기 본문에서
# 도출하는 것과 같은 정신). `shared` 는 조건 없이 기대 목록에 넣는다 — 이 파일이 그 안에
# 살기 때문에 `shared` 가 코퍼스에서 사라지는 것 자체가 RED 여야 한다.
#
# 이 ∀ 가 세는 것은 listing 이 아니라 **실제로 읽힌 파일**(BUCKET 은 SCANNED 에서 나온다).
# 그래서 "pathspec 이 좁아졌다" 와 "목록엔 있는데 전부 읽기 실패" 가 같은 자리에서 잡힌다.
expected_buckets="$(
  for d in "$ROOT"/plugins/*/; do
    [ -d "$d" ] || continue
    b="${d%/}"; printf 'plugins/%s\n' "${b##*/}"
  done
  printf 'shared\n'
)"
n_expected=0; n_present=0; missing=""
while IFS= read -r b; do
  [ -n "$b" ] || continue
  n_expected=$((n_expected+1))
  if printf '%s\n' "$OUT" \
     | awk -v want="$b" '$1=="BUCKET"{r=$0; sub(/^BUCKET[ ]+[0-9]+[ ]+/,"",r); if (r==want) f=1} END{exit !f}'
  then n_present=$((n_present+1))
  else missing="$missing $b"
  fi
done <<EOF
$expected_buckets
EOF

if [ -z "$missing" ]; then
  ok "20줄 검사: ${scanned}파일 스캔(목록 ${listed:-?} · 건너뜀 ${skipped:-?}) · 창 ${windows}개 · 기여 단위 ${n_present}/${n_expected} (vacuous 아님)"
else
  no "20줄 검사: 스캔 코퍼스에 한 건도 기여하지 않은 단위가 있다 —${missing}. 코퍼스 도출이 좁혀졌다(기여 ${n_present}/${n_expected} · 스캔 ${scanned:-0}). 아래 판정이 무의미하다"
fi

# 양성 그 둘째 — 총량 붕괴 바닥. ∀ 와 **직교한다**: ∀ 는 "단위 하나가 통째로 사라졌다"를
# 잡고, 이 하한은 "단위마다 파일 한둘만 남기고 좁혔다"를 잡는다(예: pathspec 을
# `'plugins/*/.claude-plugin/*' 'shared/tests/*'` 로 바꾸면 ∀ 는 전부 만족하는데 총량이
# 한 자리로 떨어진다). 반대로 `plugins/` 가 통째로 비어 ∀ 의 기대 목록이 `shared` 뿐이
# 되는 퇴화도 이쪽이 잡는다. 그래서 둘을 함께 둔다.
# 50 은 측정값이 아니라 **붕괴 바닥**이다 — 실측 445 에서 한참 아래에 둬 평범한 증감에
# 반응하지 않게 한 값이고, 축소를 잡는 것은 이 숫자가 아니라 위의 ∀ 다.
if [ "${scanned:-0}" -ge 50 ]; then
  ok "20줄 검사: 스캔 총량 ${scanned} ≥ 50 (붕괴 바닥)"
else
  no "20줄 검사: ${scanned:-0}파일만 스캔 — 코퍼스 도출이 깨졌다. 아래 판정이 무의미하다"
fi

nviol=0
while IFS= read -r line; do
  case "$line" in VIOLATION*) ;; *) continue ;; esac
  nviol=$((nviol+1))
  # 잠재 결함(2026-08-17 라운드 4 기록, 오늘은 휴면): 아래 `$line` 은 **의도적으로
  # 따옴표가 없다** — 단어 분할로 VIOLATION/개수/경로A/경로B 를 $1~$4 로 쪼개려는
  # 것이다. 그래서 **추적 경로에 공백이 들어오는 순간 조용히 어긋난다**($3·$4 가
  # 경로의 앞토막만 잡아 메시지가 틀린 파일을 지목한다). 지금 리포의 추적 파일 중
  # 공백을 가진 경로가 없어 발동하지 않을 뿐, 고쳐진 것이 아니다. 고치려면 파이썬
  # 쪽 출력을 탭/NUL 구분으로 바꾸고 여기서 IFS 를 그 구분자로 고정한다.
  set -- $line
  no "20줄 검사: $3 ↔ $4 가 ${2}개 블록을 공유하는데 copy-of 로 설명되지 않는다"
done <<EOF
$OUT
EOF
[ "$nviol" -eq 0 ] && ok "20줄 검사: 설명되지 않은 동일 블록 없음 (창=${WINDOW}줄 · 최소=${MIN_CHARS}자)"

finish
