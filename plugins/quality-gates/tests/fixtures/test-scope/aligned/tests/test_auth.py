from src.auth import login

def test_login_valid():
    assert login("admin", "secret") == 200

def test_login_invalid():
    assert login("admin", "wrong") == 401
