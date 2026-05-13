def login(username: str, password: str) -> int:
    if username == "admin" and password == "secret":
        return 200
    return 401
