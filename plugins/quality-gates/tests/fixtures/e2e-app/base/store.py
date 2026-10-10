"""In-memory item store."""


class Store:
    def __init__(self):
        self._items = []

    def add(self, name):
        name = name.strip()
        if not name:
            raise ValueError("name is empty")
        self._items.append(name)
        return len(self._items)

    def all(self):
        return list(self._items)
