class RateLimiter:
    def __init__(self, limit: int = 10):
        self.limit = limit
        self.count = 0

    def check(self) -> int:
        self.count += 1
        if self.count > self.limit:
            return 429
        return 200
