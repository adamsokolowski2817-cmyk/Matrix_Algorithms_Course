
import std/strutils
import ../laderman/laderman
import inverse

# Czytelne wyswietlanie macierzy.
proc printMatrix(a: Matrix) =
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      stdout.write(formatFloat(a[i, j], ffDecimal, 5), "  ")
    echo ""


# Tworzymy macierz 6x6.
let n = 6
let a = newMatrix(n, n)

for i in 0..<n:
  for j in 0..<n:
    if i == j:
      a[i, j] = 0.8
    else:
      a[i, j] = 0.1


# Odwracanie macierzy.
var s: Stats
let inverted = inverseLaderman(a, 1, s)

echo "Macierz A:"
printMatrix(a)

echo "\nMacierz odwrotna A^-1:"
printMatrix(inverted)

echo "\nLiczba FLOP: ", flops(s)


# Kontrola poprawnosci: A * A^-1 = I.
let check = classicMultiply(a, inverted)

echo "\nKontrola A * A^-1:"
printMatrix(check)

var maxError = 0.0

for i in 0..<n:
  for j in 0..<n:
    let expected = (if i == j: 1.0 else: 0.0)
    maxError = max(maxError, abs(check[i, j] - expected))

echo "\nMaksymalny blad: ", maxError
