import std/[monotimes, times]
import ../strassen/strassen
import lu
import improvements/lu_triangular


proc test(n: int) =
  let a = newMatrix(n, n)

  # Ta sama macierz dla obu algorytmow.
  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        a[i, j] = 0.8
      else:
        a[i, j] = 0.1

  # Wersja podstawowa.
  var sNormal: Stats

  let startNormal = getMonoTime()
  let normal = luStrassen(a, 1, sNormal)
  let timeNormal = (getMonoTime() - startNormal).inMicroseconds

  # Wersja bez odwrotnosci.
  var sImproved: Stats

  let startImproved = getMonoTime()
  let improved = luStrassenTriangular(a, 1, sImproved)
  let timeImproved = (getMonoTime() - startImproved).inMicroseconds

  # Kontrola poprawnosci (poza pomiarem czasu).
  let checkNormal = classicMultiply(normal.l, normal.u)
  let checkImproved = classicMultiply(improved.l, improved.u)

  echo "\n=== MACIERZ ", n, "x", n, " ==="

  echo "Wersja podstawowa:"
  echo "  FLOP: ", flops(sNormal)
  echo "  Czas [us]: ", timeNormal
  echo "  Blad: ", maxError(a, checkNormal)

  echo "Wersja ulepszona:"
  echo "  FLOP: ", flops(sImproved)
  echo "  Czas [us]: ", timeImproved
  echo "  Blad: ", maxError(a, checkImproved)

  echo "Oszczednosc FLOP: ",
    flops(sNormal) - flops(sImproved)


# Testujemy kilka rozmiarow.
for n in [4, 6, 9, 12]:
  test(n)
