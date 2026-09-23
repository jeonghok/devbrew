# 조사 주장 계약 — `evidence[]` 와 `repo_claims[]`

이 파일이 조사 주장 출력 계약의 **정본**이다. 네 자리가 이 계약을 쓴다 — `coverage-mapper` ·
`blind-spot-prober` · `steelman-builder` 세 dispatch 와, orchestrator 가 직접 수행하는 C43 경로 (a)
자동확인. `agents/steelman-builder.md` 에 같은 스키마의 인라인 사본이 있고, 두 곳의 필드 이름
집합은 `tests/test_research_claims_contract.sh` 축 D 가 집합 등호로 묶는다.

## 형식

```yaml
evidence:                      # 외부(웹) 주장
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: []                # 전제 P<n>
    decides: [OQ1]             # 이 주장이 닿는 «열린 결정». 빈 배열 허용
repo_claims:                   # 내부(레포) 주장
  - id: RC3                    # payload · audit 을 잇는 id
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택 — 보조 정보
    claim: "<주장>"
    touches: []                # 전제 P<n>
    decides: [OQ1]
```

## 두 필드의 뜻이 다르다

- **`touches`** 는 **전제 `P<n>`** 를 담는다.
  `steelman.md` Step 2 가 그 claim 을 지목된 전제 문장과 대조하고, Step 2.5 가
  `premise_refutation.hits` 로 재검토 자격을 판정하며, 의심 게이트의
  제시 형식이 `[반증됨]` 라벨을 붙이고, audit 템플릿이 「부착 주장: <evidence #> → P<n>」 으로 직렬화한다.
- **`decides`** 는 **열린 결정 `OQ<n>`** 를 담는다. 「`<open_decisions>` 에 실제로 있는 결정 중 이
  주장이 닿는 것」이고, 목록에 없는 id 를 지어내지 않는다. **빈 배열은 허용이고 거짓 연결보다 낫다.**

같은 필드에 둘을 넣으면 위 소비 사슬 넷이 무엇을 대조해야 하는지 모른다. 낱말도 가른다 — 「부착」은
`touches` 의 기존 뜻으로만 쓰고, 새 것은 **「결정 연결」** 이라 부른다.

## 판정 전에 구현을 읽는다

> 인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을 읽어라.**

출처: `docs/archive/interview/2026-07-12-project-init-audit-interview.md`. 그 사이클은 「레포에서
auto-confirm 한 사실」 범주를 만들었다가 **4건 중 3건의 전제가 틀린 것**을 확인하고 범주 자체를
폐기했다. 틀린 것은 경로가 아니었다 — 넷 다 실재하는 파일을 가리켰고, 틀린 것은 「그 자리가 주장과
맞는가」였다. 그래서 `path` 와 `anchor` 만으로는 이 실패가 걸러지지 않는다.

## 규칙

1. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않는다. 줄번호는 보조다.
2. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 와 `decides` 를 갖는다. 둘 다 빈 배열이 허용이고
   거짓 부착·거짓 연결보다 낫다.
3. `id: RC<n>` 은 **레포 주장에만** 붙는다. 웹 주장은 payload 의 «출처키» 가 그 자리를 이미 맡는다.
4. `RC<n>` 번호는 **한 인터뷰 안에서만 유일**하다(payload + 그 audit 한 쌍의 범위). `S<N>`·`ST<N>` 과
   같은 규약이고, 코퍼스 전체의 유일성은 요구하지 않는다.
5. 계약을 못 받았으면 조사 주장을 내지 않는다 — 계약 없는 조사는 계약 있는 조사와 산출물에서
   구별되지 않는다.
