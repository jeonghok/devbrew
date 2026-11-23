# 품질 게이트 보안 지적 셋 고침 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 원자료 출처 검사를 약속한 범위로 좁히고, 세션 기록 픽스처의 개인정보 잠금이 모든 사전 열쇠를 보게 하고, 「이 기계가 썼다」 고 적힌 규칙 · 대기 줄 고침이 머지 전에 사용자 눈에 보이게 한다.

**Architecture:** 출처 규칙(brief · `<brief 줄기>.audit.md` · type `interview-seed-audit`)은 `team_check.py` 한 곳에 상수 · 함수로 두고, 사본을 만드는 쪽 `team_write.py` 가 그것을 가져다 쓴다(`team_write` 가 이미 `team_check` 를 import 한다 — 반대 방향은 순환이다). 기준 · HEAD 어느 쪽의 조상도 아닌 출처 커밋은 출처 커밋을 읽지 못한 때와 같은 대체 대조로 보낸다. 자기 승인은 막지 않고 드러낸다. `team_status.py` 가 확인한 끝 뒤의 `씀` 커밋 가운데 규칙 · 대기 줄 경로를 바꾼 것을 세고, `conductor_status.py show` 가 그것을 남의 고침 줄 바로 뒤에 낸다. 지휘 문서 셋에는 그 목록을 쓰는 문장을 더한다.

**Tech Stack:** Python 3(표준 라이브러리) · git 읽기 명령 · bash 테스트(`shared/tests/assert.sh`) · unittest.

**Spec:** `docs/superpowers/specs/2026-11-22-qg-security-findings-design.md`(계획 물음의 답을 반영한 판 — 커밋 0aa52970)

## Global Constraints

- 기존 종료 코드와 알림 글자는 그대로 둔다. 새로 생기는 것은 어긋남 줄 하나(출처 경로)와 `show` 의 줄 하나(이 기계가 쓴 것으로 적힌 고침)다. 대체 대조의 출처 쪽 말머리 하나(`가 기준 · HEAD 의 조상이 아니어서` 세 꼴)가 더 붙는다. 기존 말머리 셋과 같은 틀에 끼우는 변형이다.
- 출처 규칙은 두 군데에 따로 적지 않는다. `team_write.py` 에는 `".audit.md"` · `"interview-seed-audit"` 문자열이 남지 않는다(락으로 잰다).
- 보내는 글 틀과 그 사본은 바이트로 같아야 한다(있는 락).
- `references/conducting.md` 에는 한 문장(새 줄 하나)만 더하고 다른 줄은 건드리지 않는다. 열린 PR #323 · #324 가 같은 파일을 고친다.
- 판: spec-distill `8.31.0` → `8.31.1`(patch — 고침이다). 머지 전에 #323(9.0.0) · #324(8.31.0) 가운데 하나가 먼저 머지되면, 그때 기본 브랜치 판 위의 다음 patch 번호를 쓴다. 판 리터럴을 테스트에 못 박지 않는다.
- 새 셸 테스트 파일을 만들면 실행 비트(100755)가 있어야 스위트가 센다. 이 계획은 새 파일 없이 있는 테스트 파일에 더한다.
- 통과가 정답인 단언에는 심어 보는 양성 대조를 붙인다(설계 Verification Plan).
- 있는 테스트는 기대 글자를 고치지 않은 채 통과한다(AC7). 고친 자리는 아래 「AC7 보고」 에 모두 적는다.
- 전체 스위트는 `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner <이 agent 이름> --wait <초> -- bash -c '<스위트 명령>'` 으로만 돌린다. 잠금은 지휘자 대조와 같은 공유 잠금이다 — 기다림은 줄이고, 못 잡으면 주인 · 잡은 시각을 보고한다. 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 과제 안의 좁은 테스트는 잠금 없이 돌린다.
- 커밋은 pathspec 으로 하고 구현 커밋마다 `Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md` 트레일러를 단다. `git stash` · HEAD 뒤로 옮기기 · 공유 임시 폴더 glob 삭제는 하지 않는다.

## AC7 보고 (있는 테스트에서 기대를 고치는 자리)

1. `plugins/spec-distill/tests/test_team_write.sh` 의 `양의 짝(sq)` 블록(지금 966행 `assert_not_contains … "를 읽지 못해 기준" "대체 대조: 읽히는 출처 커밋(sq)에는 대체 대조가 돌지 않는다"`).
   - 그 레포는 squash 머지 뒤 출처 커밋이 남아 있지만, 그 커밋은 기준 · HEAD 어느 쪽의 조상도 아니다.
   - 사용자 답(물음 2)대로 이제 대체 대조가 돈다. 글자 단언은 초록으로 남지만 라벨의 전제가 거짓이 된다.
   - 라벨을 바꾸고, 새 말머리가 나온다는 단언을 더한다(Task 3).
2. `plugins/spec-distill/tests/test_walk_docs.py` 의 `test_old_templates_do_not_change`(옛 세 틀이 기준 커밋 `3b4e582a` 과 바이트로 같다).
   - 설계 §3 은 틀의 금지 줄에 문장을 더하라고 한다.
   - 옛 틀 둘(계획 agent · 구현 agent)도 옛 형식 보내기에서 글자 그대로 쓰이고, 남의 고침 판정은 옛 형식에도 같다.
   - 그래서 두 금지 줄도 바꾸고, 락은 「기준 틀에 그 한 구절만 끼운 것과 바이트로 같다」 로 좁힌다(그 밖의 어떤 바이트 변경도 빨개진다)(Task 6).

## Review Focus

1. 출처 커밋을 읽지 못한 새 clone(squash 머지 뒤)에서 framing audit 구간의 머리 `type` 을 어디서 읽나 — 견주는 쪽 파일(기준의 같은 파일)에서 읽어야 한다. 출처 커밋에서만 읽으면 바른 사본이 1 이 된다. → Task 3 의 `sq2` 단언(`check rc 0` 이 그대로)이 잡는다.
2. 로드맵이 없는 팀 폴더(분해안 전에 부르는 `original`)는 검사가 돌지 않는다. 한 폴더에 brief 둘을 옮기는 있는 테스트(`fa-po`)는 그대로 통과해야 한다. → Task 2 Step 4 의 파일 전체 실행이 잡는다.
3. 로드맵 머리말에 `source_brief` 가 없으면 구간마다 어긋남이 쏟아지면 안 된다. `parse_roadmap` 의 문제 줄 하나(rc 1)로 충분하다. → Task 2 의 `test_source_problem` 단위 단언(`brief_rel=None` 이면 None).
4. 일꾼이 남의 커밋을 `씀` 으로 적는 공격 — 남의 고침 줄은 사라지고 「이 기계가 쓴 것으로 적힌 고침」 에 그 커밋이 나와야 한다. → Task 5 의 심은 `씀` 단언.
5. sync 가 쓰는 STATUS 커밋도 `씀` 이다 — 규칙 · 대기 줄 경로가 아니면 목록에 나오면 안 된다. → Task 5 의 「처음에는 줄이 없다」 단언(그 앞에 sync 가 돈다).

