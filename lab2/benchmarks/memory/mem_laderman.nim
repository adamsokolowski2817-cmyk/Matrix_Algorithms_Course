import std/[os, strutils]

import ../../laderman/laderman
import ../../reverse_laderman/inverse


if paramCount() != 3:
  raise newException(ValueError,
    "Uzycie: mem_laderman.exe inverse N CUTOFF")

let mode = paramStr(1)
let n = parseInt(paramStr(2))
let cutoff = parseInt(paramStr(3))

if mode != "inverse" or n < 1 or cutoff < 1:
  raise newException(ValueError, "Niepoprawne parametry")


# Identyczna macierz jak w mem_strassen.nim.
let a = newMatrix(n, n)
let offDiagonal = 0.01 / float64(n)

for i in 0..<n:
  for j in 0..<n:
    a[i, j] = (if i == j: 0.8 else: offDiagonal)


var s: Stats
let x = inverseLaderman(a, cutoff, s)

echo "Inverse Laderman n=", n
echo "Kontrola: ", x[0, 0]
echo "FLOP: ", flops(s)

sleep(100)
