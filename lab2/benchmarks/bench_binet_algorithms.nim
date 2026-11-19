import std/[monotimes, os, random, strutils, times]

import ../binet/binet
import ../reverse_binet/inverse
import ../lu_binet/lu
import ../tests/freivalds

# Parametry:
# maxN step wiekszyCutoff powtorzenia startN [plikCSV]
# Przyklad pojedynczego pomiaru:
# bench_binet_algorithms.exe 1000 1 32 1 1000 benchmarks/binet_n1000.csv


proc cliInt(position, defaultValue: int): int =
  if paramCount() >= position:
    parseInt(paramStr(position))
  else:
    defaultValue


proc cliString(position: int, defaultValue: string): string =
  if paramCount() >= position:
    paramStr(position)
  else:
    defaultValue


proc stableMatrix(n: int, rng: var Rand): seq[float64] =
  result = newSeq[float64](n * n)

  for i in 0..<n:
    for j in 0..<n:
      if i == j:
        result[i * n + j] = 0.7 + 0.2 * rand(rng, 1.0)
      else:
        result[i * n + j] =
          (0.01 + 0.02 * rand(rng, 1.0)) / float64(n)


proc classicMultiply(a, b: seq[float64], n: int): seq[float64] =
  result = newSeq[float64](n * n)

  for i in 0..<n:
    for k in 0..<n:
      for j in 0..<n:
        result[i * n + j] += a[i * n + k] * b[k * n + j]


proc maxError(a, b: seq[float64]): float64 =
  for i in 0..<a.len:
    result = max(result, abs(a[i] - b[i]))


proc inverseError(a, inverse: seq[float64], n: int): float64 =
  let product = classicMultiply(a, inverse, n)

  for i in 0..<n:
    for j in 0..<n:
      let expected = (if i == j: 1.0 else: 0.0)
      result = max(result, abs(product[i * n + j] - expected))


template measuredSeconds(operation: untyped): float64 =
  block:
    let startTime = getMonoTime()
    operation
    float64((getMonoTime() - startTime).inNanoseconds) / 1.0e9


proc csvRow(n, cutoff: int, algorithm: string, algorithmTime: float64,
            stats: Stats, error, classicCheckTime,
            freivaldsCheckTime: float64, verified: bool): string =
  var gflops = 0.0

  if algorithmTime > 0.0:
    gflops = float64(flops(stats)) / algorithmTime / 1.0e9

  result = $n & "," & $cutoff & "," & algorithm & "," &
    $algorithmTime & "," & $flops(stats) & "," & $gflops & "," &
    $stats.muls & "," & $stats.adds & "," &
    $stats.subs & "," & $stats.divs & "," &
    $error & "," & $classicCheckTime & "," &
    $freivaldsCheckTime & "," & $verified & "\n"


let
  maxN = cliInt(1, 64)
  step = cliInt(2, 4)
  largerCutoff = cliInt(3, 8)
  repeats = cliInt(4, 3)
  startN = cliInt(5, 1)
  outputPath = cliString(6, "benchmarks/binet_algorithms.csv")

if maxN < 1 or step < 1 or largerCutoff < 1 or repeats < 1 or
   startN < 1 or startN > maxN:
  raise newException(ValueError, "Niepoprawne parametry benchmarku")

var rng = initRand(2026)
var csv = "n,cutoff,algorithm,time_s,flops,gflops,mul,add,sub,div,error," &
          "classic_check_s,freivalds_check_s,freivalds_ok\n"

let testedCutoffs =
  if largerCutoff == 1: @[1]
  else: @[1, largerCutoff]

for n in countup(startN, maxN, step):
  # Generowanie macierzy jest poza pomiarem algorytmu.
  let a = stableMatrix(n, rng)

  for cutoff in testedCutoffs:
    var bestInverseTime = 1.0e100
    var inverseStats: Stats
    var inverted: seq[float64]

    for repetition in 0..<repeats:
      var currentStats: Stats
      var currentInverse: seq[float64]
      let elapsed = measuredSeconds:
        currentInverse = inverseBinet(a, n, cutoff, currentStats)

      if elapsed < bestInverseTime:
        bestInverseTime = elapsed
        inverseStats = currentStats
        inverted = currentInverse

    var inverseErrorValue = 0.0
    let inverseClassicCheckTime = measuredSeconds:
      inverseErrorValue = inverseError(a, inverted, n)

    var inverseVerified = false
    var inverseVerifyRng = initRand(3000 + n + cutoff)
    let inverseFreivaldsTime = measuredSeconds:
      inverseVerified = verifyInverseFreivalds(
        a, inverted, n, 10, inverseVerifyRng)

    csv.add(csvRow(n, cutoff, "inverse_binet", bestInverseTime,
      inverseStats, inverseErrorValue, inverseClassicCheckTime,
      inverseFreivaldsTime, inverseVerified))

    var bestLUTime = 1.0e100
    var luStats: Stats
    var decomposition: tuple[l, u: seq[float64]]

    for repetition in 0..<repeats:
      var currentStats: Stats
      var currentDecomposition: tuple[l, u: seq[float64]]
      let elapsed = measuredSeconds:
        currentDecomposition = luBinet(a, n, cutoff, currentStats)

      if elapsed < bestLUTime:
        bestLUTime = elapsed
        luStats = currentStats
        decomposition = currentDecomposition

    var luError = 0.0
    let luClassicCheckTime = measuredSeconds:
      luError = maxError(
        a, classicMultiply(decomposition.l, decomposition.u, n))

    var luVerified = false
    var luVerifyRng = initRand(4000 + n + cutoff)
    let luFreivaldsTime = measuredSeconds:
      luVerified = verifyLUFreivalds(
        a, decomposition.l, decomposition.u, n, 10, luVerifyRng)

    csv.add(csvRow(n, cutoff, "lu_binet", bestLUTime,
      luStats, luError, luClassicCheckTime,
      luFreivaldsTime, luVerified))

  echo "n=", n, " zakonczone"

writeFile(outputPath, csv)
echo "Zapisano ", outputPath
