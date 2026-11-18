import std/strutils
import ../strassen/strassen
import lu


# Wyswietlanie macierzy.
proc printMatrix(a: Matrix) =
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      stdout.write(formatFloat(a[i, j], ffDecimal, 5), "  ")
    echo ""


# Tworzymy macierz 4x4.
let n = 4
let a = newMatrix(n, n)

for i in 0..<n:
  for j in 0..<n:
    if i == j:
      a[i, j] = 0.8
    else:
      a[i, j] = 0.1


# Faktoryzacja LU.
var s: Stats
let decomposition = luStrassen(a, 1, s)

let l = decomposition.l
let u = decomposition.u

echo "Macierz A:"
printMatrix(a)

echo "\nMacierz L:"
printMatrix(l)

echo "\nMacierz U:"
printMatrix(u)


# Sprawdzamy L * U = A.
let check = classicMultiply(l, u)

echo "\nKontrola L * U:"
printMatrix(check)

echo "\nLiczba FLOP: ", flops(s)
echo "Maksymalny blad: ", maxError(a, check)
