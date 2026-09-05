# 판정기 자체 검증용 양성 fixture — decision:block 한 자리, 처분 호출 한 건,
# 같은 파일 안. nblock=1, ndisp=1 이 정답이다(둘이 같아도 부족하지 않다).
def handler(ledger):
    ledger.hold("x", "판정자 부재: 예시")
    return {
        "decision": "block",
        "reason": "example",
    }
