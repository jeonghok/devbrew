#!/usr/bin/env bash
# T5/AC6/AC16/AC20 — artifact synthesizer: key(dedup) + synth(verdict/kept/converge/degrade).
set -u
S="plugins/quality-gates/scripts/synthesize_artifact_findings.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
tmp="$(mktemp -d)"

# --- key phase: within-round dedup (critic + codex same anchor/category/summary -> 1) ---
cat > "$tmp/critic.yaml" <<'Y'
findings:
  - {agent: artifact-critic, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", proposed_fix: "fix A"}
Y
cat > "$tmp/codex.yaml" <<'Y'
findings:
  - {agent: codex-reviewer, category: logic, target_anchor: "#s1", severity: CRITICAL, summary: "gap A", proposed_fix: "fix A2"}
  - {agent: codex-reviewer, category: ambiguity, target_anchor: "#s2", severity: IMPORTANT, summary: "amb B", proposed_fix: "fix B"}
Y
python3 "$S" --phase key --findings "$tmp/critic.yaml" --findings "$tmp/codex.yaml" > "$tmp/merged.yaml"
n="$(python3 -c "import yaml;print(len(yaml.safe_load(open('$tmp/merged.yaml'))['findings']))")"
[ "$n" = "2" ] && ok "key dedup merges duplicate anchor+cat+summary (2 unique)" || no "key dedup wrong count: $n"
# each finding carries a dedup_key
python3 -c "import yaml;fs=yaml.safe_load(open('$tmp/merged.yaml'))['findings'];assert all(f.get('dedup_key') for f in fs)" \
  && ok "key phase injects dedup_key" || no "dedup_key missing"

# capture the #s1 finding's dedup_key for verdict targeting
K1="$(python3 -c "import yaml;fs=yaml.safe_load(open('$tmp/merged.yaml'))['findings'];print([f['dedup_key'] for f in fs if f['target_anchor']=='#s1'][0])")"
K2="$(python3 -c "import yaml;fs=yaml.safe_load(open('$tmp/merged.yaml'))['findings'];print([f['dedup_key'] for f in fs if f['target_anchor']=='#s2'][0])")"

# --- synth: confirm #s1 (CRITICAL kept), reject #s2 -> kept_critical=1, not converged ---
cat > "$tmp/adv1.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: confirm, evidence: real}
  - {finding_key: "$K2", verdict: reject, evidence: fp}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv1.yaml")"
echo "$out" | grep -q "kept_critical: 1" && ok "confirm keeps CRITICAL" || no "confirm should keep CRITICAL ($out)"
echo "$out" | grep -q "converged: false" && ok "not converged with CRITICAL kept" || no "should not converge ($out)"

# --- synth: all reject -> converged true ---
cat > "$tmp/adv2.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: reject, evidence: fp}
  - {finding_key: "$K2", verdict: reject, evidence: fp}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv2.yaml")"
echo "$out" | grep -q "converged: true" && ok "all-reject converges" || no "all-reject should converge ($out)"

# --- un-adjudicated fail-closed: only #s1 judged -> #s2 kept-excluded, unadjudicated=1 ---
cat > "$tmp/adv3.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: confirm, evidence: real}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv3.yaml")"
echo "$out" | grep -q "unadjudicated: 1" && ok "un-adjudicated counted" || no "unadjudicated should be 1 ($out)"

# --- whole-branch review fix: un-adjudicated CRITICAL must NOT false-converge ---
# Only #s2 (IMPORTANT) is judged here; #s1 (CRITICAL, K1) is left entirely
# un-adjudicated. kept excludes #s1 (fail-closed) so kept_critical=0, and verdicts
# is non-empty so NOT degraded -- the pre-fix formula (converged = not degraded and
# crit+imp==0) read this as converged:true (false-clean over a CRITICAL that was
# never adjudicated or fixed, and not even surfaced as residual).
cat > "$tmp/adv_partial_crit.yaml" <<Y
verdicts:
  - {finding_key: "$K2", verdict: reject, evidence: fp}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv_partial_crit.yaml")"
