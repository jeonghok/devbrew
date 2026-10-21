#!/usr/bin/env bash
# skill 이 부르는 스크립트의 상태 폴더 쓰기가 마지막 성분의 링크를 따라가지 않는지 실행으로 잰다.
#   · seed_edit_diff.py — 기준 사본 · .shown · .reverted
#   · docreview_state.py — 원장(링크면 거절 · 제자리 덮어쓰기는 유지) · 시대 표지
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SED="$ROOT/plugins/spec-distill/scripts/seed_edit_diff.py"
DS="$ROOT/shared/docreview/scripts/docreview_state.py"
ANCHOR="$ROOT/plugins/spec-distill/scripts/docreview_anchor.py"
PROFILE="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
DOC="$ROOT/shared/tests/fixtures/docreview/design-sample.md"
T="$(mktemp -d -t sd-state-writes-XXXXXX)" || exit 1
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT

mk_case() {   # mk_case <이름> → $T/<이름>/{work,out,state}, work/seed.md
  mkdir -p "$T/$1/work" "$T/$1/out" "$T/$1/state"
  printf 'alpha\nbeta\ngamma\n' > "$T/$1/work/seed.md"
}
sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
plain() { [ -f "$1" ] && [ ! -L "$1" ]; }
ds_init() { python3 "$DS" init --state-dir "$1" --doc "$DOC" --profile "$PROFILE"; }

# ── seed_edit_diff ───────────────────────────────────────────────────────
mk_case sed_init_dangling_base; c="$T/sed_init_dangling_base"
ln -s "$c/out/new-target" "$c/work/base.md"
python3 "$SED" init "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
if [ -e "$c/out/new-target" ] || [ -L "$c/out/new-target" ]; then no "sed_init_dangling_base: 바깥 경로가 생겼다"; else ok "sed_init_dangling_base: 바깥 경로가 생기지 않았다"; fi
if plain "$c/work/base.md" && cmp -s "$c/work/base.md" "$c/work/seed.md"; then ok "sed_init_dangling_base: 기준 사본은 seed 와 같은 일반 파일"; else no "sed_init_dangling_base: 기준 사본이 일반 파일이 아니거나 seed 와 다르다"; fi

mk_case sed_accept_base_link; c="$T/sed_accept_base_link"
printf 'outside\n' > "$c/out/o.txt"
printf 'old\n' > "$c/work/old.md"
python3 "$SED" init "$c/work/base.md" "$c/work/old.md" >/dev/null 2>&1
python3 "$SED" hunks "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
rm -f "$c/work/base.md"; ln -s "$c/out/o.txt" "$c/work/base.md"
python3 "$SED" accept "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
assert_eq "$(cat "$c/out/o.txt")" "outside" "sed_accept_base_link: 바깥 파일 그대로"
if plain "$c/work/base.md" && cmp -s "$c/work/base.md" "$c/work/seed.md"; then ok "sed_accept_base_link: 기준 사본은 일반 파일"; else no "sed_accept_base_link: 기준 사본이 일반 파일이 아니다"; fi

mk_case sed_hunks_shown_link; c="$T/sed_hunks_shown_link"
printf 'outside\n' > "$c/out/o.txt"
printf 'alpha\n' > "$c/work/b0.md"
python3 "$SED" init "$c/work/base.md" "$c/work/b0.md" >/dev/null 2>&1
ln -s "$c/out/o.txt" "$c/work/base.md.shown"
python3 "$SED" hunks "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
assert_eq "$(cat "$c/out/o.txt")" "outside" "sed_hunks_shown_link: 바깥 파일 그대로"
if plain "$c/work/base.md.shown"; then assert_eq "$(cat "$c/work/base.md.shown")" "$(sha_of "$c/work/seed.md")" "sed_hunks_shown_link: .shown 은 해시를 담은 일반 파일"; else no "sed_hunks_shown_link: .shown 이 일반 파일이 아니다"; fi

