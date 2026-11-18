import ../strassen/strassen
import inverse
import improvements/newton_schulz


# Niezalezna kontrola: max |A*X - I|.
proc checkError(a, x: Matrix): float64 =
  let ax = classicMultiply(a, x)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(ax[i, j] - expected))


# Macierz 12x12.
let n = 12
let a = newMatrix(n, n)

for i in 0..<n:
  for j in 0..<n:
    if i == j:
      a[i, j] = 0.8
    else:
      a[i, j] = 0.1


# Odwrotnosc Strassena.
var sInverse: Stats
let invA = inverseStrassen(a, 1, sInverse)

echo "=== ODWROTNA STRASSENA ==="
echo "FLOP: ", flops(sInverse)
echo "Blad: ", checkError(a, invA)


# TEST 1: celowo niedokladna odwrotnosc.
let x0 = newMatrix(n, n)

for i in 0..<n:
  for j in 0..<n:
    x0[i, j] = invA[i, j] * 1.01

var sApprox: Stats
let approx = newtonSchulzAdaptive(a, x0, 1, sApprox)

echo "\n=== NIEDOKLADNA ODWROTNOSC ==="
echo "Blad przed: ", checkError(a, x0)
echo "Blad po: ", checkError(a, approx.x)
echo "Liczba iteracji: ", approx.iterations
echo "FLOP: ", flops(sApprox)


# TEST 2: dokladna odwrotnosc Strassena.
var sAccurate: Stats
let accurate = newtonSchulzAdaptive(a, invA, 1, sAccurate)

echo "\n=== DOKLADNA ODWROTNOSC ==="
echo "Blad przed: ", checkError(a, invA)
echo "Blad po: ", checkError(a, accurate.x)
echo "Liczba iteracji: ", accurate.iterations
echo "FLOP: ", flops(sAccurate)
