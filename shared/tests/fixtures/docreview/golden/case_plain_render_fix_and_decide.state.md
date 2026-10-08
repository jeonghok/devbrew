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
  findings:
    7c1226fa#r1.1:
      id: 7c1226fa#r1.1
      lineage: 7c1226fa#r1.1
      bucket: 7c1226fa
      supersedes: null
      origin: reviewer
      layer: 1
      category: goal_fit
      anchor: '#2-goals'
      disposition: decide
      summary: Goals 가 브리프의 goal 과 다른 것을 겨눈다
      edit_scope: '#2-goals'
      blocks: []
      evidence: 브리프 §1 vs 문서 §2
      replacement: §2 를 브리프 §1 의 goal 한 문장으로 되돌린다
      if_unfixed: 설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다
      decision_view:
        if_unfixed: 설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다
        replacement: §2 를 브리프 §1 의 goal 한 문장으로 되돌린다
        basis: 브리프 §1 vs 문서 §2
        alternatives:
        - 고친다(채택)
        - 그대로 둔다(기각)
        - 나중에 정한다(보류)
        impact: '#2-goals (목표가 다른 것을 겨눔) · 인용 0 섹션'
        category_unglossed: null
        auto: false
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    9dea7cf3#r1.1:
      id: 9dea7cf3#r1.1
      lineage: 9dea7cf3#r1.1
      bucket: 9dea7cf3
      supersedes: null
      origin: reviewer
      layer: 2
      category: placeholder
      anchor: '#12-files-to-modify'
      disposition: fix
      summary: §5 에 TBD 가 남아 있다
      edit_scope: '#12-files-to-modify'
      blocks: []
      evidence: null
      replacement: TBD 를 실제 컴포넌트 이름으로 채운다
      if_unfixed: plan 이 그 자리를 스스로 지어낸다
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
  decides:
    7c1226fa#r1.1:
      state: open
      kind: pre
      immutable: false
      prev_hash: null
      round: 1
  fixes:
    9dea7cf3#r1.1:
      state: pending
      round: 1
      scope: null
  asks: {}
  permits: {}
  applied_scopes: []
  decision_log: []
  rounds:
    '1':
      open_lineages:
      - 7c1226fa#r1.1
      - 9dea7cf3#r1.1
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
- r1: prepare-recritic (2 items)
- r1: finalize (2 findings, 0 rejected)
