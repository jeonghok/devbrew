# Items

A small item list app. Python 3 standard library only — nothing to install.

## Run

```
python3 app.py --port 8765
```

The server binds `127.0.0.1` and prints `listening on http://127.0.0.1:8765` when it is ready.

## API

- `GET /api/items` → `{"items": [<name>, ...]}`
- `POST /api/items` with JSON `{"name": "<item>"}` → `201 {"count": <n>}`; an empty name → `400`

## Test

```
bash tests/test_store.sh
```
