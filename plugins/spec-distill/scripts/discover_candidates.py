#!/usr/bin/env python3
"""스코프 문서 발견 — git 은 상계, 판정은 arm_ledger.canonical_key (설계 §4.2).

`git status` 에 **pathspec 을 주지 않는다.** 판본 4 는 `:(top,literal)` 로 중첩
접두를 빠뜨렸고, 판본 5 의 `:(glob)**docs/…` 는 선행 `**` 가 완전한 경로 컴포넌트가
아니라 `:(top,literal)` 과 동일 집합을 냈다(실측) — 고치려던 결함이 그대로였다.
슬래시를 넣은 `**/` 도 `canonical_key` 의 substring 의미와는 다른 집합이다.
그래서 wildmatch 를 쓰지 않는다: git 은 dirty 집합 전체를 상계로 주고, 좁히는 일은
플러그인 자신의 술어가 단독으로 한다. 이 형태에서는 pathspec 문법이 방정식에서
빠지므로 그 실패가 재발할 수 없다.
"""
from __future__ import annotations

import subprocess
import sys
from collections import namedtuple
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))
from arm_ledger import canonical_key  # noqa: E402 # pyright: ignore[reportMissingImports]

#: git 호출 **하나**의 상한 (arm_ledger 와 같은 값).
#:
#: "Stop 훅 timeout 10초의 절반" 이라는 초기 근거는 이 모듈에서 성립하지 않는다 —
#: `discover()` 는 이 상한을 갖는 호출을 **둘** 직렬로 하므로(루트 해석 + status)
#: 최악에는 발견 혼자 10초를 다 쓴다. 그래도 값을 낮추지 않는다: 이 상한은 예산
#: 분할이 아니라 **행 걸림(hang) 방지 backstop** 이고, 낮추면 느린 리포에서 정상
#: git 호출이 `GitUnavailable` 로 오분류돼 게이트가 통째로 꺼진다(A16 advisory 는
#: 나가지만 그 턴의 검증·dispatch 는 사라진다 — 리뷰를 *덜* 하는 방향).
GIT_TIMEOUT_SEC = 5

#: rename/copy 항목만 `XY path\0origPath\0` 로 필드가 둘이다.
_TWO_FIELD_INDEX_STATES = ("R", "C")

Candidate = namedtuple("Candidate", "path key born")


class GitUnavailable(Exception):
    """git 을 쓸 수 없다. **후보 0 과 구별돼야 한다** — A16 이 이 구별에 기댄다."""


def parse_status_z(raw: bytes) -> list[tuple[str, str]]:
    """`git status --porcelain -z` 출력을 `(XY, path)` 목록으로.

    NUL 로 쪼갠 뒤 필드를 **레코드 단위로** 소비한다. rename/copy 는 뒤따르는
    origPath 필드를 함께 먹어야 하며, 그러지 않으면 이후 전체 항목이 한 칸씩 밀린다.

    출력의 모든 레코드는 NUL 로 끝난다 — 끝이 NUL 이 아니면 스트림이 잘렸다는
    뜻이고, 그 마지막 필드는 완전한 레코드가 아니라 조각이다. 조각을 그대로
    받아들이면 파일명 절반으로 후보를 만들어낸다. 그래서 raw 가 NUL 로 끝나지
    않을 때는 마지막 필드를 먼저 버린다(정상 종료라면 그 자리는 빈 문자열이라
    버려도 무해하다).
    """
    fields = raw.split(b"\x00")
    if raw and not raw.endswith(b"\x00"):
        fields = fields[:-1]
    out: list[tuple[str, str]] = []
    i = 0
    while i < len(fields):
        f = fields[i]
        i += 1
        if len(f) < 4 or f[2:3] != b" ":
            continue            # 마지막 빈 필드 · 잘린 꼬리
        xy = f[:2].decode("utf-8", "replace")
        path = f[3:].decode("utf-8", "replace")
        if xy[0] in _TWO_FIELD_INDEX_STATES or xy[1] in _TWO_FIELD_INDEX_STATES:
            i += 1              # origPath 필드를 소비한다
        out.append((xy, path))
    return out


