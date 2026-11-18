import std/[os, random, monotimes, times, strutils]
import binet

# nim c -d:release -r main.nim
# opcjonalnie: main.exe maxN step cutoff repeats
# wykresy: gnuplot wykresy.gp

const
  defaultMaxN = 128
  defaultStep = 1
  defaultCutoff = 32
  defaultRepeats = 3

proc paramNum(index, default: int): int =
  if paramCount() >= index: parseInt(paramStr(index)) else: default

proc randomMatrix(n: int): seq[float64] =
  result = newSeq[float64](n * n)
  for i in 0..<result.len:
    result[i] = 0.00000002 + rand(0.99999996)

proc classic(A, B: seq[float64], n: int): seq[float64] =
  result = newSeq[float64](n * n)
  for i in 0..<n:
    for k in 0..<n:
      let aValue = A[i * n + k]
      for j in 0..<n:
        result[i * n + j] += aValue * B[k * n + j]

# Trzy elementy: rog, srodek i koniec. Nie liczymy calej macierzy.
proc sampleError(A, B, C: seq[float64], n: int): float64 =
  for p in [0, n div 2, n - 1]:
    var expected = 0.0
    for k in 0..<n:
      expected += A[p * n + k] * B[k * n + p]
    result = max(result, abs(expected - C[p * n + p]))

proc selfCheck() =
  let A = @[1.0, 2.0, 3.0, 4.0]
  let B = @[5.0, 6.0, 7.0, 8.0]
  var example: Stats
  let C = binet(A, B, 2, 1, example)

  doAssert abs(C[0] - 19.0) < 1e-9
  doAssert abs(C[1] - 22.0) < 1e-9
  doAssert abs(C[2] - 43.0) < 1e-9
  doAssert abs(C[3] - 50.0) < 1e-9
  doAssert example.muls == 8 and example.adds == 4

  for n in 1..8:
    let X = randomMatrix(n)
    let Y = randomMatrix(n)
    var s: Stats
    let got = binet(X, Y, n, 1, s)
    let expected = classic(X, Y, n)

    for i in 0..<got.len:
      doAssert abs(got[i] - expected[i]) < 1e-8

    # Przy zejsciu do 1x1 Binet wykonuje tyle samo FLOP co klasyczne mnozenie.
    doAssert flops(s) == int64(2 * n * n * n - n * n)

  echo "OK - przyklad 2x2 i FLOP dla n = 1..8"

proc benchmark(maxN, step, cutoff, repeats: int) =
  let f = open("binet_results.csv", fmWrite)
  defer: f.close()

  f.writeLine("n,time_s,flops,mul,add,sub,div,gflops,error_sample")

  for n in countup(1, maxN, step):
    let A = randomMatrix(n)
    let B = randomMatrix(n)
    var bestTime = 1.0e100
    var bestStats: Stats
    var bestC: seq[float64]
    var batch = 1

    for rep in 1..repeats:
      var elapsed = 0.0
      var current: Stats
      var currentC: seq[float64]

      while true:
        let start = getMonoTime()
        for t in 1..batch:
          current = Stats()
          currentC = binet(A, B, n, cutoff, current)
        elapsed = float64((getMonoTime() - start).inNanoseconds) / 1e9

        if elapsed >= 0.01 or batch >= 65536:
          break
        batch *= 2

      let avg = elapsed / float64(batch)
      if avg < bestTime:
        bestTime = avg
        bestStats = current
        bestC = currentC

    let operations = flops(bestStats)
    let gflops = float64(operations) / bestTime / 1e9

    f.writeLine(
      $n & "," & $bestTime & "," & $operations & "," &
      $bestStats.muls & "," & $bestStats.adds & "," &
      $bestStats.subs & "," & $bestStats.divs & "," &
      $gflops & "," & $sampleError(A, B, bestC, n)
    )

    if n == 1 or n mod 32 == 0 or n == maxN:
      echo "n=", n, " czas=", bestTime, " s  FLOP=", operations, "  GFLOPS=", gflops

  echo "Zapisano binet_results.csv"

randomize(12345)
selfCheck()
benchmark(
  paramNum(1, defaultMaxN),
  paramNum(2, defaultStep),
  paramNum(3, defaultCutoff),
  paramNum(4, defaultRepeats)
)