echo "$out" | grep -q "converged: false" && echo "$out" | grep -q "unadjudicated: 1" \
  && ok "un-adjudicated CRITICAL blocks false-convergence" || no "un-adjudicated CRITICAL must not converge ($out)"

# --- downgrade needs new_severity: CRITICAL -> SUGGESTION drops out of crit/imp ---
cat > "$tmp/adv4.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: downgrade, new_severity: SUGGESTION, evidence: overstated}
  - {finding_key: "$K2", verdict: reject, evidence: fp}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv4.yaml")"
echo "$out" | grep -q "kept_critical: 0" && echo "$out" | grep -q "kept_suggestion: 1" \
  && ok "downgrade applies new_severity" || no "downgrade new_severity not applied ($out)"

# --- degraded-adversarial: findings existed but 0 verdicts -> degraded, NOT converged ---
cat > "$tmp/adv_empty.yaml" <<'Y'
verdicts: []
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && echo "$out" | grep -q "degraded_reason: adversarial" \
  && ok "degraded adversarial blocks false-convergence" || no "degraded guard failed ($out)"

# --- genuine clean: NO findings + empty verdicts -> converged, NOT degraded ---
cat > "$tmp/none.yaml" <<'Y'
findings: []
Y
python3 "$S" --phase key --findings "$tmp/none.yaml" > "$tmp/none_merged.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "converged: true" && echo "$out" | grep -q "degraded: false" \
  && echo "$out" | grep -q "degraded_reason: none" \
  && ok "empty findings = genuine clean (not degraded)" || no "empty findings misread ($out)"

# --- T5-Important fix: findings-load fail-closed (missing --findings file) ---
out="$(python3 "$S" --phase synth --findings "$tmp/does_not_exist.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && echo "$out" | grep -q "degraded_reason: findings_load" \
  && ok "missing --findings file forces degraded (fail-closed)" || no "missing findings file should force degraded ($out)"

# --- T5-Important fix: findings-load fail-closed (unparseable YAML) ---
printf ': : : bad yaml\n' > "$tmp/bad.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/bad.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && echo "$out" | grep -q "degraded_reason: findings_load" \
  && ok "unparseable --findings file forces degraded (fail-closed)" || no "unparseable findings file should force degraded ($out)"

# --- T5-Important fix: key phase counts a failed source instead of silently skipping it ---
python3 "$S" --phase key --findings "$tmp/critic.yaml" --findings "$tmp/does_not_exist.yaml" > "$tmp/partial_merged.yaml"
python3 -c "
import yaml
d = yaml.safe_load(open('$tmp/partial_merged.yaml'))
assert d.get('sources_failed') == 1, ('sources_failed', d.get('sources_failed'))
assert len(d['findings']) == 1, ('findings', d['findings'])
assert d['findings'][0]['target_anchor'] == '#s1', d['findings'][0]
" && ok "key phase counts failed source + keeps loadable finding" || no "key phase sources_failed / partial findings wrong"

# --- T5-Important fix: synth on a merged doc carrying sources_failed>0 -> degraded ---
cat > "$tmp/merged_with_failure.yaml" <<'Y'
findings: []
sources_failed: 1
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged_with_failure.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && echo "$out" | grep -q "degraded_reason: sources_failed" \
  && ok "sources_failed>0 on merged doc forces degraded (fail-closed)" || no "sources_failed>0 should force degraded ($out)"

# --- new_findings from adversarial added to kept ---
cat > "$tmp/adv5.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: reject, evidence: fp}
  - {finding_key: "$K2", verdict: reject, evidence: fp}
new_findings:
  - {agent: artifact-adversarial, category: completeness, target_anchor: "#s9", severity: IMPORTANT, summary: "missed C"}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv5.yaml")"
echo "$out" | grep -q "kept_important: 1" && ok "adversarial new_findings kept" || no "new_findings not kept ($out)"

# --- stagnation_key is summary-independent (across-round stability) ---
K1S="$(python3 -c "import yaml,hashlib
def n(s):return ' '.join(str(s).strip().lower().split())
raw=n('logic')+chr(0)+n('#s1');print(hashlib.sha1(raw.encode()).hexdigest()[:12])")"
python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv1.yaml" | grep -q "$K1S" \
  && ok "stagnation_keys summary-independent" || no "stagnation_key mismatch (want $K1S)"

