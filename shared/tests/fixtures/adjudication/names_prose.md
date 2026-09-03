<!-- 회귀 fixture — 정확히 무엇을 막는지: 실측(Task 6 리뷰)으로 백틱 요구만
     떼거나 콜론 요구만 떼면 아래 본문은 여전히 0건이고, «둘 다» 떼야 (맨
     `adversarial` 네 번 + 백틱 없는 콜론 둘 =) 4건이 잡힌다. 즉 이 fixture 는
     「표기를 아예 안 보는 맨 이름 스캔」— 형제 락(test_dispatch_disposition.sh)이
     겪은 실제 역사적 결함 — 을 막는다. 백틱 조건과 콜론 조건을 «각각» 독립으로
     재지는 않는다. -->
The adversarial reviewer is adversarial by design; adversarial output
feeds the adversarial gate. Note the ratio 3:1 and the key value: here.
