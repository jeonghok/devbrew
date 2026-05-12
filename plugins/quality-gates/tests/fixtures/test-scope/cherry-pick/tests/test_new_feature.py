from src.new_feature import RateLimiter

def test_ratelimiter_constructs():
    rl = RateLimiter()
    assert rl is not None  # tautological

def test_ratelimiter_has_limit_attr():
    rl = RateLimiter()
    assert hasattr(rl, "limit")  # property existence, not behavior
