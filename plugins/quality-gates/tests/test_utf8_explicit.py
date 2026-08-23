"""non-UTF-8 로케일에서 한국어 생성 파일 읽기가 죽지 않는가.

Korean-primary 리포다. encoding 을 생략하면 파이썬이 로케일의 기본 인코딩을 쓰고,
로케일이 UTF-8 이 아니면 UnicodeDecodeError 가 난다 — 그리고 많은 호출부가 그것을
`except OSError` 로 잡지 못한다(**UnicodeDecodeError 는 OSError 의 하위가 아니다**;
ValueError 의 하위다). 그래서 실패가 예외로 새거나, 넓게 잡는 곳에서는 조용한
degrade 가 된다.

두 클래스:

  ProductionEncodingSweep — `hooks/`·`scripts/`(모든 플러그인의 production 코드)에
    새로 추가되는 `read_text`/`write_text`/`open` 이 encoding 없이 들어오는 것을
    막는다. `tests/` 는 스코프 밖이다 — 그 트리의 압도적 다수(~160여 곳)는 순수
    ASCII 픽스처 문자열(`"x"`, `"ok"`, 파일 경로 등)만 쓰고 읽어서 로케일 무관이고,
    전수 인코딩은 churn 만 남긴다. 이 락은 test 파일이 아니라 production 표면만
    지킨다 — 실제로 non-UTF-8 로케일에서 사용자를 만나는 코드다.

  LocaleRegressionTests — 정적 검사만으로는 부족하다(서브프로세스 안에서 도는
  코드의 실제 로케일 의존은 텍스트만 봐서는 안 보인다). 강제로 non-UTF-8 로케일을
  만들고 한국어 내용을 담은 실제 프로덕션 훅을 돌려 살아남는지 잰다.

  ★ Task 4 (편집한 파일을 세션 동안 추적하던 PostToolUse 훅 제거) 이후 vehicle
  정정: 원래 이 클래스는 그 세션-추적 훅으로 write_text/read_text 양쪽을 쟀다. 그
  훅이 삭제되며 quality-gates 안에 상태를 write 하는 훅이 하나도 남지 않아(post-tool-use.py·
  session-end-cleanup.py·session-start-advisor.py 모두 write 호출 0건, Task 4 조사)
  write 쪽은 vehicle 을 잃었다 — 이 속성은 현재 quality-gates 안에서 측정 불가능이다.
  read 쪽은 session-start-advisor.py 의 frontmatter-scan(hooks/session-start-advisor.py:92,
  `agent_file.read_text(encoding="utf-8")`)으로 재확보했다 — 한국어 내용을 담은
  agent frontmatter 파일이 non-UTF-8 로케일 아래서도 읽혀 경고를 내는지로 잰다.

  ★ `LC_ALL=C`·`LANG=C` 만으로는 로케일이 안 바뀐다 — 이 macOS 파이썬은 PEP 538/540
  coercion 으로 C/POSIX 로케일을 조용히 UTF-8 로 승격시킨다(`locale.getpreferredencoding()`
  실측: `LC_ALL=C LANG=C` 만 주면 여전히 `UTF-8`). 진짜 non-UTF-8 기본 인코딩을 강제하려면
  `PYTHONUTF8=0`·`PYTHONCOERCECLOCALE=0` 이 함께 필요하다 — 이 조합은
  `plugins/project-init/tests/test_post_tool_use.py::test_utf8_strategy_read_under_non_utf8_locale`
  가 이미 쓰는 검증된 패턴이다(devbrew MEMORY: "성숙한 레퍼런스를 바닥부터 재구현하지
  말 것"). 브리프 스켈레톤의 `PYTHONIOENCODING=ascii` 만으로는 `getpreferredencoding()`
  이 안 바뀌어 이 테스트가 fix 유무와 무관하게 항상 통과했을 것이다 — 측정 안 되는
  락이 될 뻔한 것을 실행해서 잡았다.
"""
import json
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
PLUGIN_ROOT = pathlib.Path(__file__).resolve().parents[1]
ADVISOR_HOOK = PLUGIN_ROOT / "hooks" / "session-start-advisor.py"

# 이미 확인한 예외 셋 — 셋 다 실제 텍스트를 읽거나 쓰지 않아 encoding 이 의미가 없다.
_KNOWN_EXCEPTIONS = {
    # docstring 안의 산문 언급이지 호출이 아니다 (Task 30 axis 2 조사로 확정).
    "plugins/quality-gates/scripts/build_codex_prompt.py": {17},
    # fcntl.flock 전용 락 파일 핸들 — write()/read() 로 텍스트가 한 번도 오가지 않는다.
    "plugins/quality-gates/scripts/qg-gc.py": {81},
    "plugins/spec-distill/scripts/spec-distill-gc.py": {98},
}


