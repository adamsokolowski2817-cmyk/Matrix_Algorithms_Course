import std/random

import ../laderman/laderman
import ../reverse_laderman/inverse


# Losowa macierz z dominujaca przekatna.
proc randomMatrixStable(n: int, rng: var Rand): Matrix =
  result = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        result[i, j] = 0.7 + 0.2 * rand(rng, 1.0)
      else:
        result[i, j] = (0.01 + 0.02 * rand(rng, 1.0)) / float64(n)


# Blad: max |A*A^-1 - I|.
proc inverseError(a, x: Matrix): float64 =
  let product = classicMultiply(a, x)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i, j] - expected))


proc test(n: int, rng: var Rand) =
  let a = randomMatrixStable(n, rng)

  var s: Stats
  let inv = inverseLaderman(a, 1, s)

  let err = inverseError(a, inv)

  if not (err < 1e-8):
    raise newException(ValueError,
      "Laderman | n=" & $n & " | blad=" & $err)

  echo "OK n=", n,
       " | blad=", err,
       " | FLOP=", flops(s)


var rng = initRand(2026)

echo "=== TESTY LADERMANA ==="

for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 16, 24, 32]:
  for trial in 1..3:
    test(n, rng)

echo "\nKONIEC TESTÓW LADERMANA"
