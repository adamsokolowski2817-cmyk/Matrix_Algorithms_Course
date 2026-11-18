import std/random
import ../lu_strassen/improvements/lu_triangular
import ../strassen/strassen
import ../reverse_strassen/inverse
import ../lu_strassen/lu
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

echo "=== BENCHMARK STRASSEN / LU ==="

for n in countup(startN, maxN, step):
  let a = stableMatrix(n, rng)

  # 1. ODWROTNA STRASSENA
  var inverseStats: Stats
  var inverted: Matrix

  let inverseTime = measureBatched(repeats):
    var s: Stats
    inverted = inverseStrassen(a, cutoff, s)
    inverseStats = s

  let invError = inverseError(a, inverted)

  if not (invError < 1e-8):
    raise newException(ValueError,
      "Blad odwracania dla n=" & $n)

  csv.add(csvRow(n, "inverse_strassen", inverseTime,
                 inverseStats, invError))

  echo "n=", n,
       " | inverse=", inverseTime, " s",
       " | FLOP=", flops(inverseStats)


  # 2. PODSTAWOWA FAKTORYZACJA LU
  var luStats: Stats
  var decomposition: tuple[l, u: Matrix]

  let luTime = measureBatched(repeats):
    var s: Stats
    decomposition = luStrassen(a, cutoff, s)
    luStats = s

  let product = classicMultiply(
    decomposition.l, decomposition.u)

  let luError = maxError(a, product)

  if not (luError < 1e-8):
    raise newException(ValueError,
      "Blad faktoryzacji LU dla n=" & $n)

  csv.add(csvRow(n, "lu_strassen", luTime,
                 luStats, luError))

  echo "n=", n,
       " | LU=", luTime, " s",
       " | FLOP=", flops(luStats)

  echo ""


  # 3. ULEPSZONA FAKTORYZACJA LU
  var improvedStats: Stats
  var improved: tuple[l, u: Matrix]

  let improvedTime = measureBatched(repeats):
    var s: Stats
    improved = luStrassenTriangular(a, cutoff, s)
    improvedStats = s

  let improvedProduct = classicMultiply(
    improved.l, improved.u)

  let improvedError = maxError(a, improvedProduct)

  if not (improvedError < 1e-8):
    raise newException(ValueError,
      "Blad ulepszonego LU dla n=" & $n)

  csv.add(csvRow(n, "lu_strassen_triangular",
                 improvedTime, improvedStats, improvedError))

  echo "n=", n,
       " | LU improved=", improvedTime, " s",
       " | FLOP=", flops(improvedStats)



writeFile("benchmarks/strassen.csv", csv)
echo "Zapisano benchmarks/strassen.csv"
