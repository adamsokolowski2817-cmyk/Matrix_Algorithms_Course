import std/random

import ../strassen/strassen
import ../reverse_strassen/inverse
import ../reverse_strassen/improvements/newton_schulz
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


# CSV zawiera dodatkowo blad poczatkowy i iteracje.
proc csvRow(n: int, name: string, seconds: float64,
            s: Stats, beforeErr, afterErr: float64,
            iterations: int): string =

  var gflops = 0.0

  if seconds > 0.0:
    gflops = float64(flops(s)) / seconds / 1e9

  result = $n & "," & name & "," &
           $seconds & "," & $flops(s) & "," &
           $s.muls & "," & $s.adds & "," &
           $s.subs & "," & $s.divs & "," &
           $gflops & "," & $afterErr & "," &
           $beforeErr & "," & $iterations & "\n"


# Parametry.
let maxN = cliInt(1, 96)
let step = cliInt(2, 8)
let cutoff = cliInt(3, 1)
let repeats = cliInt(4, 5)
let startN = cliInt(5, 8)

let tolerance = 1e-12
let maxIterations = 5

if maxN < 1 or step < 1 or cutoff < 1 or
   repeats < 1 or startN < 1 or startN > maxN:
  raise newException(ValueError, "Niepoprawne parametry")


var rng = initRand(2026)

var csv = "n,algorithm,time_s,flops,mul,add,sub,div,gflops,error,error_before,iterations\n"

echo "=== BENCHMARK NEWTON-SCHULZ ==="

for n in countup(startN, maxN, step):

  let a = stableMatrix(n, rng)

  # 1. Poczatkowa odwrotnosc Strassena.
  var inverseStats: Stats
  let invA = inverseStrassen(a, cutoff, inverseStats)


  # 2. Celowo niedokladna odwrotnosc (blad 1%).
  let x0 = newMatrix(n, n)

  for i in 0..<n:
    for j in 0..<n:
      x0[i, j] = invA[i, j] * 1.01

  let approximateBefore = inverseError(a, x0)


  # 3. Adaptacyjny Newton dla niedokladnego wyniku.
  var approxStats: Stats

  var approxResult: tuple[
    x: Matrix,
    initialError, finalError: float64,
    iterations: int
  ]

  let approxTime = measureBatched(repeats):
    var s: Stats
    approxResult = newtonSchulzAdaptive(
      a, x0, cutoff, s, tolerance, maxIterations)
    approxStats = s

  let approximateAfter = inverseError(
    a, approxResult.x)

  if not (approximateAfter < approximateBefore and
          approximateAfter < 1e-8):
    raise newException(ValueError,
      "Newton nie poprawil odwrotnosci dla n=" & $n)

  csv.add(csvRow(n, "newton_approx", approxTime,
                 approxStats, approximateBefore,
                 approximateAfter, approxResult.iterations))


  # 4. Adaptacyjny Newton dla dokladnej odwrotnosci.
  let accurateBefore = inverseError(a, invA)

  var accurateStats: Stats

  var accurateResult: tuple[
    x: Matrix,
    initialError, finalError: float64,
    iterations: int
  ]

  let accurateTime = measureBatched(repeats):
    var s: Stats
    accurateResult = newtonSchulzAdaptive(
      a, invA, cutoff, s, tolerance, maxIterations)
    accurateStats = s

  let accurateAfter = inverseError(
    a, accurateResult.x)

  if not (accurateAfter < 1e-8):
    raise newException(ValueError,
      "Blad dokladnej odwrotnosci dla n=" & $n)

  if accurateResult.initialError <= tolerance and
     accurateResult.iterations != 0:
    raise newException(ValueError,
      "Newton wykonal zbedna iteracje")


  csv.add(csvRow(n, "newton_accurate", accurateTime,
                 accurateStats, accurateBefore,
                 accurateAfter, accurateResult.iterations))


  # 5. Wyniki.
  echo "\nn=", n

  echo "  Poczatkowe odwracanie Strassena:"
  echo "    FLOP=", flops(inverseStats)

  echo "  Niedokladna odwrotnosc:"
  echo "    blad przed=", approximateBefore
  echo "    blad po=", approximateAfter
  echo "    iteracje=", approxResult.iterations
  echo "    czas=", approxTime, " s"
  echo "    FLOP=", flops(approxStats)

  echo "  Dokladna odwrotnosc:"
  echo "    blad przed=", accurateBefore
  echo "    blad po=", accurateAfter
  echo "    iteracje=", accurateResult.iterations
  echo "    czas=", accurateTime, " s"
  echo "    FLOP=", flops(accurateStats)


writeFile("benchmarks/newton.csv", csv)

echo "\nZapisano benchmarks/newton.csv"