---

### Task 1: 가벼운 다시 확인

계획을 쓸 때(2026-11-22, 기준 eecb4cf4) 한 번 했다. 실행을 시작할 때 기본 브랜치가 움직였으면 다시 본다.

**Files:** 읽기만 한다.

- [ ] **Step 1: 근거 자리가 그대로인지 본다**

```bash
cd <이 worktree> && git fetch -q origin && git log --oneline -1 origin/main
grep -n -E '_SRC_UNREAD|def check_tree|GIT_ALLOWED' plugins/spec-distill/scripts/team_check.py
grep -n -E 'FRAMING_TYPE|audit_rel = stem|def wanted_sections|def _framing_from_state' plugins/spec-distill/scripts/team_write.py
grep -n -E 'def strings|under_answers' plugins/spec-distill/tests/test_session_fixture.py
grep -n -E 'def foreign_commits|def trust_of' plugins/spec-distill/scripts/team_status.py
grep -n -E 'def _foreign_count|def render_view|"foreign": 0' plugins/spec-distill/scripts/conductor_status.py
grep -n -E '^6\. \*\*금지|^금지: ' plugins/spec-distill/references/conductor-dispatch.md
grep -n '승인 기록 다시 보이기' plugins/spec-distill/references/conducting.md
grep -n '## 남이 올린 고침을 만났을 때' plugins/spec-distill/references/conductor-state-branch.md
```

Expected: 함수 · 상수가 모두 있다. `conductor-dispatch.md` 에 금지 줄이 넷(6번 하나 · 틀 셋)이다. `conducting.md` 의 「승인 기록 다시 보이기」 가 한 줄이다. origin/main 이 6e0e718c 보다 앞서면 `plugins/spec-distill/.claude-plugin/plugin.json` 의 판도 적어 둔다(Task 6 이 쓴다).

- [ ] **Step 2: 다르면 멈춰 보고한다** — 함수가 옮겨졌거나 절이 사라졌으면 일하지 않고 그 자리를 보고한다.

---

### Task 2: 출처 경로 검사와 하나의 규칙 (AC1 · AC3)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_check.py`(상수 · 함수 · `check_tree` 의 8번 고리)
- Modify: `plugins/spec-distill/scripts/team_write.py:29-33,117-134,189-228`(규칙을 `team_check` 에서 가져온다)
- Modify: `plugins/spec-distill/references/team-files.md` §3(`original` 명령 항목 · 「출처와 바이트 같음」 항목)
- Test: `plugins/spec-distill/tests/test_team_write.sh`(끝의 `finish` 앞에 새 블록) · `plugins/spec-distill/tests/test_team_docs.py`

**Interfaces:**
- Produces (`team_check.py`):
  - `FRAMING_TYPE: str = "interview-seed-audit"`(team_write 에서 옮긴다. `team_write.FRAMING_TYPE = team_check.FRAMING_TYPE` 별칭은 남긴다 — `tests/test_raw_source.py:248` 이 읽는다)
  - `audit_of(brief_rel: str) -> Optional[str]` — `.md` 로 끝나면 `brief_rel[:-3] + ".audit.md"`, 아니면 None
  - `head_type(data: bytes) -> str` — UTF-8 로 읽어 머리말 `type` 값(따옴표 벗김). 읽지 못하면 `""`
  - `SOURCE_NOT_ALLOWED: str = "출처가 로드맵 source_brief(%s) · 그 audit · framing audit 가운데 하나가 아니다"`
  - `source_problem(source: str, brief_rel: Optional[str], blob: Optional[bytes]) -> Optional[str]` — 아래 규칙. 문제 없으면 None
- Consumes: 없음.

`source_problem` 의 규칙:
- `brief_rel` 이 None 이면 None을 낸다. `parse_roadmap` 이 이미 「frontmatter source_brief 가 없다」 를 문제 줄로 낸다.
- `source` 가 `brief_rel` 이나 `audit_of(brief_rel)` 이면 None을 낸다.
- `blob` 이 None 이면 None을 낸다. 견줄 파일이 없으면 이어지는 대조가 검사 불가(3)로 끝나므로 통과하지 않는다.
- `head_type(blob) == FRAMING_TYPE` 이면 None을 낸다.
- 그 밖에는 `SOURCE_NOT_ALLOWED % brief_rel` 을 낸다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_docs.py` 에 단위 단언을 더한다(같은 파일의 `import team_check as TC` 꼴):

```python
    def test_source_problem(self):   # AC1 · AC3 — 출처 규칙 하나
        import team_check as TC
        brief = "docs/iv/b.md"
        seed = b"---\ntype: interview-seed-audit\n---\n"
        self.assertEqual(TC.audit_of(brief), "docs/iv/b.audit.md")
        self.assertIsNone(TC.audit_of("docs/iv/b.txt"))
        self.assertIsNone(TC.source_problem(brief, brief, b"x"))
        self.assertIsNone(TC.source_problem("docs/iv/b.audit.md", brief, b"x"))
        self.assertIsNone(TC.source_problem("anywhere/s.audit.md", brief, seed))
        self.assertEqual(TC.source_problem("docs/x/forged.audit.md", brief, b"---\ntype: interview-audit\n---\n"),
                         TC.SOURCE_NOT_ALLOWED % brief)
        self.assertEqual(TC.source_problem("docs/iv/other.md", brief, b"no head"), TC.SOURCE_NOT_ALLOWED % brief)
        self.assertIsNone(TC.source_problem("docs/x/forged.audit.md", None, b"x"))     # Review Focus 3
        self.assertIsNone(TC.source_problem("docs/x/forged.audit.md", brief, None))    # 견줄 파일 없음 — 대조가 3 으로 끝낸다

    def test_one_source_rule(self):   # 규칙을 두 군데에 따로 적지 않는다
        tw = (SCRIPTS / "team_write.py").read_text(encoding="utf-8")
        tc = (SCRIPTS / "team_check.py").read_text(encoding="utf-8")
        for lit in ('".audit.md"', '"interview-seed-audit"'):
            self.assertNotIn(lit, tw, lit)
            self.assertEqual(tc.count(lit), 1, lit)
