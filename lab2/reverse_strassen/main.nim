
import ../strassen/strassen
import inverse

# Wyswietlanie macierzy w terminalu.
proc printMatrix(a: Matrix) =
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      stdout.write(a[i, j], "  ")
    echo ""


let a = newMatrix(4, 4)

for i in 0..<4:
  for j in 0..<4:
    if i == j:
      a[i, j] = 0.8
    else:
      a[i, j] = 0.1

var s: Stats

let inverted = inverseStrassen(a, 1, s)

echo "Macierz A:"
printMatrix(a)

echo "\nMacierz odwrotna A^-1:"
printMatrix(inverted)

echo "\nLiczba FLOP: ", flops(s)

let check = classicMultiply(a, inverted)

echo "\nKontrola A * A^-1:"
printMatrix(check)
