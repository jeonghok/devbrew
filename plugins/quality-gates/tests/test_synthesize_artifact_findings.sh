#!/usr/bin/env bash
# T5/AC6/AC16/AC20 — artifact synthesizer: key(dedup) + synth(verdict/kept/converge/degrade).
set -u
S="plugins/quality-gates/scripts/synthesize_artifact_findings.py"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
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
  && ok "degraded adversarial blocks false-convergence" || no "degraded guard failed ($out)"

# --- genuine clean: NO findings + empty verdicts -> converged, NOT degraded ---
cat > "$tmp/none.yaml" <<'Y'
findings: []
Y
python3 "$S" --phase key --findings "$tmp/none.yaml" > "$tmp/none_merged.yaml"
out="$(python3 "$S" --phase synth --findings "$tmp/none_merged.yaml" --adversarial "$tmp/adv_empty.yaml")"
echo "$out" | grep -q "converged: true" && echo "$out" | grep -q "degraded: false" \
  && ok "empty findings = genuine clean (not degraded)" || no "empty findings misread ($out)"

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

rm -rf "$tmp"
echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