# ============================================================================
# Review-gate self-dogfood (iter-1 Retry) fail-closed hardening.
# ============================================================================

# --- F-A: an empty/degenerate merged file must degrade, not read as converged ---
# A 0-byte merged.yaml -> yaml.safe_load == None is a LOAD failure, not a genuine
# zero-findings round. Mutation proof: reverting phase_synth's guard to
# `merged_doc == "__ERR__"` reddens this (None != "__ERR__" -> converged:true).
: > "$tmp/empty_merged.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/empty_merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && echo "$out" | grep -q "degraded_reason: findings_load" \
  && ok "empty merged file forces degraded (fail-closed, not false-clean)" || no "empty merged file must degrade ($out)"

# --- F-A: a null/scalar merged doc must degrade too ---
printf 'null\n' > "$tmp/null_merged.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/null_merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "degraded_reason: findings_load" \
  && ok "null/scalar merged doc forces degraded (fail-closed)" || no "null merged doc must degrade ($out)"

# --- F-A: phase_key counts a wrong-schema source (dict w/o findings list) ---
# A source that loads but lacks a findings list (a stray `codex_failed: true` doc,
# or reviewer prose parsed to a scalar) must increment sources_failed, NOT be read
# as zero findings. Mutation proof: reverting the phase_key guard to
# `doc == "__ERR__"` reddens this (wrong-schema doc -> sources_failed:0).
printf 'codex_failed: true\nreason: boom\n' > "$tmp/wrongschema.yaml"
python3 "$S" --phase key --findings "$tmp/critic.yaml" --findings "$tmp/wrongschema.yaml" > "$tmp/ws_merged.yaml"
python3 -c "
import yaml
d = yaml.safe_load(open('$tmp/ws_merged.yaml'))
assert d.get('sources_failed') == 1, ('sources_failed', d.get('sources_failed'))
assert len(d['findings']) == 1, ('findings', d['findings'])
" && ok "key phase counts a wrong-schema source (no silent 0-findings)" || no "wrong-schema source must count as sources_failed"

# --- F-B: an off-vocabulary severity fails CLOSED to CRITICAL (blocks convergence) ---
# A reviewer emitting `severity: BLOCKER` (or a typo, or omitting it) must NOT be
# demoted to the non-blocking SUGGESTION. Mutation proof: reverting _norm_sev's
# fallback to "SUGGESTION" reddens this (kept_critical:0 -> converged:true).
cat > "$tmp/offvocab.yaml" <<'Y'
findings:
  - {agent: artifact-critic, category: logic, target_anchor: "#z1", severity: BLOCKER, summary: "grave gap", proposed_fix: "fix"}
Y
python3 "$S" --phase key --findings "$tmp/offvocab.yaml" > "$tmp/ov_merged.yaml"
KOV="$(python3 -c "import yaml;fs=yaml.safe_load(open('$tmp/ov_merged.yaml'))['findings'];print(fs[0]['dedup_key'])")"
cat > "$tmp/adv_ov.yaml" <<Y
verdicts:
  - {finding_key: "$KOV", verdict: confirm, evidence: real}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/ov_merged.yaml" --adversarial "$tmp/adv_ov.yaml")"
echo "$out" | grep -q "kept_critical: 1" && echo "$out" | grep -q "converged: false" \
  && ok "off-vocab severity fails closed to CRITICAL (blocks convergence)" || no "off-vocab severity must block ($out)"

# --- F-I: downgrade WITHOUT new_severity keeps the original severity (fail-closed) ---
# The code keeps the original severity when new_severity is missing/off-vocab; this
# gives that previously-untested branch teeth. Mutation proof: changing that
# fallback to `continue` (drop the finding) reddens this (kept_critical:1 -> 0,
# converged:false -> true) = a dropped-CRITICAL false-convergence.
cat > "$tmp/adv_dg_nosev.yaml" <<Y
verdicts:
  - {finding_key: "$K1", verdict: downgrade, evidence: overstated}
  - {finding_key: "$K2", verdict: reject, evidence: fp}
