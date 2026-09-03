import sys
sys.path.insert(0, sys.argv[1] + "/shared/adjudication")
from adjudication import Ledger

L = Ledger(items="open")
L.hold("a", "판정자 부재: adversarial 판정 없음")
L.hold("b", "항목 파손: not a mapping")
L.hold("c", "항목 파손: missing file")
L.hold("d", "접두 없는 사유")
c = L.held_by_class()
print("부재=%d" % c["판정자 부재"])
print("파손=%d" % c["항목 파손"])
print("기타=%d" % c["기타"])
print("합=%d" % sum(c.values()))