def _full_call(lines: list, start_idx: int) -> str:
    """`start_idx`(0-based)에서 시작하는 호출문을 괄호 깊이로 끝까지 모은다.

    `read_text(...)`/`write_text(...)`/`open(...)` 은 여러 줄에 걸치는 경우가
    흔하다(예: `encoding="utf-8"` 가 다음 줄에 온다) — 한 줄만 보는 검사는
    이미 고쳐진 호출을 오탐하거나(이 axis 조사에서 실제로 발생) 반대로
    다음 줄의 `encoding` 을 놓친 진짜 결함을 통과시킬 수 있다.
    """
    depth = 0
    started = False
    end = start_idx
    for i in range(start_idx, min(start_idx + 20, len(lines))):
        depth += lines[i].count("(") - lines[i].count(")")
        if "(" in lines[i]:
            started = True
        if started and depth <= 0:
            end = i
            break
    return "\n".join(lines[start_idx:end + 1])


def _find_offenders(paths):
    import re
    call_re = re.compile(r'\.(read_text|write_text)\(|(?<![\w.])open\(')
    binary_re = re.compile(r'["\']([rwa]b\+?|[rwa]\+?b)["\']')
    offenders = []
    for path in paths:
        rel = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            if not call_re.search(line):
                continue
            block = _full_call(lines, i)
            if binary_re.search(block):
                continue  # "rb"/"wb" — 바이너리 모드는 대상이 아니다
            if "encoding" in block:
                continue
            lineno = i + 1
            if lineno in _KNOWN_EXCEPTIONS.get(rel, set()):
                continue
            offenders.append(f"{rel}:{lineno}")
    return offenders


class ProductionEncodingSweep(unittest.TestCase):
    """production 표면(`hooks/`·`scripts/`)에 새 미지정 encoding 이 들어오면 red."""

    def test_no_bare_read_text_write_text_or_open_in_production(self):
        paths = sorted(ROOT.glob("plugins/*/hooks/*.py")) + \
            sorted(ROOT.glob("plugins/*/scripts/*.py"))
        self.assertGreater(len(paths), 10, "스캔 대상이 비정상적으로 적다 — 글롭이 깨졌다")
        offenders = _find_offenders(paths)
        self.assertEqual(
            offenders, [],
            "encoding 미지정 read_text/write_text/open (production):\n"
            + "\n".join(offenders),
        )

    def test_the_known_exceptions_are_still_exceptions(self):
        """계측기 확인 — 예외 목록이 실제로 그 세 줄을 가리키는지.

        `_KNOWN_EXCEPTIONS` 를 조용히 넓혀서 위 테스트를 헐겁게 만드는 편집을
        여기서 잡는다: 셋 다 여전히 offender **모양**(encoding 없음)이어야 하고,
        그 개수가 정확히 3이어야 한다 — 늘어나면 새 예외가 몰래 추가된 것이다.
        """
        paths = sorted(ROOT.glob("plugins/*/hooks/*.py")) + \
            sorted(ROOT.glob("plugins/*/scripts/*.py"))
        with_exceptions_disabled = _find_offenders_without_allowlist(paths)
        flagged = {f"{rel}:{n}" for rel, ns in _KNOWN_EXCEPTIONS.items() for n in ns}
        self.assertEqual(set(with_exceptions_disabled) & flagged, flagged,
                         "알려진 예외 중 일부가 더 이상 offender 모양이 아니다 — "
                         "목록이 stale 하다")
        self.assertEqual(sum(len(v) for v in _KNOWN_EXCEPTIONS.values()), 3)


def _find_offenders_without_allowlist(paths):
    saved = dict(_KNOWN_EXCEPTIONS)
    _KNOWN_EXCEPTIONS.clear()
    try:
        return _find_offenders(paths)
    finally:
        _KNOWN_EXCEPTIONS.update(saved)


