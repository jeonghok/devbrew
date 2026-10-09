# tools/plain-language

리포 안에서만 도는 쉬운 말 출력 도구 둘이다. 플러그인에 들어가지 않는다.

- `measure_output.py <목록.tsv>` — 고정한 세션 기록 목록(머리 `path\tsize\tmtime`)의 파일만 읽어 사람에게 보이는 글의 양을 다섯 값으로 낸다. 크기나 수정 시각이 목록과 다른 파일은 읽지 않고 따로 센다. 정의는 스크립트 머리에 있다.
- `token_boundary.py --base <커밋>` — 규칙 블록 때문에 skill 앞 5,000토큰 경계 밖으로 새로 밀려난 절을 근사로 잰다.

테스트: `cd tools/plain-language && python3 -m unittest -v test_measure_output`
