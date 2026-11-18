import std/[os, strutils]

import ../../strassen/strassen
import ../../reverse_strassen/inverse
import ../../lu_strassen/lu
import ../../lu_strassen/improvements/lu_triangular


# Parametry: tryb, rozmiar, cutoff.
if paramCount() != 3:
  raise newException(ValueError,
    "Uzycie: mem_strassen.exe TRYB N CUTOFF")

let mode = paramStr(1)
let n = parseInt(paramStr(2))
let cutoff = parseInt(paramStr(3))

if n < 1 or cutoff < 1:
  raise newException(ValueError, "Niepoprawne parametry")


# Ta sama macierz dla kazdego algorytmu.
let a = newMatrix(n, n)
let offDiagonal = 0.01 / float64(n)

for i in 0..<n:
  for j in 0..<n:
    a[i, j] = (if i == j: 0.8 else: offDiagonal)


# Wykonujemy tylko jedna wybrana operacje.
case mode

of "inverse":
  var s: Stats
  let x = inverseStrassen(a, cutoff, s)

  echo "Inverse Strassen n=", n
  echo "Kontrola: ", x[0, 0]
  echo "FLOP: ", flops(s)

of "lu":
  var s: Stats
  let decomposition = luStrassen(a, cutoff, s)

  echo "LU Strassen n=", n
  echo "Kontrola: ", decomposition.l[0, 0]
  echo "FLOP: ", flops(s)

of "lu_improved":
  var s: Stats
  let decomposition = luStrassenTriangular(a, cutoff, s)

  echo "LU improved n=", n
  echo "Kontrola: ", decomposition.u[0, 0]
  echo "FLOP: ", flops(s)

else:
  raise newException(ValueError, "Nieznany tryb")


# Dajemy PowerShellowi czas na odczyt pamieci.
sleep(100)
