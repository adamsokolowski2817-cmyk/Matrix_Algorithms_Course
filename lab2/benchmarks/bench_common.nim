import std/[os, strutils, algorithm, monotimes, times]

# Odczyt parametru z terminala lub wartosci domyslnej.
proc cliInt*(position, defaultValue: int): int =
  if paramCount() >= position:
    result = parseInt(paramStr(position))
  else:
    result = defaultValue


# Pomiar czasu podobny do Labu 1.
# Dla malych macierzy automatycznie zwiekszamy
# liczbe obliczen w jednej serii.
template measureBatched*(repeats: int, operation: untyped): float64 =
  block:
    var durations: seq[float64] = @[]
    var batch = 1

    for rep in 0..<repeats:
      var elapsed = 0.0

      while true:
        let startTime = getMonoTime()

        for k in 0..<batch:
          operation

        elapsed = float64(
          (getMonoTime() - startTime).inNanoseconds
        ) / 1e9

        # Pomiar minimum 10 ms.
        if elapsed >= 0.01 or batch >= 65536:
          break

        batch *= 2

      durations.add(elapsed / float64(batch))

    # Mediana czasu jednego wykonania.
    durations.sort()
    durations[durations.len div 2]
