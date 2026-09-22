---
docreview:
  doc: <REPO_ROOT>/shared/tests/fixtures/docreview/design-sample.md
  profile: <REPO_ROOT>/plugins/spec-distill/references/docreview-profiles/design-doc.md
  round: 2
  rereview_count: 1
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
    '2':
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
        hash: 779483f9b33c
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
        hash: 5d9a206e6f82
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
    fee27fc9#r1.1:
      id: fee27fc9#r1.1
      lineage: fee27fc9#r1.1
      bucket: fee27fc9
      supersedes: null
      origin: reviewer
      layer: 1
      category: scope
      anchor: '#3-non-goals'
      disposition: decide
      summary: Non-goals 가 브리프의 범위 항목 하나를 조용히 뺐다
      edit_scope: '#3-non-goals'
      blocks: []
      evidence: 브리프 §2 C3 vs 문서 §3
      replacement: null
      if_unfixed: null
      decision_view:
        if_unfixed: (리뷰어가 안 적음)
        replacement: (대체안 미작성)
        basis: 브리프 §2 C3 vs 문서 §3
        alternatives:
        - 고친다(채택)
        - 그대로 둔다(기각)
        - 나중에 정한다(보류)
        impact: '#3-non-goals (범위가 넓어지거나 좁아짐) · 인용 0 섹션'
        category_unglossed: null
        auto: false
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    011167c4#r1.2:
      id: 011167c4#r1.2
      lineage: 011167c4#r1.2
      bucket: 011167c4
      supersedes: null
      origin: reviewer
      layer: 2
      category: ambiguity
      anchor: '#1-context'
      disposition: fix
      summary: AC 가 하나뿐이라 Goals B 를 덮지 않는다
      edit_scope: '#1-context'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    d56c5e0c#r1.1:
      id: d56c5e0c#r1.1
      lineage: d56c5e0c#r1.1
      bucket: d56c5e0c
      supersedes: null
      origin: reviewer
      layer: 2
      category: ambiguity
      anchor: '#12-files-to-modify'
      disposition: ask
      summary: b.py 를 유지하나?
      edit_scope: '#12-files-to-modify'
      blocks:
      - 9dea7cf3#r1.1
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
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
      disposition: decide
      summary: c.py 누락 — 파일 목록이 실제 변경과 다르다
      edit_scope: '#12-files-to-modify'
      blocks: []
      evidence: §5 가 c.py 를 참조한다
      replacement: null
      if_unfixed: null
      decision_view:
        if_unfixed: (리뷰어가 안 적음)
        replacement: (대체안 미작성)
        basis: §5 가 c.py 를 참조한다
        alternatives:
        - 고친다(채택)
        - 그대로 둔다(기각)
        - 나중에 정한다(보류)
        impact: '#12-files-to-modify (TBD·빈 절) · 인용 1 섹션'
        category_unglossed: null
        auto: false
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    d949ac4c#r1.1:
      id: d949ac4c#r1.1
      lineage: d949ac4c#r1.1
      bucket: d949ac4c
      supersedes: null
      origin: reviewer
      layer: 2
      category: testing
      anchor: '#12-files-to-modify'
      disposition: defer
      summary: AC1 의 자동 검증 절차는 plan 이 정한다
      edit_scope: '#12-files-to-modify'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    11adb9c3#r1.1:
      id: 11adb9c3#r1.1
      lineage: 11adb9c3#r1.1
      bucket: 11adb9c3
      supersedes: null
      origin: auto
      layer: 2
      category: ambiguity
      anchor: '#2-goals'
      disposition: decide
      summary: 목표 B 가 두 가지로 읽힌다
      edit_scope: '#2-goals'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view:
        if_unfixed: (리뷰어가 안 적음)
        replacement: (대체안 미작성)
        basis: (근거 없음)
        alternatives:
        - 고친다(채택)
        - 그대로 둔다(기각)
        - 나중에 정한다(보류)
        impact: '#2-goals (두 가지로 읽힘) · 인용 0 섹션'
        category_unglossed: null
        auto: true
      state: null
      promotion: protected
      promoted_from: fix
      immutable: false
      kind: pre
    e1b5b3be#r1.1:
      id: e1b5b3be#r1.1
      lineage: e1b5b3be#r1.1
      bucket: e1b5b3be
      supersedes: null
      origin: reviewer
      layer: 2
      category: handoff_incomplete
      anchor: '#handoff-context'
      disposition: fix
      summary: Deferred to plan 표가 비어 있다
      edit_scope: '#handoff-context'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    65e28991#r1.1:
      id: 65e28991#r1.1
      lineage: 65e28991#r1.1
      bucket: 65e28991
      supersedes: null
      origin: reviewer
      layer: 2
      category: isolation
      anchor: '#handoff-context'
      disposition: fix
      summary: 부품 경계가 흐리다
      edit_scope: '#handoff-context'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    1615824b#r1.1:
      id: 1615824b#r1.1
      lineage: 1615824b#r1.1
      bucket: 1615824b
      supersedes: null
      origin: auto
      layer: 1
      category: data_flow
      anchor: '#5-architecture'
      disposition: decide
      summary: §5 의 데이터 흐름에 소비자 없는 산출물이 있다 — 의도인가?
      edit_scope: '#5-architecture'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view:
        if_unfixed: (리뷰어가 안 적음)
        replacement: (대체안 미작성)
        basis: (근거 없음)
        alternatives:
        - 고친다(채택)
        - 그대로 둔다(기각)
        - 나중에 정한다(보류)
        impact: '#5-architecture (데이터가 끊김) · 인용 0 섹션'
        category_unglossed: null
        auto: true
      state: null
      promotion: protected
      promoted_from: ask
      immutable: false
      kind: pre
    011167c4#r1.1:
      id: 011167c4#r1.1
      lineage: 011167c4#r1.1
      bucket: 011167c4
      supersedes: null
      origin: reviewer
      layer: 2
      category: ambiguity
      anchor: '#1-context'
      disposition: fix
      summary: AC1 의 '관측 가능한' 이 무엇인지 없다
      edit_scope: '#1-context'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: rejected
      promotion: null
      promoted_from: null
      immutable: null
      kind: null
    11adb9c3#r2.1:
      id: 11adb9c3#r2.1
      lineage: 11adb9c3#r2.1
      bucket: 11adb9c3
      supersedes: null
      origin: reviewer
      layer: 2
      category: ambiguity
      anchor: '#2-goals'
      disposition: fix
      summary: 목표 B 문구 후속 손질
      edit_scope: '#2-goals'
      blocks: []
      evidence: null
      replacement: null
      if_unfixed: null
      decision_view: null
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: pre
    42522f07#r2.1:
      id: 42522f07#r2.1
      lineage: 42522f07#r2.1
      bucket: 42522f07
      supersedes: null
      origin: auto
      layer: 2
      category: frozen_change
      anchor: '#12-files-to-modify'
      disposition: decide
      summary: 'finding 없이 바뀜: 12. Files to Modify (modified)'
      edit_scope: '#12-files-to-modify'
      blocks: []
      evidence: 섹션 '12. Files to Modify' (#12-files-to-modify) modified — hash 62a715899d27→5d9a206e6f82
      replacement: null
      if_unfixed: null
      decision_view:
        if_unfixed: (리뷰어가 안 적음)
        replacement: (대체안 미작성)
        basis: 섹션 '12. Files to Modify' (#12-files-to-modify) modified — hash 62a715899d27→5d9a206e6f82
        alternatives:
        - 현재 변경 유지(채택)
        - 이전 상태로 원복(기각)
        - 나중에 정한다(보류)
        impact: '#12-files-to-modify (얼림 검사가 잡은 변경) · 인용 1 섹션'
        category_unglossed: null
        auto: true
      state: null
      promotion: null
      promoted_from: null
      immutable: false
      kind: post
  decides:
    fee27fc9#r1.1:
      state: open
      kind: pre
      immutable: false
      prev_hash: null
      round: 1
    9dea7cf3#r1.1:
      state: open
      kind: pre
      immutable: false
      prev_hash: null
      round: 1
    11adb9c3#r1.1:
      state: applied
      kind: pre
      immutable: false
      prev_hash: null
      round: 1
      decision_id: D1.1
    1615824b#r1.1:
      state: open
      kind: pre
      immutable: false
      prev_hash: null
      round: 1
    42522f07#r2.1:
      state: open
      kind: post
      immutable: false
      prev_hash: 62a715899d27
      round: 2
  fixes:
    011167c4#r1.2:
      state: pending
      round: 1
      scope: null
    e1b5b3be#r1.1:
      state: pending
      round: 1
      scope: null
    65e28991#r1.1:
      state: pending
      round: 1
      scope: null
    11adb9c3#r2.1:
      state: pending
      round: 2
      scope: null
  asks:
    d56c5e0c#r1.1:
      answered: false
      blocks:
      - 9dea7cf3#r1.1
      round: 1
  permits:
    D1.1:
      kind: apply
      apply_anchors:
      - '#2-goals'
      round: 2
      finding_id: 11adb9c3#r1.1
      consumed: true
  applied_scopes: []
  decision_log:
  - decision_id: D1.1
    round: 1
    finding_ids:
    - 11adb9c3#r1.1
    lineage: 11adb9c3#r1.1
    choice: adopt
    quote: 목표 B 문구 수정 승인
  rounds:
    '1':
      open_lineages:
      - 011167c4#r1.2
      - 11adb9c3#r1.1
      - 1615824b#r1.1
      - 65e28991#r1.1
      - 9dea7cf3#r1.1
      - d56c5e0c#r1.1
      - e1b5b3be#r1.1
      - fee27fc9#r1.1
      progress: 0
      route_report:
        degrade:
          critic_dead: false
          layer2_missing: false
          codex_absent: false
          codex_reason: null
          recritic_dead: null
        advisory: []
        rejected: 1
        bucket_conflicts: 1
        revived: 0
        lineage_mismatch: 1
        reraise_unconsumed: 0
        escalated_unconsumed: 0
      started_mtime_ns: <MTIME_NS>
    '2':
      open_lineages:
      - 011167c4#r1.2
      - 11adb9c3#r2.1
      - 1615824b#r1.1
      - 42522f07#r2.1
      - 65e28991#r1.1
      - 9dea7cf3#r1.1
      - d56c5e0c#r1.1
      - e1b5b3be#r1.1
      - fee27fc9#r1.1
      progress: 1
      route_report:
        degrade:
          critic_dead: false
          layer2_missing: false
          codex_absent: true
          codex_reason: exit_nonzero
          recritic_dead: missing
        advisory:
        - codex 없음 — 모델 다양성 0 (exit_nonzero)
        - '입력 실패(보조): codex — exit_nonzero'
        - '입력 실패(보조): doc-recritic — missing'
        - 기각 경로 0 — 오탐이 걸러지지 않았다 (doc-recritic missing)
        rejected: 0
        bucket_conflicts: 0
        revived: 0
        lineage_mismatch: 0
        reraise_unconsumed: 0
        escalated_unconsumed: 0
      started_mtime_ns: <MTIME_NS>
  pending_recritic: null
  rejected_lineages:
    011167c4#r1.1:
      by: recritic
      why: AC1 본문이 '관측 가능한 조건' 을 §13 항목으로 정의한다 — 오탐
      round: 1
  escalated: []
  reraise: []
---
# docreview 원장
- r0: init
- r1: begin-round (rereview_count=0)
- r1: prepare-recritic (10 items)
- r1: finalize (9 findings, 1 rejected)
- r1: decide 11adb9c3#r1.1 adopt
- r2: begin-round (rereview_count=1)
- r2: observe-diff applied=1 expired=0
- r2: prepare-recritic (1 items)
- r2: finalize (2 findings, 0 rejected)
