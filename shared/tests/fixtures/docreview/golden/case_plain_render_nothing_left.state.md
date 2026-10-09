---
docreview:
  doc: <REPO_ROOT>/shared/tests/fixtures/docreview/design-sample.md
  profile: <REPO_ROOT>/plugins/spec-distill/references/docreview-profiles/design-doc.md
  round: 1
  rereview_count: 0
  extra_rounds: []
  snapshots:
    '1':
      headingless: false
      sections:
      - anchor: '#__preamble__'
        title: (머리말)
        level: 0
        hash: 2a070ec95b1f
        parents: []
      - anchor: '#1-context'
        title: 1. Context
        level: 2
        hash: e8f290498d99
        parents: []
      - anchor: '#2-goals'
        title: 2. Goals
        level: 2
        hash: c6e0614eb576
        parents: []
      - anchor: '#3-non-goals'
        title: 3. Non-goals
        level: 2
        hash: b1c76687a3f4
        parents: []
      - anchor: '#5-architecture'
        title: 5. Architecture
        level: 2
        hash: 399439c847c6
        parents: []
      - anchor: '#51-parts'
        title: 5.1 Parts
        level: 3
        hash: aac5fb6c114b
        parents:
        - '#5-architecture'
      - anchor: '#11-acceptance-criteria'
        title: 11. Acceptance Criteria
        level: 2
        hash: 30445edc0450
        parents: []
      - anchor: '#12-files-to-modify'
        title: 12. Files to Modify
        level: 2
        hash: 62a715899d27
        parents: []
      - anchor: '#handoff-context'
        title: Handoff Context
        level: 2
        hash: 69f1685cd548
        parents: []
      - anchor: '#deferred-to-plan'
        title: Deferred to plan
        level: 3
        hash: 36a209eba25b
        parents:
        - '#handoff-context'
  findings: {}
  decides: {}
  fixes: {}
  asks: {}
  permits: {}
  applied_scopes: []
  decision_log: []
  rounds:
    '1':
      open_lineages: []
      progress: 0
      route_report:
        degrade:
          critic_dead: false
          layer2_missing: false
          codex_absent: false
          codex_reason: null
          recritic_dead: null
        advisory: []
        rejected: 0
        bucket_conflicts: 0
        revived: 0
        lineage_mismatch: 0
        reraise_unconsumed: 0
        escalated_unconsumed: 0
      started_mtime_ns: <MTIME_NS>
  pending_recritic: null
  rejected_lineages: {}
  escalated: []
  reraise: []
---
# docreview 원장
- r0: init
- r1: begin-round (rereview_count=0)
- r1: prepare-recritic (0 items)
- r1: finalize (0 findings, 0 rejected)
