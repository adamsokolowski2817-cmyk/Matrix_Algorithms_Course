import ../laderman/laderman
import inverse
import improvements/inverse_adaptive
import improvements/split_strategy


# Maksymalny blad wzgledem macierzy jednostkowej.
proc identityError(a: Matrix): float64 =
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(a[i, j] - expected))


# Przykladowa macierz 9x9.
let n = 9
let a = newMatrix(n, n)

for i in 0..<n:
  for j in 0..<n:
    if i == j:
      a[i, j] = 0.8
    else:
      a[i, j] = 0.1


# Wersja podstawowa.
var sNormal: Stats
let normal = inverseLaderman(a, 1, sNormal)


# Wersja adaptacyjna.
var sAdaptive: Stats
let adaptive = inverseLadermanAdaptive(a, 1, sAdaptive)


# Sprawdzamy obie odwrotnosci.
let checkNormal = classicMultiply(a, normal)
let checkAdaptive = classicMultiply(a, adaptive)


echo "Macierz: ", n, "x", n
echo "Podzial podstawowy: ", n div 2, " + ", n - n div 2

let h = splitPoint(n, smDivisibleBy3)
echo "Podzial adaptacyjny: ", h, " + ", n - h

echo "\n=== WERSJA PODSTAWOWA ==="
echo "FLOP: ", flops(sNormal)
echo "Blad: ", identityError(checkNormal)

echo "\n=== WERSJA ADAPTACYJNA ==="
echo "FLOP: ", flops(sAdaptive)
echo "Blad: ", identityError(checkAdaptive)

echo "\nRoznica wynikow: ", maxError(normal, adaptive)
