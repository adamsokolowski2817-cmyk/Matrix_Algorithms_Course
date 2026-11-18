import std/random

import ../strassen/strassen
import ../reverse_strassen/inverse
import ../reverse_strassen/improvements/sherman_morrison
import bench_common


# Losowa macierz z dominujaca przekatna.
proc stableMatrix(n: int, rng: var Rand): Matrix =
  result = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        result[i, j] = 0.7 + 0.2 * rand(rng, 1.0)
      else:
        result[i, j] =
          (0.01 + 0.02 * rand(rng, 1.0)) / float64(n)


# Maksymalny blad A*X - I.
proc inverseError(a, x: Matrix): float64 =
  let product = classicMultiply(a, x)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i, j] - expected))


# Zapis pojedynczego wyniku do CSV.
proc csvRow(n: int, name: string, seconds: float64,
            s: Stats, err: float64): string =

  var gflops = 0.0

  if seconds > 0.0:
    gflops = float64(flops(s)) / seconds / 1e9

  result = $n & "," & name & "," &
           $seconds & "," & $flops(s) & "," &
           $s.muls & "," & $s.adds & "," &
           $s.subs & "," & $s.divs & "," &
           $gflops & "," & $err & "\n"


# Parametry benchmarku.
let maxN = cliInt(1, 96)
let step = cliInt(2, 8)
let cutoff = cliInt(3, 1)
let repeats = cliInt(4, 5)
let startN = cliInt(5, 8)

if maxN < 1 or step < 1 or cutoff < 1 or
   repeats < 1 or startN < 1 or startN > maxN:
  raise newException(ValueError, "Niepoprawne parametry")


var rng = initRand(2026)

var csv = "n,algorithm,time_s,flops,mul,add,sub,div,gflops,error\n"

echo "=== BENCHMARK SHERMAN-MORRISON ==="

for n in countup(startN, maxN, step):

  let a = stableMatrix(n, rng)

  # 1. Obliczamy poczatkowa odwrotnosc.
  var initialStats: Stats
  let invA = inverseStrassen(a, cutoff, initialStats)

  # 2. Modyfikujemy jeden element macierzy.
  let changed = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      changed[i, j] = a[i, j]

  let row = 0
  let col = n - 1
  let delta = 0.015

  changed[row, col] = changed[row, col] + delta


  # 3. Podstawowy algorytm: ponowne odwracanie.
  var inverseStats: Stats
  var inverseResult: Matrix

  let inverseTime = measureBatched(repeats):
    var s: Stats
    inverseResult = inverseStrassen(changed, cutoff, s)
    inverseStats = s

  let inverseErr = inverseError(changed, inverseResult)

  if not (inverseErr < 1e-8):
    raise newException(ValueError,
      "Blad ponownego odwracania dla n=" & $n)

  csv.add(csvRow(n, "inverse_strassen",
                 inverseTime, inverseStats, inverseErr))


  # 4. Sherman-Morrison: aktualizacja odwrotnosci.
  var shermanStats: Stats
  var shermanResult: Matrix

  let shermanTime = measureBatched(repeats):
    var s: Stats
    shermanResult = updateInverseEntry(
      invA, row, col, delta, s)
    shermanStats = s

  let shermanErr = inverseError(changed, shermanResult)

  if not (shermanErr < 1e-8):
    raise newException(ValueError,
      "Blad Sherman-Morrison dla n=" & $n)

  csv.add(csvRow(n, "sherman_morrison",
                 shermanTime, shermanStats, shermanErr))


  # 5. Wyniki porownania.
  let savedFlops = flops(inverseStats) - flops(shermanStats)

  var speedup = 0.0
  if shermanTime > 0.0:
    speedup = inverseTime / shermanTime

  echo "\nn=", n
  echo "  Poczatkowa odwrotnosc FLOP: ", flops(initialStats)
  echo "  Ponowne odwracanie:"
  echo "    czas=", inverseTime, " s"
  echo "    FLOP=", flops(inverseStats)

  echo "  Sherman-Morrison:"
  echo "    czas=", shermanTime, " s"
  echo "    FLOP=", flops(shermanStats)

  echo "  Zaoszczedzone FLOP: ", savedFlops
  echo "  Przyspieszenie: ", speedup, "x"
  echo "  Blad Sherman-Morrison: ", shermanErr


writeFile("benchmarks/sherman.csv", csv)

echo "\nZapisano benchmarks/sherman.csv"