Y
out="$(python3 "$S" --phase synth --findings "$tmp/merged.yaml" --adversarial "$tmp/adv_dg_nosev.yaml")"
echo "$out" | grep -q "kept_critical: 1" && echo "$out" | grep -q "converged: false" \
  && ok "downgrade w/o new_severity keeps CRITICAL (fail-closed)" || no "downgrade w/o new_severity must keep CRITICAL ($out)"

# ============================================================================
# iter-2 re-review (fixes to the fixes): further fail-closed hardening.
# ============================================================================

# --- F-A/iter2: synth invoked with NO --findings at all must degrade (not clean) ---
# Mutation proof: reverting to `bool(findings_path) and not _is_findings_doc(...)`
# lets an empty findings_path read as converged:true.
out="$(python3 "$S" --phase synth --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && ok "synth with no --findings degrades (fail-closed)" || no "no --findings must degrade ($out)"

# --- F-A/iter2: a non-mapping finding ENTRY counts as a source failure ---
# `findings: ["bare string"]` passes _is_findings_doc (list present) but the entry is
# not a mapping; it must count as sources_failed, not be silently skipped.
cat > "$tmp/garbled_src.yaml" <<'Y'
findings:
  - "this is a bare string, not a mapping"
Y
python3 "$S" --phase key --findings "$tmp/critic.yaml" --findings "$tmp/garbled_src.yaml" > "$tmp/g_merged.yaml"
python3 -c "
import yaml
d = yaml.safe_load(open('$tmp/g_merged.yaml'))
assert d.get('sources_failed') == 1, ('sources_failed', d.get('sources_failed'))
" && ok "malformed non-mapping finding entry -> sources_failed (no silent skip)" || no "non-mapping finding must count as sources_failed"

# --- F-A/iter2: a non-int sources_failed on the merged doc forces degraded ---
cat > "$tmp/badsf.yaml" <<'Y'
findings: []
sources_failed: unknown
Y
out="$(python3 "$S" --phase synth --findings "$tmp/badsf.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && ok "non-int sources_failed on merged doc forces degraded (fail-closed)" || no "non-int sources_failed must degrade ($out)"

# --- F-B/iter2: dedup keeps the STRICTEST severity across sources (not first-wins) ---
# critic (processed first) emits SUGGESTION; codex emits the SAME dedup key with
# CRITICAL. The merged finding must carry CRITICAL, so a later confirm can't leave
# only a non-blocking SUGGESTION. Mutation proof: dropping the strictest-severity
# merge leaves the first-wins SUGGESTION -> RED.
cat > "$tmp/critic_low.yaml" <<'Y'
findings:
  - {agent: artifact-critic, category: logic, target_anchor: "#d1", severity: SUGGESTION, summary: "dup gap", proposed_fix: "x"}
Y
cat > "$tmp/codex_high.yaml" <<'Y'
findings:
  - {agent: codex-reviewer, category: logic, target_anchor: "#d1", severity: CRITICAL, summary: "dup gap", proposed_fix: "x2"}
Y
python3 "$S" --phase key --findings "$tmp/critic_low.yaml" --findings "$tmp/codex_high.yaml" > "$tmp/dup_merged.yaml"
sev="$(python3 -c "import yaml;fs=yaml.safe_load(open('$tmp/dup_merged.yaml'))['findings'];print(fs[0]['severity'])")"
[ "$sev" = "CRITICAL" ] && ok "dedup keeps strictest severity (SUGGESTION+CRITICAL -> CRITICAL)" || no "dedup must keep strictest severity (got $sev)"

# ============================================================================
# iter-3 convergence check (codex): adversarial schema fail-closed.
# ============================================================================

# --- CX3-1: malformed adversarial new_findings (a MAPPING, not a list) with NO prior
# findings must degrade, not silently drop + converge. Mutation proof: reverting the
# schema guard (coerce non-list -> []) reads the dropped malformed new_finding as clean.
cat > "$tmp/nf_map.yaml" <<'Y'
verdicts: []
new_findings:
  agent: artifact-adversarial
  severity: IMPORTANT
  summary: "missed issue emitted as a single mapping, not a list"
