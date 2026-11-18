import std/random

import ../laderman/laderman
import ../reverse_laderman/inverse
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


# Sprawdzenie A * A^-1 = I.
proc inverseError(a, x: Matrix): float64 =
  let product = classicMultiply(a, x)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i, j] - expected))


# Zapis wyniku w formacie CSV.
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
let startN = cliInt(5, 1)

if maxN < 1 or step < 1 or cutoff < 1 or
   repeats < 1 or startN < 1 or startN > maxN:
  raise newException(ValueError, "Niepoprawne parametry")


var rng = initRand(2026)
var csv = "n,algorithm,time_s,flops,mul,add,sub,div,gflops,error\n"

echo "=== BENCHMARK LADERMANA ==="

for n in countup(startN, maxN, step):
  let a = stableMatrix(n, rng)

  var sResult: Stats
  var inverted: Matrix

  let elapsed = measureBatched(repeats):
    var s: Stats
    inverted = inverseLaderman(a, cutoff, s)
    sResult = s

  let err = inverseError(a, inverted)

  if not (err < 1e-8):
    raise newException(ValueError,
      "Blad Ladermana dla n=" & $n)

  csv.add(csvRow(n, "inverse_laderman", elapsed,
                 sResult, err))

  echo "n=", n,
       " | czas=", elapsed, " s",
       " | FLOP=", flops(sResult),
       " | blad=", err


writeFile("benchmarks/laderman.csv", csv)
echo "Zapisano benchmarks/laderman.csv"
