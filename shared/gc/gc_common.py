# TTL-GC 공통 조각. **부분 사본**이므로 파일 전체 동일화는 안 한다 —
# state root 해석 방식이 두 플러그인에서 다르고, 그것이 각자의 고유 본문이다.
# 잔여 중복은 shared/tests/test_no_new_duplication.sh 의 20줄 검사가 지킨다.
#
# ⚠ 안전: 삭제 대상 경로 검증을 여기에 둔다. macOS bash 의 `cd ""` 는 exit 0 이고
# cwd 를 안 바꾸므로, 빈 변수가 `rm -rf` 로 흘러가면 상위 디렉토리가 지워진다.
# 파이썬에서도 같은 부류의 사고를 막기 위해 root 밖 경로를 거부한다.
"""devbrew TTL-GC 공통 조각 정본.

**담는 것** — TTL 계산 · 세션 디렉토리 나이 판정 · 안전 삭제(경로 검증 포함).

**담지 않는 것** — state root 해석. 그것이 quality-gates ↔ spec-distill 에서 다른
부분이고(전자는 payload cwd 상대, 후자는 git-aware `--git-common-dir`), 부분 사본의
"각자 고유 본문"이다. 플러그인 **안**의 중복은 그 플러그인의 파일 하나로 접는다
(quality-gates 는 `plugins/quality-gates/scripts/state_path.py`, spec-distill 은
이미 `state_path.py` 를 갖고 있다).

**배포 방식** — 실행 지점(`if __name__`)이 없는 import-only 정본이다. 각 플러그인의
`scripts/` 에 머리 한 줄짜리 마커를 단 물리 사본으로 실린다(설치본에는 `shared/` 가
없으므로 형제 사본이어야 import 가 풀린다). 사본이 정본과 갈라지지 않는지는
`shared/tests/test_copy_of_contract.sh` 축 1b·1c 가 잰다.
"""
from __future__ import annotations

import os
import shutil
import sys
import time
import uuid
from pathlib import Path

# 갓 만들어진 **빈** 세션 폴더가 첫 write 전에 수집되는 것을 막는 창.
GRACE_NS = 60 * 1_000_000_000
# 두 번 stat 사이의 간격 — 그 사이에 mtime 이 움직이면 살아있는 세션이다.
DOUBLE_STAT_DELAY_S = 0.05
# rename-then-rmtree 의 중간 이름. 이 접두는 두 플러그인의 세션 이름 패턴
# (`^[A-Za-z0-9_-]{8,}$`)에 걸리지 않는다 — 그래서 중단된 GC 가 남긴 잔해가
# 다음 실행에서 세션 폴더로 오인되지 않는다.
GC_PENDING_PREFIX = ".gc-pending-"


def ttl_ns(env_name: str, default_hours: int = 24) -> int:
    """`env_name` 시간 단위 override 를 나노초 TTL 로. 비정상 값은 기본값으로.

    0 이하와 정수가 아닌 값을 **둘 다** 기본값으로 떨어뜨린다. 0 을 그대로 쓰면
    TTL 이 0 이 되어 모든 세션 폴더가 즉시 수집 대상이 된다 — 오타 하나가
    작업 중인 상태를 지우는 방향이라, 그 방향으로 fail 하면 안 된다.
    """
    raw = os.environ.get(env_name, str(default_hours))
    try:
        n = int(raw)
        if n <= 0:
            n = default_hours
    except ValueError:
        n = default_hours
    return n * 3600 * 1_000_000_000


def folder_mtime_ns(folder: Path) -> int:
    """폴더 나이 = 직속 파일들의 최신 mtime. 직속 파일이 없으면 폴더 자신의 mtime.

    디렉토리 mtime 은 하위 **디렉토리** 변경에 반응하지 않는 플랫폼이 있어서
    파일 쪽을 먼저 본다. `OSError` 는 잡지 않는다 — 호출자가 "폴더가 사라졌다"와
    "권한이 없다"를 구분해 처리한다.
    """
    files = [p for p in folder.iterdir() if p.is_file()]
    if not files:
        return folder.stat().st_mtime_ns
    return max(p.stat().st_mtime_ns for p in files)


