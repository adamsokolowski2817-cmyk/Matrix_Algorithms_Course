import std/random

import ../strassen/strassen
import ../reverse_strassen/inverse
import ../lu_strassen/lu
import ../lu_strassen/improvements/lu_triangular
import ../reverse_strassen/improvements/sherman_morrison
import ../reverse_strassen/improvements/newton_schulz


# Losowa macierz z dominujaca przekatna.
# Wszystkie elementy naleza do (1e-8, 1.0).
proc randomMatrixStable(n: int, rng: var Rand): Matrix =
  result = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        result[i, j] = 0.7 + 0.2 * rand(rng, 1.0)
      else:
        result[i, j] = (0.01 + 0.02 * rand(rng, 1.0)) / float64(n)


# Blad odwrotnosci: max |A*X - I|.
proc inverseError(a, x: Matrix): float64 =
  let product = classicMultiply(a, x)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i, j] - expected))


# Czy L i U maja poprawna postac trojkatna?
proc validLU(l, u: Matrix): bool =
  let n = l.rows

  for i in 0..<n:
    if abs(l[i, i] - 1.0) > 1e-10:
      return false

    for j in 0..<n:
      if j > i and abs(l[i, j]) > 1e-10:
        return false

      if i > j and abs(u[i, j]) > 1e-10:
        return false

  return true


# Przerywamy test, jesli blad jest zbyt duzy.
proc requireSmallError(name: string, n: int, err: float64) =
  if not (err < 1e-8):
    raise newException(ValueError,
      name & " | n=" & $n & " | blad=" & $err)


proc test(n: int, rng: var Rand) =
  let a = randomMatrixStable(n, rng)

  # TEST 1: Odwracanie Strassenem.
  var sInverse: Stats
  let inv = inverseStrassen(a, 1, sInverse)
  let errInverse = inverseError(a, inv)

  requireSmallError("Strassen inverse", n, errInverse)

  # TEST 2: Podstawowa faktoryzacja LU.
  var sLU: Stats
  let basic = luStrassen(a, 1, sLU)

  let errLU = maxError(a, classicMultiply(basic.l, basic.u))
  requireSmallError("LU podstawowe", n, errLU)

  if not validLU(basic.l, basic.u):
    raise newException(ValueError, "Niepoprawna postac LU")

  # TEST 3: LU bez jawnych odwrotnosci.
  var sImproved: Stats
  let improved = luStrassenTriangular(a, 1, sImproved)

  let errImproved = maxError(
    a, classicMultiply(improved.l, improved.u))

  requireSmallError("LU ulepszone", n, errImproved)

  if not validLU(improved.l, improved.u):
    raise newException(ValueError, "Niepoprawna postac ulepszonego LU")

  # TEST 4: Sherman-Morrison.
  # Zmieniamy jeden element macierzy.
  let changed = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      changed[i, j] = a[i, j]

  let row = 0
  let col = n - 1
  let delta = 0.015

  changed[row, col] = changed[row, col] + delta

  var sSherman: Stats
  let updated = updateInverseEntry(
    inv, row, col, delta, sSherman)

  let errSherman = inverseError(changed, updated)
  requireSmallError("Sherman-Morrison", n, errSherman)

  # TEST 5: Adaptacyjny Newton-Schulz.
  # Celowo pogarszamy odwrotnosc o 1%.
  let approximate = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      approximate[i, j] = inv[i, j] * 1.01

  let errBefore = inverseError(a, approximate)

  var sNewton: Stats
  let corrected = newtonSchulzAdaptive(
    a, approximate, 1, sNewton)

  let errAfter = inverseError(a, corrected.x)

  if not (errAfter < errBefore and errAfter < 1e-8):
    raise newException(ValueError, "Newton-Schulz nie poprawil wyniku")

  # Sprawdzamy tez, czy nie poprawia bez potrzeby
  # juz dokladnej odwrotnosci.
  var sAccurate: Stats
  let accurate = newtonSchulzAdaptive(a, inv, 1, sAccurate)

  if accurate.iterations != 0:
    raise newException(ValueError, "Zbedna iteracja Newtona")

  echo "OK n=", n,
       " | inverse=", errInverse,
       " | LU=", errLU,
       " | LU improved=", errImproved,
       " | Sherman=", errSherman,
       " | Newton=", errAfter


# Stale ziarno = powtarzalne testy.
var rng = initRand(2026)

echo "=== TESTY STRASSENA I ULEPSZEN ==="

for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 24, 32]:
  for trial in 1..3:
    test(n, rng)

echo "\nKONIEC TESTÓW STRASSENA"
