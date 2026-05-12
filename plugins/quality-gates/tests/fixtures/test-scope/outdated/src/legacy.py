def parse_v2(payload: dict) -> dict:
    return {"version": 2, "data": payload.get("data", {})}