def within_grace(folder: Path) -> bool:
    """갓 생성된 **빈** 폴더인가. 내용이 하나라도 있으면 mtime 이 판정을 맡는다."""
    try:
        has_files = any(p.is_file() for p in folder.iterdir())
        if has_files:
            return False
        age_ns = time.time_ns() - folder.stat().st_ctime_ns
        return age_ns < GRACE_NS
    except OSError:
        # iterdir() 와 stat() 사이에 폴더가 사라졌다 — 동시 정리와의 레이스.
        return False


def safe_rmtree(target, root) -> bool:
    """`root` **아래**의 경로만 지운다. 검증을 통과해 지웠으면 True.

    거부 방향으로만 틀린다: 빈 경로 · `.`/`..` · `root` 자기 자신 · `..` 로
    빠져나가는 경로를 전부 거부하고 stderr 로 시끄럽게 알린다. 조용한 no-op 은
    삭제 실패를 성공으로 읽히게 하므로, 거부는 반드시 소리를 낸다.

    검증은 `os.path.abspath` — **어휘적** 정규화라 심볼릭 링크를 따라가지 않는다.
    root 안의 심볼릭 링크가 밖을 가리키는 경우는 이 검사를 통과하지만, 그때는
    `shutil.rmtree` 자신이 심볼릭 링크를 거부하므로(디렉토리가 아니다) 밖이 지워지지
    않는다. 여기서 판정하는 것은 **경로 문자열이 root 밖을 가리키는가** 하나다.

    True 는 "검증을 통과해 `rmtree` 를 호출했다"는 뜻이지 삭제 성공 보장이 아니다
    (`ignore_errors=True` 라 권한 오류 등은 조용히 넘어간다) — 호출자가 존재
    여부로 다시 확인해야 한다면 그렇게 해야 한다.
    """
    t_raw, r_raw = str(target), str(root)
    if not t_raw or not r_raw or t_raw in (".", "..") or r_raw in ("", "."):
        print(
            "[devbrew-gc] 삭제 거부: 축퇴 경로 (target={0!r}, root={1!r})".format(
                t_raw, r_raw),
            file=sys.stderr,
        )
        return False
    t = os.path.abspath(t_raw)
    r = os.path.abspath(r_raw)
    if t == r or not t.startswith(r + os.sep):
        print(
            "[devbrew-gc] 삭제 거부: '{0}' 는 root '{1}' 밖이다".format(t, r),
            file=sys.stderr,
        )
        return False
    shutil.rmtree(t, ignore_errors=True)
    return True


def gc_one(folder: Path, ttl: int, root) -> bool:
    """폴더 하나를 TTL 기준으로 수집. 실제로 걷어냈으면 True.

    레이스 가드 2층(호출자의 fcntl 락까지 합쳐 3층): ① `DOUBLE_STAT_DELAY_S`
    간격의 double-stat 로 "지금 쓰이는 중"을 걸러내고, ② rename 을 먼저 해
    사라짐을 원자적으로 만든 뒤 지운다. rename 이 성공한 시점에 그 폴더는 이미
    root 에서 사라졌으므로, 뒤이은 삭제가 실패해도 True 다.
    """
    if within_grace(folder):
        return False
    try:
        snap1 = folder_mtime_ns(folder)
    except OSError:
        return False
    if time.time_ns() - snap1 < ttl:
        return False
    time.sleep(DOUBLE_STAT_DELAY_S)
    try:
        snap2 = folder_mtime_ns(folder)
    except OSError:
        return False
    if snap1 != snap2:
        return False
    pending = folder.parent / "{0}{1}".format(GC_PENDING_PREFIX, uuid.uuid4().hex)
    try:
        folder.rename(pending)
    except OSError:
        return False
    safe_rmtree(pending, root)
    return True
