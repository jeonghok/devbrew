def emit(sources_failed, accepted):
    # 원장과 무관한 지역 카운터를 출력 dict 로 «만든다». 읽는 것이 아니다.
    return {"sources_failed": sources_failed, "accepted": accepted}
