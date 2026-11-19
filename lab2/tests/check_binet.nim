import std/random

import ../binet/binet as binetModule
import ../reverse_binet/inverse
import ../lu_binet/lu
import freivalds
import ../strassen/strassen as strassenModule
import ../reverse_strassen/inverse as inverseStrassenModule
import ../lu_strassen/lu as luStrassenModule


# Powtarzalna macierz z dominujaca przekatna.
# Wszystkie wartosci sa w przedziale (0.00000001, 1.0).
proc stableMatrix(n: int, rng: var Rand): seq[float64] =
  result = newSeq[float64](n * n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        result[i * n + j] = 0.7 + 0.2 * rand(rng, 1.0)
      else:
        result[i * n + j] =
          (0.01 + 0.02 * rand(rng, 1.0)) / float64(n)


proc classicMultiply(a, b: seq[float64], n: int): seq[float64] =
  result = newSeq[float64](n * n)

  for i in 0..<n:
    for k in 0..<n:
      for j in 0..<n:
        result[i * n + j] += a[i * n + k] * b[k * n + j]


proc maxError(a, b: seq[float64]): float64 =
  for i in 0..<a.len:
    result = max(result, abs(a[i] - b[i]))


proc inverseError(a, inverse: seq[float64], n: int): float64 =
  let product = classicMultiply(a, inverse, n)

  for i in 0..<n:
    for j in 0..<n:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i * n + j] - expected))


proc toStrassenMatrix(a: seq[float64], n: int): strassenModule.Matrix =
  result = strassenModule.newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      result[i, j] = a[i * n + j]


proc toSequence(a: strassenModule.Matrix): seq[float64] =
  result = newSeq[float64](a.rows * a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i * a.cols + j] = a[i, j]


proc requireSmallError(name: string, n: int, error: float64) =
  if error >= 1.0e-8:
    raise newException(ValueError,
      name & " | n=" & $n & " | blad=" & $error)


proc checkTriangular(l, u: seq[float64], n: int) =
  for i in 0..<n:
    if abs(l[i * n + i] - 1.0) > 1.0e-10:
      raise newException(ValueError, "Macierz L nie ma jedynek na przekatnej")

    for j in 0..<n:
      if j > i and abs(l[i * n + j]) > 1.0e-10:
        raise newException(ValueError, "Macierz L nie jest dolnotrojkatna")

      if i > j and abs(u[i * n + j]) > 1.0e-10:
        raise newException(ValueError, "Macierz U nie jest gornotrojkatna")


proc testSize(n: int, rng: var Rand) =
  let a = stableMatrix(n, rng)

  # Porownujemy cutoff=1 z klasycznym zakonczeniem rekurencji.
  for cutoff in [1, 2, 4]:
    var inverseStats: binetModule.Stats
    let inverse = inverseBinet(a, n, cutoff, inverseStats)
    requireSmallError("inverse Binet cutoff=" & $cutoff, n,
                      inverseError(a, inverse, n))

    var luStats: binetModule.Stats
    let decomposition = luBinet(a, n, cutoff, luStats)
    requireSmallError("LU Binet cutoff=" & $cutoff, n,
      maxError(a, classicMultiply(decomposition.l, decomposition.u, n)))
    checkTriangular(decomposition.l, decomposition.u, n)

    var verifyRng = initRand(1000 + n * 10 + cutoff)
    doAssert verifyInverseFreivalds(
      a, inverse, n, 10, verifyRng)
    doAssert verifyLUFreivalds(
      a, decomposition.l, decomposition.u, n, 10, verifyRng)

  # Porownanie z istniejacymi implementacjami Strassena.
  let strassenA = toStrassenMatrix(a, n)

  var binetInverseStats: binetModule.Stats
  let binetInverse = inverseBinet(a, n, 1, binetInverseStats)
  var strassenInverseStats: strassenModule.Stats
  let strassenInverse = inverseStrassenModule.inverseStrassen(
    strassenA, 1, strassenInverseStats)
  requireSmallError("inverse Binet vs Strassen", n,
    maxError(binetInverse, toSequence(strassenInverse)))

  var binetLUStats: binetModule.Stats
  let binetLU = luBinet(a, n, 1, binetLUStats)
  var strassenLUStats: strassenModule.Stats
  let strassenLU = luStrassenModule.luStrassen(
    strassenA, 1, strassenLUStats)
  requireSmallError("L Binet vs Strassen", n,
    maxError(binetLU.l, toSequence(strassenLU.l)))
  requireSmallError("U Binet vs Strassen", n,
    maxError(binetLU.u, toSequence(strassenLU.u)))

  echo "OK n=", n


proc testDetectedError(rng: var Rand) =
  let n = 5
  let a = stableMatrix(n, rng)

  var stats: binetModule.Stats
  var decomposition = luBinet(a, n, 2, stats)
  decomposition.u[0] += 0.1

  var verifyRng = initRand(7654)
  doAssert not verifyLUFreivalds(
    a, decomposition.l, decomposition.u, n, 20, verifyRng)

  var inverseStats: binetModule.Stats
  var inverse = inverseBinet(a, n, 2, inverseStats)
  inverse[0] += 0.1

  verifyRng = initRand(8765)
  doAssert not verifyInverseFreivalds(
    a, inverse, n, 20, verifyRng)


proc testNoPivotError() =
  let invertibleButNeedsPivot = @[0.0, 0.5, 0.5, 0.5]

  var inverseStats: binetModule.Stats
  var inverseFailed = false
  try:
    discard inverseBinet(invertibleButNeedsPivot, 2, 1, inverseStats)
  except ValueError:
    inverseFailed = true
  doAssert inverseFailed

  var luStats: binetModule.Stats
  var luFailed = false
  try:
    discard luBinet(invertibleButNeedsPivot, 2, 1, luStats)
  except ValueError:
    luFailed = true
  doAssert luFailed


proc testFlopCounters() =
  # Gauss-Jordan dla 1x1 wykonuje dwa dzielenia:
  # jedno po lewej stronie i jedno dla macierzy jednostkowej.
  var inverseStats: binetModule.Stats
  discard inverseBinet(@[0.5], 1, 1, inverseStats)
  doAssert inverseStats.divs == 2
  doAssert inverseStats.adds == 0
  doAssert inverseStats.subs == 0
  doAssert inverseStats.muls == 0

  # Doolittle dla 2x2: jedno mnozenie, jedno odejmowanie
  # i jedno dzielenie przy wyznaczaniu L[1,0].
  var luStats: binetModule.Stats
  discard luBinet(@[0.8, 0.1, 0.2, 0.7], 2, 2, luStats)
  doAssert luStats.muls == 1
  doAssert luStats.subs == 1
  doAssert luStats.divs == 1
  doAssert luStats.adds == 0


proc testFreivaldsRejectsInvalidNumbers() =
  var verifyRng = initRand(9999)
  doAssert not verifyInverseFreivalds(
    @[1.0], @[NaN], 1, 1, verifyRng)

  verifyRng = initRand(9999)
  doAssert not verifyLUFreivalds(
    @[1.0], @[1.0], @[Inf], 1, 1, verifyRng)


var rng = initRand(2026)

echo "=== TESTY BINETA: ODWROTNA, LU I FREIVALDS ==="

for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 24, 32]:
  for trial in 1..3:
    testSize(n, rng)

testDetectedError(rng)
testNoPivotError()
testFlopCounters()
testFreivaldsRejectsInvalidNumbers()

echo "KONIEC TESTOW BINETA"