def born_from_status(xy: str) -> bool:
    """인덱스 자리(X)가 `?` 가 아니면 인덱스 항목이 있다 = born.

    코드를 열거하지 않고 **자리로 읽는다.** 열거는 조합을 빠뜨리고, 빠지는 대표
    사례가 하필 `AM`(git add 후 Bash 로 수정)이다 — 이 설계가 겨냥하는 시나리오.
    """
    return xy[:1] != "?"


def candidates_from_records(records, exists) -> list[Candidate]:
    """레코드 → 후보. `exists` 는 파일 존재 술어(테스트가 주입한다).

    존재 검사가 born 판정보다 **앞선다**: 스테이지된 삭제(`D `)처럼 디스크에 없는
    항목은 검증할 대상 자체가 없으므로 born 을 물을 이유가 없다. 이 순서가
    `D`·`R`·`C` 를 코드로 열거하지 않고 흡수한다.
    """
    out: list[Candidate] = []
    for xy, path in records:
        if not exists(path):
            continue
        key = canonical_key(path)
        if key is None:
            continue
        out.append(Candidate(path=path, key=key, born=born_from_status(xy)))
    out.sort(key=lambda c: c.key)
    return out


def _run_git(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            ["git", *args], cwd=str(cwd), capture_output=True, check=False,
            timeout=GIT_TIMEOUT_SEC,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise GitUnavailable(str(exc)) from exc


def discover(cwd: Path | None = None) -> list[Candidate]:
    """이 리포의 dirty·untracked 스코프 문서. git 불능이면 GitUnavailable.

    `git status --porcelain -z` 는 실행 cwd 와 무관하게 **리포-루트 상대** 경로를
    낸다(실측: `sub/deep` 에서 실행해도 `?? sub/deep/a.md` 가 아니라 `?? a.md`).
    `exists` 술어를 `cwd` 인자에 대고 조인하면, `cwd` 가 서브디렉터리일 때 모든
    경로가 "존재하지 않음"으로 갈려 **후보 0 을 조용히** 낸다 — GitUnavailable 과
    구별돼야 한다는 이 모듈 자신의 계약(A16)을 정확히 이 지점에서 깬다. 그래서
    존재 검사는 `git rev-parse --show-toplevel` 로 얻은 리포 루트에 대고 한다.
    루트 해석 자체가 실패하면 다른 git 실패와 동일하게 GitUnavailable — `cwd` 로
    되돌아가지 않는다. 되돌아가면 바로 그 침묵하는 빈 결과가 재도입된다.

    **`Candidate.path` 는 절대경로다.** git 이 주는 리포-루트 상대 경로를 그대로
    흘려보내면, 소비자가 그것을 자기 **프로세스 cwd** 에 대고 연다 — 훅의 cwd 가
    리포 서브디렉터리일 때 발견은 성공하는데 그 뒤의 파일 읽기만 실패한다. 위
    문단이 `exists` 술어에서 막은 결함과 같은 클래스가 한 층 위에서 재발하는 것이고,
    이번엔 조용하지도 않다: 읽기 실패가 **날조된 구조 실패 사유**로 바뀌어 상한까지
    block 을 내고 그 뒤 영영 침묵한다. 어느 방향도 사실이 아니다.
    루트를 아는 것은 이 함수뿐이므로 조인도 여기서 끝낸다 (소비자마다 반복하면
    빠뜨리는 소비자가 생긴다).

    키는 영향받지 않는다 — `canonical_key` 는 `find(PREFIX)` 라 절대·상대·워크트리
    경로를 같은 키로 매핑한다(그 함수의 계약이 명시한다). `resolve_mode` 도
    `PATH_PREFIX not in file_path` 라는 substring 판정이다.
    """
    start = Path(cwd) if cwd is not None else Path.cwd()
    rp = _run_git(["rev-parse", "--show-toplevel"], start)
    if rp.returncode != 0:
        raise GitUnavailable(rp.stderr.decode("utf-8", "replace").strip()
                             or f"git rev-parse rc={rp.returncode}")
    root = Path(rp.stdout.decode("utf-8", "replace").strip())
    cp = _run_git(
        ["status", "--porcelain", "-z", "--untracked-files=all"], start)
    if cp.returncode != 0:
        raise GitUnavailable(cp.stderr.decode("utf-8", "replace").strip()
                             or f"git status rc={cp.returncode}")
    cands = candidates_from_records(
        parse_status_z(cp.stdout), exists=lambda p: (root / p).exists())
    return [c._replace(path=str(root / c.path)) for c in cands]