mk_case sed_revert_markers_link; c="$T/sed_revert_markers_link"
printf 'alpha\nbeta\n' > "$c/work/b0.md"
python3 "$SED" init "$c/work/base.md" "$c/work/b0.md" >/dev/null 2>&1
printf '%s' "$(sha_of "$c/work/seed.md")" > "$c/out/o1.txt"   # .shown 이 읽힐 때 맞는 해시를 담은 바깥 파일
cp "$c/out/o1.txt" "$c/out/o1.keep"
ln -s "$c/out/o1.txt" "$c/work/base.md.shown"
ln -s "$c/out/o2.txt" "$c/work/base.md.reverted"
python3 "$SED" revert "$c/work/base.md" "$c/work/seed.md" --ids 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "sed_revert_markers_link: revert 성공"
if cmp -s "$c/out/o1.txt" "$c/out/o1.keep"; then ok "sed_revert_markers_link: .shown 바깥 파일 그대로"; else no "sed_revert_markers_link: .shown 바깥 파일이 바뀌었다"; fi
if [ -e "$c/out/o2.txt" ] || [ -L "$c/out/o2.txt" ]; then no "sed_revert_markers_link: .reverted 바깥 경로가 생겼다"; else ok "sed_revert_markers_link: .reverted 바깥 경로가 생기지 않았다"; fi

# ── docreview_state ──────────────────────────────────────────────────────
mk_case ds_save_symlink_refused; c="$T/ds_save_symlink_refused"
printf 'outside\n' > "$c/out/o.txt"
ln -s "$c/out/nope" "$c/state/docreview-state.md"
err="$(ds_init "$c/state" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_symlink_refused: 끊어진 링크 원장은 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_symlink_refused: 사유"
if [ -e "$c/out/nope" ] || [ -L "$c/out/nope" ]; then no "ds_save_symlink_refused: 바깥 경로가 생겼다"; else ok "ds_save_symlink_refused: 바깥 경로가 생기지 않았다"; fi
# 살아 있는 링크 — 저장하는 명령(begin-round)
mkdir -p "$c/state2" "$c/state0"
ds_init "$c/state0" >/dev/null 2>&1
cp "$c/state0/docreview-state.md" "$c/out/o.txt"
ln -s "$c/out/o.txt" "$c/state2/docreview-state.md"
python3 "$ANCHOR" snapshot "$DOC" > "$c/s1.json"
before="$(cat "$c/out/o.txt")"
err="$(python3 "$DS" begin-round --state-dir "$c/state2" --snapshot "$c/s1.json" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_symlink_refused: 살아 있는 링크 원장도 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_symlink_refused: 살아 있는 링크 사유"
assert_eq "$(cat "$c/out/o.txt")" "$before" "ds_save_symlink_refused: 바깥 파일 그대로"

mk_case ds_save_hardlink_refused; c="$T/ds_save_hardlink_refused"
mkdir -p "$c/state0"
ds_init "$c/state0" >/dev/null 2>&1
cp "$c/state0/docreview-state.md" "$c/out/o.txt"
ln "$c/out/o.txt" "$c/state/docreview-state.md"
python3 "$ANCHOR" snapshot "$DOC" > "$c/s1.json"
before="$(cat "$c/out/o.txt")"
err="$(python3 "$DS" begin-round --state-dir "$c/state" --snapshot "$c/s1.json" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_hardlink_refused: 하드 링크 원장은 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_hardlink_refused: 사유"
assert_eq "$(cat "$c/out/o.txt")" "$before" "ds_save_hardlink_refused: 다른 이름의 파일 그대로"

mk_case ds_era_link_not_followed; c="$T/ds_era_link_not_followed"
ln -s "$c/out/new-target" "$c/state/docreview-digest-era"
ds_init "$c/state" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "ds_era_link_not_followed: 원장은 저장된다"
if [ -e "$c/out/new-target" ] || [ -L "$c/out/new-target" ]; then no "ds_era_link_not_followed: 바깥 경로가 생겼다"; else ok "ds_era_link_not_followed: 바깥 경로가 생기지 않았다"; fi

mk_case ds_inplace_ro_dir_kept; c="$T/ds_inplace_ro_dir_kept"
ds_init "$c/state" >/dev/null 2>&1
python3 "$ANCHOR" snapshot "$DOC" > "$c/s1.json"
chmod 555 "$c/state"
python3 "$DS" begin-round --state-dir "$c/state" --snapshot "$c/s1.json" >/dev/null 2>&1; rc=$?
chmod 755 "$c/state"
assert_eq "$rc" "0" "ds_inplace_ro_dir_kept: 쓰기 불가 폴더 안 원장도 갱신된다"
assert_contains "$(cat "$c/state/docreview-state.md")" "round: 1" "ds_inplace_ro_dir_kept: 라운드가 올랐다"

finish