class LocaleRegressionTests(unittest.TestCase):
    """서브프로세스로 실제 production 훅을 non-UTF-8 기본 인코딩 아래 돌린다."""

    def _non_utf8_env(self):
        env = dict(os.environ)
        env.update(LC_ALL="C", LANG="C", PYTHONUTF8="0", PYTHONCOERCECLOCALE="0")
        return env

    def _non_utf8_open_default_env(self):
        """`open()`/`read_text()`/`write_text()` 의 기본 encoding(`locale.
        getpreferredencoding()`) 만 non-UTF-8 로 강제하고, `sys.stdin` 은 별도로
        UTF-8 로 고정한다.

        훅은 `json.load(sys.stdin)` 으로 payload 를 받는다 — `sys.stdin` 의
        인코딩도 로케일을 따르므로, `LC_ALL=C` 아래서 stdin 까지 같이
        non-UTF-8 이 되면 파이프로 보낸 UTF-8 바이트가 `surrogateescape` 로
        깨진 채 들어와 `write_text(..., encoding="utf-8")` 에서 무관한
        `UnicodeEncodeError`(surrogates not allowed)가 난다 — **이 axis 가 고친
        지점과 다른 결함**이다(stdin 인코딩은 Task 30 스코프 밖). `PYTHONIOENCODING`
        은 `getpreferredencoding()` 에 영향을 주지 않고 `sys.stdin`/`stdout` 만
        고정한다(실측: 아래 두 env var 조합에서 `getpreferredencoding()`은 여전히
        `US-ASCII`, `sys.stdin.encoding`은 `utf-8`) — 그래서 read_text/write_text
        경로만 골라 흔들 수 있다.
        """
        env = self._non_utf8_env()
        env["PYTHONIOENCODING"] = "utf-8"
        return env

    def test_getpreferredencoding_sanity(self):
        """계측기 확인 — 이 환경 조합이 실제로 로케일 기본 인코딩을 UTF-8 아닌
        값으로 바꾸는지 먼저 확인한다. 안 바뀌면 아래 테스트는 fix 유무와
        무관하게 늘 통과하는 가짜 락이다."""
        proc = subprocess.run(
            ["python3", "-c", "import locale; print(locale.getpreferredencoding())"],
            env=self._non_utf8_env(), capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        got = proc.stdout.strip()
        self.assertNotIn("UTF-8", got.upper(), got)
        self.assertNotIn("UTF8", got.upper(), got)

    def test_stdin_decoupled_sanity(self):
        """계측기 확인 — `_non_utf8_open_default_env()` 가 주장대로 stdin 은
        UTF-8, `open()` 기본은 non-UTF-8 로 갈리는지."""
        proc = subprocess.run(
            ["python3", "-c",
             "import locale, sys; "
             "print(locale.getpreferredencoding()); print(sys.stdin.encoding)"],
            env=self._non_utf8_open_default_env(), capture_output=True, text=True,
            timeout=10,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        pref, stdin_enc = proc.stdout.strip().splitlines()
        self.assertNotIn("UTF", pref.upper(), pref)
        self.assertIn("UTF", stdin_enc.upper(), stdin_enc)

    def test_session_start_advisor_survives_non_utf8_locale_with_korean_content(self):
        """session-start-advisor.py 의 frontmatter-scan 은 plugins/*/agents/*.md 를
        `read_text(encoding="utf-8")` 로 읽는다(hooks/session-start-advisor.py:92).
        그 파일이 한국어 본문을 담고 있어도 non-UTF-8 기본 인코딩 아래서 살아남아
        경고를 내야 한다 — 조용히 `except (OSError, UnicodeDecodeError): continue`
        로 삼켜지면 스캐너가 fail-open 한다(:109).

        Task 4 로 세션 동안 편집한 파일을 추적하던 PostToolUse 훅(원래 이
        클래스의 vehicle)이 삭제되며 write_text 쪽은 quality-gates 안에 남은
        vehicle 이 없다 — 이 테스트는 read_text 쪽만 재확보한다. write 쪽
        커버리지는 다른 vehicle 이 생기기 전까지 이 파일로 측정 불가능하다.
        """
        env = self._non_utf8_open_default_env()
        with tempfile.TemporaryDirectory() as wt_dir:
            agent_dir = pathlib.Path(wt_dir) / "plugins" / "설계-플러그인" / "agents"
            agent_dir.mkdir(parents=True)
            (agent_dir / "테스트.md").write_text(
                "---\nname: test\nallowedTools: [Read]\n---\n본문: 한국어 내용 확인용.\n",
                encoding="utf-8",
            )
            payload = {"cwd": wt_dir, "session_id": "locale-regression-advisor-01"}
            proc = subprocess.run(
                ["python3", str(ADVISOR_HOOK)],
                input=json.dumps(payload, ensure_ascii=False),
                capture_output=True, text=True, encoding="utf-8",
                cwd=wt_dir, env=env, timeout=10,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn(
                "allowedTools", proc.stderr,
                "non-UTF-8 로케일에서 한국어 agent 파일 read_text 가 조용히 실패"
                f"(또는 삼켜짐)했다: stderr={proc.stderr!r}",
            )


if __name__ == "__main__":
    unittest.main()
