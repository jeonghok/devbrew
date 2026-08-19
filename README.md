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

## 구조

- **`/plugins`** — 직접 개발/관리하는 플러그인
- **`/external_plugins`** — 서드파티 플러그인

## License

Apache License 2.0
