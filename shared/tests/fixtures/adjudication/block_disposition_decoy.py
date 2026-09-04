# 판정기 자체 검증용 decoy fixture — review-dispatch.py 의
# `_block_with_ledger()` docstring 이 실측으로 드러낸 결함을 재현한다:
# 설명 주석 안의 `L.reject(...)` 텍스트가 grep -c
# 기반 카운트를 실제 호출로 오인시켰다. 여기엔 decision:block 한 자리가
# 있지만 처분 호출은 «주석 속 문자열»뿐, 실제 ast.Call 은 없다.
# 정답은 nblock=1, ndisp=0 — grep 기반이면 ndisp=1 로 잘못 세어 이 결손을
# 놓친다.
def handler():
    # 누가 `L.reject(...)` 하나만 더해도 공시가 뜬다 — 지금은 안 부른다.
    return {
        "decision": "block",
        "reason": "example",
    }
