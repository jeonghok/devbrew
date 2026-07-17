#!/usr/bin/env bash
# T4/AC9/AC19/AC7(6b) — change-signal (pre-commit) + atomic single-path commit.
set -u
SCRIPTS="$(cd "$(dirname "$0")/../scripts" && pwd)"
SIG="$SCRIPTS/artifact_change_signal.sh"; COMMIT="$SCRIPTS/artifact_commit.sh"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

mkrepo() { local d; d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t
  git config user.name t; echo "v0" > doc.md; echo "other0" > other.md
  git add doc.md other.md; git commit -q -m init; git branch -m feature/x ); echo "$d"; }

# change-signal: unchanged -> false; modified -> true (BEFORE commit)
d="$(mkrepo)"
[ "$(cd "$d" && bash "$SIG" doc.md | sed -n 's/^changed: //p')" = "false" ] && ok "signal clean=false" || no "signal clean should be false"
( cd "$d"; echo "v1" >> doc.md )
[ "$(cd "$d" && bash "$SIG" doc.md | sed -n 's/^changed: //p')" = "true" ] && ok "signal dirty=true" || no "signal dirty should be true"
rm -rf "$d"

# whole-branch review fix: tracked/untracked detection (E2b must reject an
# untracked target -- `git diff --quiet HEAD` never sees an untracked path, so
# without this, an untracked file misreads as "clean" and silently no-ops).
d="$(mkrepo)"
[ "$(cd "$d" && bash "$SIG" doc.md | sed -n 's/^tracked: //p')" = "true" ] && ok "signal tracked=true for a committed file" || no "signal should report tracked=true for a committed file"
( cd "$d"; echo "new" > untracked.md )  # NOT git-added -- wholly untracked
out="$(cd "$d" && bash "$SIG" untracked.md)"
echo "$out" | grep -q "^tracked: false" && ok "signal tracked=false for an untracked file" || no "signal should report tracked=false for an untracked file ($out)"
echo "$out" | grep -q "^changed: false" && ok "untracked file also reads changed=false (git diff blind to it -- why tracked: is needed)" || no "untracked file changed line unexpected ($out)"
rm -rf "$d"

# atomicity: unrelated STAGED change must NOT be swept into the commit
d="$(mkrepo)"
( cd "$d"; echo "v1" >> doc.md; echo "other1" >> other.md; git add other.md )  # other.md staged, unrelated
out="$(cd "$d" && bash "$COMMIT" doc.md "critique(round 1): x")"
sha="$(echo "$out" | sed -n 's/^committed_sha: //p')"
[ -n "$sha" ] && ok "commit returns sha" || no "commit should return sha ($out)"
# HEAD commit touches ONLY doc.md
files="$(cd "$d" && git show --name-only --format= HEAD | tr '\n' ' ')"
echo "$files" | grep -q "doc.md" && ! echo "$files" | grep -q "other.md" \
  && ok "commit scoped to doc.md only (other.md excluded)" || no "commit swept unrelated file ($files)"
# other.md still has uncommitted (staged) change
( cd "$d" && ! git diff --quiet HEAD -- other.md ) && ok "other.md change preserved uncommitted" || no "other.md change lost"
rm -rf "$d"

# no-op: nothing to commit -> no_op
d="$(mkrepo)"
out="$(cd "$d" && bash "$COMMIT" doc.md "msg")"
echo "$out" | grep -q "^no_op: true" && ok "no-op reported" || no "no-op should be reported ($out)"
rm -rf "$d"

# no `git add -A` anywhere in either script (C5 grep lock)
grep -qE 'git[[:space:]]+add[[:space:]]+-A' "$COMMIT" "$SIG" && no "git add -A present (forbidden)" || ok "no git add -A"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
