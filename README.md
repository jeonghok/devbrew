# DevBrew

Brewing better dev tools for Claude Code.

## 마켓플레이스 등록

`~/.claude/settings.json`의 `extraKnownMarketplaces`에 추가:

```json
{
  "extraKnownMarketplaces": {
    "devbrew": {
      "source": {
        "source": "github",
        "repo": "Jeongho-K/devbrew"
      }
    }
  }
}
```

또는 Claude Code에서:
```
/plugin → Discover → Add marketplace → Jeongho-K/devbrew
```

등록 후 Claude Code를 재시작하면 DevBrew의 모든 플러그인을 `/plugin`에서 확인하고 설치할 수 있습니다.

## 플러그인 목록

| Plugin | Description | Category |
|--------|-------------|----------|
| [quality-gates](plugins/quality-gates/) | 2-gate quality verification pipeline (review + runtime) | development |
| [project-init](plugins/project-init/) | Git workflow initialization: branching strategy, commit conventions, PR process | development |

## Python

devbrew의 **훅**은 Python 3.12 이상을 요구합니다. 이 숫자는 리터럴이 아니라 도출된 값입니다 —
「2026-10 이후에도 패치를 받는 버전 중 최빈」. 다음 재검토 시점은 3.12 EOL(2028-10)이고,
올릴 때는 숫자를 손으로 바꾸는 게 아니라 이 규칙을 다시 적용합니다. 정본은
`shared/python/devbrew-python.sh`의 `FLOOR_MAJOR`/`FLOOR_MINOR`.

바닥 미만 머신에서 훅은 **막지 않고 건너뜁니다**. 대신 세션 시작에 안내가 한 번 나가고,
`$DEVBREW_PYTHON`으로 인터프리터를 직접 지정할 수 있습니다. 스킬·커맨드가 Bash로 부르는
자리는 이 해석의 범위 밖이라 여전히 사용자의 `python3`를 집습니다.

개발·검증은 uv로 재현합니다. 개발 바닥은 `pyproject.toml`의 `requires-python`이며,
출하 바닥과 **같은 숫자지만 같은 사실이 아닙니다** — 집행자가 다릅니다(uv vs 훅의 해석기).

```
uv run -m unittest <module>                    # 개발 바닥 (.python-version)
uv run --python 3.14 -m unittest <module>      # 천장
```

uv가 없으면 기존 `python3 -m unittest`로 degrade합니다 — uv는 출하 요구사항이 아닙니다.

## 구조

- **`/plugins`** — 직접 개발/관리하는 플러그인
- **`/external_plugins`** — 서드파티 플러그인

## License

Apache License 2.0