```

`test_team_write.sh` 의 `finish` 앞에 새 블록을 더한다. `fresh src` 로 레포 사본을 뜨고, `ttc "$T/src" "$T/src.md" "${RD}src"`(rc 0)로 팀 폴더를 만들어 커밋 · push 한다. 그 사본에서:
- 도우미 `plant <레포> <원자료 사본> <출처> <커밋> <첫 줄> <끝 줄>` 을 쓴다. `$T/plant.py` 가 `team_files.extend_original(있는 바이트, [(출처, 커밋, "사용자 원문", 첫 줄, 그 커밋의 그 줄들, "")])` 로 구간 하나를 끝에 붙인다. 붙이기 전 · 뒤의 `markers` 수가 하나 늘었는지 단언한다(같은 바이트라 건너뛰면 픽스처가 무너진 것이다).
- 사례마다 `cp` 로 둔 원본 사본에서 시작하고 끝에 되돌린다.
- 검사 명령은 `(cd "$T/src" && python3 "$S/team_layout.py" check --roadmap "${RD}src/roadmap.md" "$@") > "$T/chk.txt" 2>&1; echo $?` 꼴의 `srccheck` 다.

단언(라벨은 이 글자 그대로 시작한다):
- `AC1 위조 출처:` — `docs/x/forged.audit.md` 를 새로 커밋한다(`docs/iv/t-brief-interview.audit.md` 를 복사하고 §6 한 줄을 바꾼 글, 머리 type 은 그대로). 그 줄을 `plant` 하면 `srccheck` rc `1` 이다. `chk.txt` 에 `(출처 docs/x/forged.audit.md · 사용자 원문 ` 와 `출처가 로드맵 source_brief(docs/iv/t-brief-interview.md) · 그 audit · framing audit 가운데 하나가 아니다` 가 있다. 양성 짝으로, 되돌린 사본은 rc `0` 이다.
- `AC1 다른 brief:` — `docs/iv/u-brief-interview.md` 의 §6 줄을 `plant` 하면 rc `1` 이다(사용자 답 1).
- `AC1 다른 brief · original:` — `(cd "$T/src" && python3 "$RW" original --brief docs/iv/u-brief-interview.md --out "${RD}src")` 는 rc `1` 이다. 출력에 `검사 실패` 가 있고 `snap "$T/src"` 는 그대로다.
- `남는 것(framing 꼴):` — 머리 `type: interview-seed-audit` 인 `docs/x/fake-seed.audit.md` 를 커밋하고 `plant` 하면 rc `0` 이다. 설계가 공시하는 경계이자 framing 길의 양성 대조다.
- `AC3 framing 있음:` — 만든 그대로의 `src` 팀 폴더는 `srccheck` rc `0` 이다.
- `AC3 framing 없음:` — `(cd "$FA" && python3 "$S/team_layout.py" check --roadmap "${RD}fa-o-<그 블록의 첫 kind>/roadmap.md")` 는 rc `0` 이다. 이 단언은 framing 없이 만든 사본의 블록(지금 1217–1222행 근처의 `fa_create "o-$kind"`) 바로 뒤에 둔다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py -k source -k one_source_rule; bash plugins/spec-distill/tests/test_team_write.sh 2>&1 | grep -E '^(not ok|FAIL)|AC1|남는 것|AC3' | head -20`
Expected: `AttributeError: module 'team_check' has no attribute 'audit_of'`. `AC1 위조 출처: rc 1` 이 실패한다(지금은 0).

- [ ] **Step 3: 구현한다**

- `team_check.py` 에 위 Interfaces 의 다섯을 둔다.
- `check_tree` 의 1번에서 `brief_rel = meta.get("source_brief") or None` 을 잡는다(로드맵을 못 읽으면 None).
- 8번 고리에서, 출처 커밋의 blob 을 읽은 뒤 바이트를 견주기 전에 `source_problem(s.source, brief_rel, blob)` 을 부른다. 문제면 `"%s: %s" % (where, problem)` 을 errors 에 넣고 `continue` 한다.
- `team_write.py` 는 `audit_rel = team_check.audit_of(brief_rel)` 을 쓴다. `_framing_from_state` 의 `seed[:-3] + ".audit.md"` 는 `team_check.audit_of(seed)`(`.md` 검사는 그대로 앞에 둔다)를 쓴다. type 비교는 `team_check.head_type(data) != team_check.FRAMING_TYPE` 로 바꾸고 거절 글자는 그대로 둔다.
- `team-files.md` §3 의 `original` 명령 항목 목록 끝에 한 줄을 더한다: `- 원자료 사본은 로드맵의 \`source_brief\` 하나에서만 옮긴다 — 로드맵이 있는 폴더에서 다른 인터뷰 결과물로 \`original\` 을 부르면 쓰기 전 검사에서 거절되고 사유가 나온다.`
- 「출처와 바이트 같음」 항목의 첫 하위 항목으로 한 줄을 더한다: `  - 출처 경로는 로드맵 \`source_brief\` 가 가리키는 인터뷰 결과물 · 그 audit(이름의 \`.md\` 를 \`.audit.md\` 로 바꾼 파일) · framing audit(견주는 쪽 파일의 머리 \`type\` 이 \`interview-seed-audit\`) 가운데 하나다. 아니면 바이트를 견주지 않고 어긋남이다. 같은 브랜치에 framing audit 꼴을 갖춘 파일을 새로 커밋하면 이 검사를 지나간다 — 그 파일은 PR 에 새 파일로 보인다.`

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_raw_source.py && bash plugins/spec-distill/tests/test_team_write.sh 2>&1 | tail -3 && python3 -m unittest plugins/spec-distill/tests/test_team_layout.py`
Expected: 모두 통과하고 `test_team_write.sh` 의 끝 줄에 실패 0. 있는 단언(특히 `fa-po` 의 brief 둘 · 짝 픽스처)은 글자를 고치지 않고 통과한다.

- [ ] **Step 5: 커밋한다**

```bash
git add -- plugins/spec-distill/scripts/team_check.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_docs.py
git commit -m "fix(spec-distill): 원자료 출처를 source_brief · audit · framing audit 로 좁힌다" -m "Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md" -- plugins/spec-distill/scripts/team_check.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_docs.py
```

---

### Task 3: 조상이 아닌 출처 커밋은 대체 대조로 (AC2)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_check.py`(`GIT_ALLOWED` · `_SRC_FOREIGN` · `is_ancestor` · 8번 고리)
- Modify: `plugins/spec-distill/references/team-files.md` §3(말머리 목록 · 하위 항목 한 줄)
- Test: `plugins/spec-distill/tests/test_team_write.sh`(Task 2 블록에 이어서 · `양의 짝(sq)` 라벨) · `plugins/spec-distill/tests/test_team_docs.py:263`

**Interfaces:**
- Consumes: Task 2 의 `source_problem` · `brief_rel`.
- Produces (`team_check.py`):
  - `GIT_ALLOWED` 에 `"merge-base"` 를 더한다(읽기 명령).
  - `_SRC_FOREIGN = ("가 기준 · HEAD 의 조상이 아니어서", "가 기준 · HEAD 의 조상이 아니고", "가 기준 · HEAD 의 조상이 아니다")` — 기존 `_SRC_*` 와 같은 세 자리(같음 알림 · 다름 · 기준 모름).
  - `is_ancestor(top, commit: str, of: Optional[str]) -> bool` — `of` 가 None 이면 False. 아니면 `merge-base --is-ancestor <commit> <of>` 의 rc 가 0 일 때 참.

8번 고리의 새 흐름(구간마다):
1. `blob = show(top, s.commit, s.source)` 를 읽는다.
2. `reached = blob is not None and (is_ancestor(top, s.commit, commit) or is_ancestor(top, s.commit, head))` 를 계산한다. `head = _commit_of(top, "HEAD")` 는 고리 앞에서 한 번 구한다.
3. `reached` 이면 Task 2 대로 `source_problem` → 바이트 대조를 하고 끝낸다.
4. 아니면 대체 대조로 간다. 말머리는 `blob is not None` 이면 `_SRC_FOREIGN`, 아니면 지금의 셋 가운데 하나다.
5. 기준의 파일 `at_base` 를 읽었으면 바이트를 견주기 전에 `source_problem(s.source, brief_rel, at_base)` 를 부른다. 문제면 어긋남을 내고 다음 구간으로 간다. Review Focus 1 이 이것이다 — type 은 견주는 쪽 파일에서 읽는다.
6. 나머지 갈래(기준 모름 · 기준에 없음 · 못 읽음 · 같음 · 다름)와 글자는 지금 그대로 둔다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

Task 2 블록에 이어, 같은 `src` 사본에서:
- `AC2 다른 ref 의 위조:` — `side` 브랜치에서 `docs/iv/t-brief-interview.md` 의 §6 한 줄 k 를 바꿔 커밋(`side_commit`)하고 `main` 으로 돌아온다. 브랜치는 남긴다 — 커밋 객체가 읽히는 상태다. `plant` 로 그 줄 k..k 를 `side_commit` 출처로 붙인다. 픽스처 대조로, `python3 "$T/sections_match.py" <사본> "$T/src"` 는 `ok` 다 — 옛 검사라면 통과했을 사본이라는 증거다. 이 사본에서 `srccheck` rc `3` 이다. `chk.txt` 에 `출처 커밋 ${side_commit:0:12} 가 기준 · HEAD 의 조상이 아니고 기준 refs/remotes/origin/HEAD 의 같은 줄과도 다르다` 가 있다.
- `AC2 다른 ref · 같은 바이트:` — `side2` 에서 §6 밖의 줄만 바꿔 커밋한다. 바뀌지 않은 §6 줄을 그 커밋 출처로 `plant` 하면 rc `0` 이다. `chk.txt` 에 `출처 커밋 ${side2_commit:0:12} 가 기준 · HEAD 의 조상이 아니어서 기준 refs/remotes/origin/HEAD 의 같은 줄과 견줬다 — 같다` 가 있다.
- `AC2 HEAD 의 조상:` — 지금 브랜치에서 push 하지 않은 커밋으로 §6 한 줄을 바꾸고, 그 줄을 그 커밋 출처로 `plant` 하면 rc `0` 이다. `chk.txt` 에 `의 같은 줄과 견줬다` 가 없다(대체 대조가 돌지 않는다).
- `양의 짝(sq)` 블록은 AC7 보고 1 이다. 966행의 라벨을 `대체 대조: 출처 커밋이 읽혀도 기준 · HEAD 의 조상이 아니면(squash 뒤) 「읽지 못해」 라 하지 않는다` 로 바꾼다. 바로 뒤에 `assert_contains "$(cat "$T/chk.txt")" "출처 커밋 ${stamp:0:12} 가 기준 · HEAD 의 조상이 아니어서 기준 refs/remotes/origin/HEAD 의 같은 줄과 견줬다 — 같다" "대체 대조(sq): squash 뒤 남은 출처 커밋도 기준과 견준다 — 새 clone(sq2)과 판정이 같다"` 를 더한다. 이 단언이 기대려면 `sqcheck "$T/sq"` 직후여야 한다 — 그 자리로 옮기거나 `sqcheck` 를 한 번 더 부른다.
- `test_team_docs.py:263` 의 고리에 `TC._SRC_FOREIGN` 을 더한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh 2>&1 | grep -E 'AC2|대체 대조\(sq\)' ; python3 -m unittest plugins/spec-distill/tests/test_team_docs.py`
Expected: `AC2 다른 ref 의 위조: rc 3` 이 실패한다(지금은 0). `_SRC_FOREIGN` 이 없어 AttributeError 가 난다.

- [ ] **Step 3: 구현한다** — 위 Interfaces 와 흐름대로.

`team-files.md` §3 을 이렇게 고친다:
- 말머리 목록 `` `를 읽지 못해`(커밋이 없다) · `에 그 파일이 없어` · `에서 그 파일을 읽지 못해` `` 끝에 `` · `가 기준 · HEAD 의 조상이 아니어서`(커밋은 읽히나 기준 · 지금 HEAD 어느 쪽의 조상도 아니다) `` 를 더한다.
- Task 2 가 더한 하위 항목 바로 뒤에 한 줄을 더한다: `  - 출처 커밋이 기준과 지금 HEAD 어느 쪽의 조상도 아니면 출처 커밋을 읽지 못한 때와 같이 기준의 같은 파일 · 같은 줄과 견준다 — 다른 ref 에 심은 커밋은 기준에 그 글이 없어 통과하지 않고, squash 머지 뒤에도 기계마다 판정이 같다.`

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh 2>&1 | tail -3 && python3 -m unittest plugins/spec-distill/tests/test_team_docs.py`
Expected: 실패 0. `sq2` 의 단언들(`check rc 0` · 알림 2줄)과 `sq8` 의 단언들은 글자를 고치지 않고 통과한다.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "fix(spec-distill): 기준 · HEAD 의 조상이 아닌 출처 커밋은 기준과 견준다" -m "Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md" -- plugins/spec-distill/scripts/team_check.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_docs.py
```

---

### Task 4: 개인정보 잠금이 모든 열쇠를 본다 (AC4)

**Files:**
- Modify: `plugins/spec-distill/tests/test_session_fixture.py:23-47,59-69`

**Interfaces:**
- Produces: `IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")` · `is_safe_key(k: str) -> bool`(`is_safe(k) or IDENT.fullmatch(k)`) · `unsafe(value) -> Iterator[str]`. `unsafe` 는 `is_safe` 가 아닌 글 값과 `is_safe_key` 가 아닌 열쇠를 낸다. 모든 깊이의 사전 · 목록을 다 돈다. `strings()` 는 지운다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
    def test_keys_outside_answers_are_checked(self):   # AC4 — PR #305 리뷰
        _use, res = entries("answer")
        for bad in ("설계를 승인할까요?", "/Users/someone/x", "a@b.example"):
            planted = json.loads(json.dumps(res))
            planted["toolUseResult"]["annotations"] = {bad: {"notes": "자리표시"}}
            self.assertIn(bad, list(unsafe(planted)), bad)
            nested = json.loads(json.dumps(res))
            nested["message"]["content"][0][bad] = "자리표시"            # 목록 안 사전의 열쇠
            self.assertIn(bad, list(unsafe(nested)), bad)

    def test_identifier_keys_pass_and_the_fixtures_are_clean(self):   # AC4 뒷부분 — 양성 대조는 위 심은 열쇠
        self.assertEqual(list(unsafe({"advisorModel": "자리표시", "is_error": True})), [])
        for path in sorted(DATA.glob("*.jsonl")):
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                self.assertEqual(list(unsafe(json.loads(line))), [], "%s:%d" % (path.name, n))
```

있는 `test_every_string_is_a_placeholder_or_a_fixed_word` 는 위 둘째 테스트가 대신한다. 이름을 남겨 같은 몸(`unsafe` 가 빈 목록)으로 둔다 — AC7: 기대는 그대로이고 부르는 함수만 바뀐다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py`
Expected: `NameError: name 'unsafe' is not defined`

- [ ] **Step 3: 구현한다** — Interfaces 대로. 목록의 원소에도 사전 열쇠 검사가 걸려야 한다(지금 `strings()` 가 놓치는 자리).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py -v 2>&1 | tail -5`
Expected: OK. 심은 열쇠가 걸리는지 보려면 `unsafe` 의 열쇠 검사 줄을 잠시 지운다. 그러면 `test_keys_outside_answers_are_checked` 가 빨개져야 한다. 확인한 뒤 되돌리고 `git diff HEAD -- plugins/spec-distill/tests/test_session_fixture.py` 로 의도한 차이만 남았는지 본다.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "fix(spec-distill): 세션 기록 개인정보 잠금이 모든 사전 열쇠를 본다" -m "Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md" -- plugins/spec-distill/tests/test_session_fixture.py
```

---

### Task 5: `show` 가 이 기계가 쓴 것으로 적힌 고침을 낸다 (AC5)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py:94-132`(나눈다)
- Modify: `plugins/spec-distill/scripts/conductor_status.py:579,665,704-714,793-806`
- Test: `plugins/spec-distill/tests/test_conductor_cross.py`(`foreign_write` 가 있는 클래스)

**Interfaces:**
- Produces (`team_status.py`):
  - `edits_since(git, tip, trust, paths) -> Optional[list]` — 지금 `foreign_commits` 의 몸에서 마지막 걸러내기만 뺀 것이다. 범위 · 머지 검사(`own` 을 그대로 쓴다) · 재지 못함의 뜻이 같다. `[(커밋 40자, (바꾼 경로…)), …]` 를 오래된 차례로 낸다.
  - `foreign_commits(...)` 는 `edits_since` 가운데 `own` 에 없는 것이다(이름 · 반환 그대로).
  - `own_commits(git, tip, trust, paths) -> Optional[list]` 는 `edits_since` 가운데 `own` 에 있는 것이다.
- Produces (`conductor_status.py`):
  - `OWN_EDITS = "이 기계가 쓴 것으로 적힌 고침 %d"`
  - `_edits(root, roadmap_rel, team, seen) -> tuple` 는 (남의 고침 수 | None, 내 고침 목록 | None) 을 낸다. `_foreign_count` 를 대신한다(기계 상태를 한 번만 읽는다). 다른 호출자가 있으면 같은 값을 받게 고친다.
  - `own_lines(own: Optional[list]) -> list` — 비었거나 None 이면 `[]`. 아니면 `[OWN_EDITS % n] + ["  %s · %s" % (c[:8], " · ".join(CB.visible(p) for p in paths)) ...]`.
  - 화면(view)의 열쇠 `"own"`: 기본 `[]`(579행의 `"foreign": 0` 옆). `render_view` 는 `not view["unavailable"]` 일 때 남의 고침 줄 바로 뒤에 `own_lines(view["own"])` 를 낸다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_conductor_cross.py`, `foreign_write` 이웃)

```python
    def test_own_rules_edit_is_listed_after_the_foreign_line(self):   # AC5
        self.assertNotIn("이 기계가 쓴 것으로 적힌 고침", self.text())          # 처음에는 없다 — STATUS 쓰기만 한 `씀` 은 세지 않는다(Review Focus 5)
        team = CB.team_of(self.w, rm(ALPHA))
        commit = CB.write(self.w, rm(ALPHA), <이 클래스가 ALPHA 를 claim 한 세션>, lambda b: {team.rules: "- [나] 내 줄\n"}, "내").commit
        out = self.text()
        self.assertIn("\n" + CS.OWN_EDITS % 1 + "\n  %s · %s\n" % (commit[:8], team.rules), out)
        self.assertLess(out.index(CS.OWN_EDITS % 1), out.index("다른 로드맵과 닿는 것"))
        self.assertEqual(CS.cross_view(self.w, rm(ALPHA), now=at(20))["own"], [(commit, (team.rules,))])

    def test_a_planted_own_row_moves_a_foreign_edit_into_the_own_list(self):   # G3 — 일꾼이 남의 고침을 `씀` 으로 적는다
        team = CB.team_of(self.w, rm(ALPHA))
        commit = self.foreign_write(ALPHA, {team.path(CB.PENDING_FILE): "- A1 · 결정 기록 · 남\n"})
        self.assertIn(TS.FOREIGN % 1 + CS.FOREIGN_TAIL, self.text())             # 양성 대조 — 심기 전에는 남의 고침이다
        CB.record_own(self.w, rm(ALPHA), <같은 세션>, [commit])
        out = self.text()
        self.assertNotIn("확인되지 않은 남의 고침", out)
        self.assertIn("\n" + CS.OWN_EDITS % 1 + "\n  %s · %s\n" % (commit[:8], team.path(CB.PENDING_FILE)), out)
```

`team_status` 쪽 단언(`tests/test_leader_seat.py` 의 남의 고침 클래스 끝): 같은 픽스처에서 `TS.own_commits` 와 `TS.foreign_commits` 의 커밋 합집합이 `TS.edits_since` 와 같다. 둘은 겹치지 않는다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_cross.py -k own plugins/spec-distill/tests/test_leader_seat.py`
Expected: `AttributeError: module 'conductor_status' has no attribute 'OWN_EDITS'`

- [ ] **Step 3: 구현한다** — Interfaces 대로. `sync` 의 출력은 바꾸지 않는다(설계는 `show` 만).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_status.py && bash plugins/spec-distill/tests/test_leader_seat_e2e.sh 2>&1 | tail -2`
Expected: 모두 통과하고, 있는 남의 고침 단언은 글자 그대로다.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "fix(spec-distill): show 가 이 기계가 쓴 것으로 적힌 규칙 · 대기 줄 고침을 보인다" -m "Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md" -- plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_leader_seat.py
```

---

### Task 6: 지휘 문서 세 문장 · 판 올림 (AC6)

**Files:**
- Modify: `plugins/spec-distill/references/conductor-dispatch.md:35,153,168,192`
- Modify: `plugins/spec-distill/references/conducting.md`(73행 바로 뒤 새 줄 하나)
- Modify: `plugins/spec-distill/references/conductor-state-branch.md`(「남이 올린 고침을 만났을 때」 의 `씀` 항목 뒤 · 줄마다 할 일 표)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`
- Test: `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` · `test_walk_docs.py` · `test_conducting_loop.sh` · `test_conductor_state_branch_docs.py`

**Interfaces:** Consumes: Task 5 의 `OWN_EDITS` 글자 「이 기계가 쓴 것으로 적힌 고침」.

넣을 글(글자 그대로):
- D1: `conductor-dispatch.md` 「늘 싣는 것」 6번 끝(「… 그 파일을 되돌리지 않는다.」 뒤)에 붙인다 — ` 기계 상태의 \`확인한 끝\` 절과 상태 브랜치는 쓰지 않는다 — 그 절의 \`씀\` 줄은 남의 고침을 이 기계가 쓴 것으로 보이게 한다.`
- D2: 틀 셋(계획 agent · 구현 agent · team 형식)의 금지 줄에서 `HEAD 뒤로 옮기기.` 를 `HEAD 뒤로 옮기기 · 기계 상태의 확인한 끝 절과 상태 브랜치 쓰기.` 로 바꾼다. 다른 바이트는 그대로 둔다.
- D3: `conducting.md` 73행 바로 뒤 새 줄을 넣는다. 들여쓰기는 73행 항목의 글과 같은 4칸이다 — `    team 형식이면 \`conductor_status.py show\` 가 내는 「이 기계가 쓴 것으로 적힌 고침」 목록도 함께 싣는다 — 그 가운데 리더가 쓰지 않은 고침이 있으면 머지 명령 줄을 내지 않고 사용자에게 알린다.`
- D4: `conductor-state-branch.md` 「남이 올린 고침을 만났을 때」 의 `- \`씀\` 은 이 기계가 그 부름 안에서 만든 커밋만이다. …` 항목 바로 뒤에 한 줄을 넣는다 — `- \`씀\` 줄은 기계 상태 파일에 있어 이 기계에서 도는 누구나(담당자 세션 · 하위 agent 도) 쓸 수 있다 — 남의 고침을 \`씀\` 으로 적으면 위 판정은 그 고침을 세지 않는다. 막지 않고 드러낸다: \`conductor_status.py show\` 가 확인한 끝 뒤의 \`씀\` 커밋 가운데 규칙 사본 · \`rules-base.md\` · \`pending.md\` 를 바꾼 것을 「이 기계가 쓴 것으로 적힌 고침 n」 과 커밋마다 한 줄(\`<8자> · <바꾼 경로들>\`)로 내고, 머지 전 「승인 기록 다시 보이기」 가 그 목록을 싣는다.`
- D5: 같은 파일 줄마다 할 일 표의 137행(「확인되지 않은 남의 고침 n …」) 바로 뒤에 행을 넣는다 — `| 「이 기계가 쓴 것으로 적힌 고침 n」 과 커밋 줄(\`show\`) | 0 | 커밋마다 리더가 쓴 것인지 본다 — 쓰지 않은 것이 있으면 머지 전에 사용자에게 알린다 |`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

- `test_conductor_dispatch_reference.sh`: `once '## 늘 싣는 것' '기계 상태의 \`확인한 끝\` 절과 상태 브랜치는 쓰지 않는다'` 를 더한다. 틀 셋마다 블록에 `HEAD 뒤로 옮기기 · 기계 상태의 확인한 끝 절과 상태 브랜치 쓰기.` 가 한 번 있다는 단언을 더한다(`TPL` 에서 `### ` 로 자른 블록 — 있는 `blk` 꼴. team 형식 블록 머리는 `### team 형식 — 계획 · 구현 담당자`).
- `test_walk_docs.py::test_old_templates_do_not_change`(AC7 보고 2): `self.assertEqual(fence_under(self.TEXT, heading), fence_under(old, heading).replace("HEAD 뒤로 옮기기.", "HEAD 뒤로 옮기기 · 기계 상태의 확인한 끝 절과 상태 브랜치 쓰기.", 1) if heading != "### 이어 부르기" else fence_under(old, heading), heading)` 꼴로 좁힌다. 양성 대조로, 옛 블록에 그 구절이 정확히 한 번 있다는 단언(`fence_under(old, heading).count("HEAD 뒤로 옮기기.") == 1`)을 붙인다.
- `test_conducting_loop.sh`: `once 5 '목록도 함께 싣는다 — 그 가운데 리더가 쓰지 않은 고침이 있으면 머지 명령 줄을 내지 않고 사용자에게 알린다'` 를 더한다.
- `test_conductor_state_branch_docs.py::test_procedure_file_has_the_three_new_sections` 의 words 에 `"이 기계에서 도는 누구나"` · `"이 기계가 쓴 것으로 적힌 고침 n"` 을 더한다. 코드와 글자를 맞추는 단언 `self.assertIn(CS.OWN_EDITS.replace("%d", "n"), text)` 도 더한다(그 파일에 `import conductor_status as CS` 가 없으면 더한다).

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -2; bash plugins/spec-distill/tests/test_conducting_loop.sh 2>&1 | tail -2; python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py`
Expected: 새 단언이 실패한다(글이 아직 없다). 옛 틀 락은 아직 초록이다.

- [ ] **Step 3: D1–D5 를 넣고 판을 올린다**

- `plugin.json` 의 `version` 을 `8.31.1` 로 바꾼다. 기본 브랜치가 그새 올라갔으면 그 위의 다음 patch 다(Global Constraints).
- `CHANGELOG.md` 맨 위에 `## [8.31.1] — 2026-11-22` 와 `### Security` 를 둔다. 줄 셋을 쓴다:
  - ① `team_layout.py check` 가 원자료 사본의 출처를 로드맵 `source_brief` · 그 audit · framing audit 로 좁힌다. 기준 · HEAD 의 조상이 아닌 출처 커밋은 기준과 견준다. 다른 brief 로 부른 `original` 은 로드맵이 있는 폴더에서 거절된다(PR #283 리뷰).
  - ② 세션 기록 픽스처의 개인정보 잠금이 모든 사전 열쇠를 본다(PR #305 리뷰).
  - ③ `conductor_status.py show` 가 「이 기계가 쓴 것으로 적힌 고침 n」 을 낸다. 보내는 글 · 틀의 금지 줄 · 머지 전 승인 기록 다시 보이기 · 상태 브랜치 문서가 그 목록과 한계를 적는다(PR #314 리뷰).
- 각 줄 끝에 이미 깐 레포가 할 일이 있으면 적는다. 원자료 사본에 다른 brief 구간이 든 팀 폴더는 검사가 1 로 끝난다.

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -2 && bash plugins/spec-distill/tests/test_conducting_loop.sh 2>&1 | tail -2 && bash plugins/spec-distill/tests/test_conducting_reference.sh 2>&1 | tail -2 && python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_human_lines.py && bash plugins/spec-distill/tests/test_repo_literals.sh 2>&1 | tail -2 && bash plugins/spec-distill/tests/test_plain_gate_templates.sh 2>&1 | tail -2`
Expected: 모두 통과한다. 이 문서들을 코퍼스로 읽는 락(계획 때 찾은 것)은 이렇다:
- `test_conducting_interview_stage.sh` · `test_decompose_surface.sh` · `test_end_gates.sh` · `test_entry_guidance.sh` · `test_epic_conductor_skill.sh` · `test_parallel_recommend_docs.sh` · `test_qg_review_reference.sh` · `test_review_handoff_order.sh` · `test_roadmap_status.sh` · `test_superpowers_presence.sh` · `test_team_files.py`
- `shared/tests/test_inline_python_isolated.sh` · `test_skill_reference_pointers.sh`

이것들도 이 과제 경계에서 돈다. 새 문장은 부재 락의 금지 글자를 쓰지 않는다 — 계획 때 본 것: `AskUserQuestion` · `${CLAUDE_PLUGIN_ROOT}` · `sdd-mirror` · `hc keys` · 「(R3)」 · 「이 판」. 「늘 싣는 것」 의 한 번 세는 글자(`` `TMPDIR` `` · `pathspec` · `` `git stash` ``)도 새 문장에 없다. team 틀의 `<…>` 자리표시도 늘지 않는다.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m "fix(spec-distill): 자기 승인 구멍을 드러내는 문장과 판 8.31.1" -m "Spec: docs/superpowers/specs/2026-11-22-qg-security-findings-design.md" -- plugins/spec-distill/references/conductor-dispatch.md plugins/spec-distill/references/conducting.md plugins/spec-distill/references/conductor-state-branch.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/tests/test_conductor_dispatch_reference.sh plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_conducting_loop.sh plugins/spec-distill/tests/test_conductor_state_branch_docs.py
```

---

### Task 7: 전체 스위트와 AC 대조 (AC7)

**Files:** 고치지 않는다(실패가 나오면 그 과제로 돌아간다).

- [ ] **Step 1: 잠금 아래 전체 스위트를 돌린다**

Run: `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner <이 agent 이름> --wait 1800 -- bash -c 'bash tools/suite/run-all.sh'`
Expected: 새 실패 0. worktree 에서만 나는 기존 실패(`TestCrossResolverAdvisory`)는 기준 브랜치에서도 나는지 견줘 보고한다. 잠금을 못 잡으면(3 · 75) 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다.

- [ ] **Step 2: AC 마다 한 줄로 대조한다**

| AC | 과제 | 근거 테스트 |
|---|---|---|
| AC1 | Task 2 | `AC1 위조 출처:` · `AC1 다른 brief:` · `test_source_problem` |
| AC2 | Task 3 | `AC2 다른 ref 의 위조:`(rc 3) · `AC2 다른 ref · 같은 바이트:`(알림) · `AC2 HEAD 의 조상:` |
| AC3 | Task 2 · 3 | `AC3 framing 있음:` · `AC3 framing 없음:` · 있는 `test_team_write.sh` 의 create · original 단언 · `sq2` |
| AC4 | Task 4 | `test_keys_outside_answers_are_checked` · `test_identifier_keys_pass_and_the_fixtures_are_clean` |
| AC5 | Task 5 | `test_own_rules_edit_is_listed_after_the_foreign_line` · `test_a_planted_own_row_moves_a_foreign_edit_into_the_own_list` |
| AC6 | Task 6 | 네 문서 락 · 옛 틀 바이트 락(한 구절 대치) |
| AC7 | Task 7 | 전체 스위트 · 위 「AC7 보고」 두 자리 |

AC 마다 `AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거` 한 줄로 보고한다.

---

### Task 8: 내 고침 목록이 보일 때까지 접기를 미룬다 (AC5 · 구현 물음 1 의 답)

마지막 전체 리뷰의 C1 · I2 · I3 에 대한 사용자 답(2026-11-23 · 설계문서 커밋 4cb47acc 에 반영)을 구현한다. 정본은 설계 §3 의 새 항목(「목록은 사용자에게 보일 때까지 남는다 …」)과 AC5 의 새 문장이다. 답 원문: 지휘 상태 폴더의 `relay/qg-sec/impl-answer-1.md`.

**Files:**
- Modify: `plugins/spec-distill/scripts/leader_seat.py`(`settle` 614행 근처 · `confirm` 582행 근처)
- Modify: `plugins/spec-distill/references/conducting.md`(74행 — 이미 넣은 줄에 문장을 잇는다, 줄 수는 그대로)
- Modify: `plugins/spec-distill/references/conductor-state-branch.md`(67행 한계 문장 · 줄마다 할 일 표의 새 행)
- Modify: `plugins/spec-distill/references/team-files.md`(235행 근처 「남는 것」 공시 — 둘째 줄 더하기)
- Modify: `plugins/spec-distill/CHANGELOG.md`(8.31.1 의 Security 줄 ③ · ①)
- Test: `plugins/spec-distill/tests/test_leader_seat.py` · `test_conductor_cross.py` · 문서 락(`test_conducting_loop.sh` · `test_conductor_state_branch_docs.py` · `test_team_docs.py` 가운데 그 문장을 재는 곳)

**Interfaces:**
- Consumes: Task 5 의 `TS.edits_since` · `TS.own_commits` · `TS.foreign_commits`(같은 범위 · 같은 감시 경로 `_watched(team)`) · `CS.OWN_EDITS`.
- `settle`: 지금 「남의 고침 0 이면 `확인한 끝` 절을 `확인 · <tip>` 한 줄로」 접는다. 이제 남의 고침이 0 이어도 확인한 끝 뒤에 감시 경로(규칙 사본 · `rules-base.md` · `pending.md`)를 바꾼 `씀` 커밋(내 고침 목록 — `씀` 병합 포함)이 있으면 접지 않고, 남의 고침이 남았을 때와 같이 범위(`<확인 끝>..<tip>`) 밖의 버려진 `씀` 줄만 지운다. 그런 커밋이 없으면 지금처럼 접는다. 반환값(남의 고침 수 | None)과 알림 글자는 그대로다. 기계 상태를 한 번 읽고 `edits_since` 를 한 번 재서 가른다. 내 고침을 재지 못하면(None) 접지 않는다(재지 못하면 건드리지 않는다는 지금 뜻과 같게).
- `confirm`(표시 없이): 남의 고침이 없고 내 고침 목록이 있으면 지금의 `NOTHING_TO_CONFIRM` 뒤에 있는 글자 `CONFIRM_TIP % seen`(「확인할 끝: <40자>」) 줄을 함께 낸다 — 종료 코드는 지금처럼 0. 새 글자를 만들지 않는다. 남의 고침이 있으면 지금 그대로(목록 + 「확인할 끝」, rc 1).
- `confirm --confirmed <끝>`: 지금 그대로 — 끝이 읽을 끝과 같으면 `확인 · <끝>` 한 줄로 기록한다(그 뒤에는 범위가 비어 내 고침 목록도 없다).
- `sync` 의 출력 글자는 바꾸지 않는다.

넣을 글(설계 §3 의 새 글을 따른다 — 글자는 구현자가 아래 뜻으로 짓고, 부재 락의 금지 글자를 쓰지 않는다):
- conducting.md 74행 끝에 잇는다: 보인 뒤 사용자가 머지를 정하면 `conductor_branch.py confirm --confirmed <확인할 끝>` 으로 확인한 끝을 기록한다 — 그 전에는 `sync` 가 그 목록을 접지 않는다. (`<SD>` 꼴의 경로 접두는 그 파일의 이웃 줄과 같게.)
- conductor-state-branch.md 67행: 한계를 `확인한 끝` 절의 줄 전체(`씀` · `확인`)로 넓힌다 — `씀` 줄은 막지 않고 드러내고, 직접 심은 `확인` 줄은 드러나지도 않는다 — 막는 장치는 E3. 그리고 감시 경로를 바꾼 `씀` 커밋이 있으면 `sync` 가 접지 않고 `confirm --confirmed <끝>` 으로만 접는다는 문장. 줄마다 할 일 표의 「이 기계가 쓴 것으로 적힌 고침 n」 행의 할 일에 「보인 뒤 `confirm --confirmed <확인할 끝>`」 을 잇는다.
- team-files.md 「남는 것」 공시 바로 뒤에 둘째 공시 한 줄: 같은 브랜치에서 인터뷰 결과물을 고쳤다 되돌린 커밋도 지나간다(HEAD 의 조상인 출처 커밋을 받기 때문) — PR 의 바뀐 파일 목록에는 나오지 않고 커밋별 보기에서만 보인다. squash 머지면 머지 뒤 기준과 견줘 검사 불가로 드러나고, 머지 커밋으로 머지하면 계속 지나간다.
- CHANGELOG 8.31.1 Security ③ 에 「감시 경로를 바꾼 `씀` 커밋이 있으면 `sync` 가 확인 기록을 접지 않고 `confirm --confirmed` 로만 접는다 · `확인` 줄을 직접 심는 길은 드러나지 않는다(E3)」 를, ① 에 「브랜치에서 결과물을 고쳤다 되돌린 커밋은 지나간다(공시)」 를 잇는다. 날짜 · 판은 그대로.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_conductor_cross.py` 의 `Show` 또는 `test_leader_seat.py` 의 settle 이웃)
  - `씀 을 심음 → sync → show:` 남의 규칙 고침 F 를 만들고 `CB.record_own(…, [F])` 로 심은 뒤 `CS.sync` 를 한 번 돌리면 `show` 에 `CS.OWN_EDITS % 1` 과 `F[:8] · <경로>` 줄이 남는다(지금은 사라진다 — 마지막 리뷰 실험 `exp_sync.py` 꼴).
  - `confirm --confirmed 뒤에는 없다:` 이어서 `LS.confirm(…)`(표시 없이)의 알림에 `LS.CONFIRM_TIP % seen` 이 있고, 그 끝으로 `LS.confirm(…, confirmed=seen)` 을 부른 뒤 `sync` → `show` 에 그 줄이 없고 `확인한 끝` 절이 한 줄이다.
  - `감시 경로 밖 씀 만이면 지금처럼 접힌다:` STATUS 만 쓴 `씀` 만 있을 때 `sync` 뒤 `확인한 끝` 절이 `확인 · <tip>` 한 줄이다(있는 `test_settle_compacts_when_clean` 이 이미 재면 그것을 가리키고 새로 더하지 않아도 된다).
  - `리더의 바른 규칙 고침도 남는다:` `CB.write(…)` 로 리더가 규칙 사본을 고친 뒤 `sync` → `show` 에 그 커밋 줄이 남는다.
  - 판정 변이: settle 의 새 갈래를 빼면 첫 단언과 넷째 단언이 빨개진다.
- [ ] **Step 2: 실패를 확인한다.**
- [ ] **Step 3: 구현한다** — Interfaces 대로. 그다음 넣을 글을 넣고, 그 문장을 재는 락에 본문 고유 단언을 더한다(conducting.md 74행의 새 구절 · conductor-state-branch.md 의 `확인` 줄 한계 · team-files.md 의 둘째 공시).
- [ ] **Step 4: 통과를 확인한다** — `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_walk_docs.py` · `bash plugins/spec-distill/tests/test_leader_seat_e2e.sh` · `test_conducting_loop.sh` · `test_conductor_state_branch_e2e.sh` · `test_team_status.sh` 와 바꾼 파일을 코퍼스로 읽는 락. 있는 테스트의 기대가 바뀌는 자리(「`sync` 뒤 확인한 끝이 한 줄」 을 재던 단언이 감시 경로를 바꾼 `씀` 을 쓰는 픽스처였던 곳)는 고치고 그 자리를 보고한다.
- [ ] **Step 5: 커밋한다** — pathspec · 트레일러 두 줄(`Spec: …` · `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`). 전체 스위트는 돌리지 않는다.

끝나면 마지막 전체 리뷰를 새로 고친 범위(앞 리뷰 뒤의 커밋 — ff2230ca 뒤)만 좁게 한 번 다시 받는다 — AC5 와 「고친 검사를 여전히 지나가는 길이 있는가」 를 다시 묻는다.
