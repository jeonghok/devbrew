# `shared/suite-lock/` — 공유 스위트 잠금

`suite_lock.py` 의 정본이다. 전체 스위트처럼 무거운 테스트 실행이 같은 시각에 겹치지 않게 잠금 폴더 하나를 쥐고 명령을 돌린다.

## 누가 쓰나

- spec-distill — 지휘자의 스위트 대조(`merge_check.py`)와 하위 agent 의 전체 스위트. 지휘자 스크립트(`conductor_ledger.py` · `control_plane.py` · `conductor_status.py`)는 잠금 상태를 읽는다.
- quality-gates — 차등 테스트의 테스트 명령마다.

## 링크 꼴

- 두 플러그인은 자기 `scripts/` 에 같은 이름의 상대 심볼릭 링크를 둔다 — `ln -s ../../../shared/suite-lock/suite_lock.py plugins/<플러그인>/scripts/suite_lock.py`. 설치할 때 링크가 실제 내용으로 풀린다.
- 링크가 정본을 가리키는지는 `shared/tests/test_copy_of_contract.sh` 가 잰다.

## 바꿀 때

- 명령줄(`show` · `run`)과 종료 코드 값(show 0 · run 은 명령의 종료 코드 · 75 바쁨 · 3 쓸 수 없음 · 2 사용법)은 두 플러그인이 기대는 계약이다.
- 잠금 자리에 잠금 꼴이 아닌 것(폴더가 아닌 것 · `owner` 파일 말고 다른 것이 든 주인 없는 폴더)이 있으면 치우지도 옮기지도 않고 기다리지 않은 채 3 으로 끝난다.
- 이 파일의 동작을 바꾸는 변경은 공유본 변경이다 — 링크한 두 플러그인의 스위트로 잰다(시험은 `plugins/spec-distill/tests/test_suite_lock.py`). 판 올림은 `CLAUDE.md` 의 판 올림 규칙을 따른다.
