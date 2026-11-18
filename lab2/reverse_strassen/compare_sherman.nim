import std/[monotimes, times]
import ../strassen/strassen
import inverse
import improvements/sherman_morrison


# Maksymalny blad wzgledem macierzy jednostkowej.
proc identityError(a: Matrix): float64 =
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(a[i, j] - expected))


proc test(n: int) =
  let a = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        a[i, j] = 0.8
      else:
        a[i, j] = 0.1

  # Obliczamy poczatkowa odwrotnosc A.
  var sInitial: Stats
  let invA = inverseStrassen(a, 1, sInitial)

  # Zmieniamy jeden element macierzy.
  let row = 1
  let col = 2
  let delta = 0.05

  let changed = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      changed[i, j] = a[i, j]

  changed[row, col] = changed[row, col] + delta

  # WERSJA 1: Ponowne odwracanie Strassenem.
  var sNormal: Stats

  let startNormal = getMonoTime()
  let normal = inverseStrassen(changed, 1, sNormal)
  let timeNormal = (getMonoTime() - startNormal).inMicroseconds

  # WERSJA 2: Sherman-Morrison.
  var sSherman: Stats

  let startSherman = getMonoTime()
  let updated = updateInverseEntry(invA, row, col,
                                   delta, sSherman)
  let timeSherman = (getMonoTime() - startSherman).inMicroseconds

  # Kontrola poprawnosci poza pomiarem czasu.
  let checkNormal = classicMultiply(changed, normal)
  let checkSherman = classicMultiply(changed, updated)

  echo "\n=== MACIERZ ", n, "x", n, " ==="
  echo "Koszt poczatkowej odwrotnosci: ", flops(sInitial)

  echo "\nPonowne odwracanie:"
  echo "  FLOP: ", flops(sNormal)
  echo "  Czas [us]: ", timeNormal
  echo "  Blad: ", identityError(checkNormal)

  echo "\nSherman-Morrison:"
  echo "  FLOP: ", flops(sSherman)
  echo "  Czas [us]: ", timeSherman
  echo "  Blad: ", identityError(checkSherman)

  echo "\nRoznica odwrotnosci: ", maxError(normal, updated)


for n in [4, 9, 16, 32]:
  test(n)