Y
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/nf_map.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && ok "malformed adversarial new_findings (mapping) degrades (fail-closed)" || no "malformed new_findings must degrade ($out)"

# --- CX3-1: a non-mapping adversarial doc (bare scalar) must degrade too ---
printf 'just a bare string\n' > "$tmp/adv_scalar.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/adv_scalar.yaml")"
echo "$out" | grep -q "degraded: true" && ok "non-mapping adversarial doc degrades (fail-closed)" || no "scalar adversarial doc must degrade ($out)"

# --- regression guard: a genuine no-findings round with a WELL-FORMED empty verdicts
# list must STILL converge (the schema guard must not over-degrade the happy path) ---
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "converged: true" && echo "$out" | grep -q "degraded: false" \
  && ok "well-formed empty verdicts + no findings still converges (no over-degrade)" || no "genuine clean must still converge ($out)"

# --- CX4 (final convergence): a non-mapping ELEMENT inside a valid new_findings LIST
# must degrade, not be silently skipped + converged (the list is well-shaped but an
# entry is a bare scalar). Mutation proof: removing the element-mapping check reads
# the dropped scalar new_finding as clean.
cat > "$tmp/nf_scalar.yaml" <<'Y'
verdicts: []
new_findings:
  - "IMPORTANT: rollback behavior unspecified (emitted as a bare scalar, not a mapping)"
Y
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/nf_scalar.yaml")"
echo "$out" | grep -q "degraded: true" && echo "$out" | grep -q "converged: false" \
  && ok "non-mapping new_findings ELEMENT degrades (fail-closed)" || no "scalar new_findings element must degrade ($out)"

note "── 처분 회계 (T1-B)"
# kept finding 은 리터럴 dedup_key 를 빼서 :151 의 setdefault 가 내용(category+target_anchor+
# summary)에서 해시를 만들게 한다. :234(new_findings)는 echo 된 dedup_key 를 신뢰하지 않고
# 항상 그 셋을 재계산하므로, 아래 new_findings 항목이 같은 target_anchor/summary(카테고리
# 없음도 동일)를 가져야 «내용으로» 충돌해 실제 absorbed 흡수가 일어난다 — 수정 라운드 1
# (판정 ①): 리터럴 dedup_key 로 맞추려던 원래 fixture 는 :234 의 방어적 재계산과 만나
# 절대 충돌하지 않았다.
AKEY="$(python3 -c "import hashlib
def n(s):return ' '.join(str(s).strip().lower().split())
raw=''+chr(0)+n('#a')+chr(0)+n('kept');print(hashlib.sha1(raw.encode()).hexdigest()[:12])")"
cat > "$tmp/afind.yaml" <<YAML
findings:
  - {agent: critic, target_anchor: "#a", severity: CRITICAL, summary: kept}
  - {agent: critic, target_anchor: "#b", severity: IMPORTANT, summary: rejected, dedup_key: k2}
  - {agent: critic, target_anchor: "#c", severity: IMPORTANT, summary: 판정없음, dedup_key: k3}
sources_failed: 1
YAML
cat > "$tmp/aadv.yaml" <<YAML
verdicts:
  - {finding_key: "$AKEY", verdict: confirm}
  - {finding_key: k2, verdict: reject}
new_findings:
  - "형태 불량"
  - {agent: adv, target_anchor: "#a", severity: IMPORTANT, summary: kept}  # category(없음)+target_anchor+summary 가 위 kept finding 과 같아 해시 충돌 -> absorbed
YAML
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$S" --phase synth \
        --findings "$tmp/afind.yaml" --adversarial "$tmp/aadv.yaml" 2>&1)"
assert_grep "$OUT" 'rejected: *[1-9]'  "기각이 원장에 실린다"
assert_grep "$OUT" 'held: *[1-9]'      "판정자 부재가 원장에 실린다"
assert_grep "$OUT" 'absorbed: *[1-9]'  "kept_keys 중복 흡수가 세어진다"
assert_grep "$OUT" 'sources_failed: *[1-9]' "입력 실패가 원장에 실린다"

rm -rf "$tmp"
finish
