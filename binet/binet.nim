type
  # Zliczamy operacje zmiennoprzecinkowe wykonane przez algorytm.
  # Binet tylko mnozy i dodaje, wiec subs i divs zostaja zerami.
  Stats* = object
    adds*, subs*, muls*, divs*: int64

proc flops*(s: Stats): int64 =
  s.adds + s.subs + s.muls + s.divs

proc multiplyBlock(
  A, B: seq[float64],
  C: var seq[float64],
  aStart, bStart, cStart: int,
  rows, inner, cols, stride, cutoff: int,
  accumulate: bool,
  s: var Stats
) =
  # Maly blok: zwykle mnozenie, petle i-k-j.
  # Pierwszy skladnik tylko wpisujemy (1 mnozenie).
  # Kazdy nastepny dopisujemy (1 mnozenie i 1 dodawanie).
  if min(rows, min(inner, cols)) <= cutoff:
    for i in 0..<rows:
      let aRow = aStart + i * stride
      let cRow = cStart + i * stride
      var k0 = 0

      if not accumulate:
        let aValue = A[aRow]
        let bRow = bStart
        for j in 0..<cols:
          C[cRow + j] = aValue * B[bRow + j]
        k0 = 1

      for k in k0..<inner:
        let aValue = A[aRow + k]
        let bRow = bStart + k * stride
        for j in 0..<cols:
          C[cRow + j] += aValue * B[bRow + j]

    let cells = int64(rows) * int64(cols)
    s.muls += cells * int64(inner)
    if accumulate:
      s.adds += cells * int64(inner)
    else:
      s.adds += cells * int64(inner - 1)
    return

  # Kazdy wymiar na polowe i ewentualna reszte, bez dopisywania zer.
  let
    r1 = rows div 2
    r2 = rows - r1
    k1 = inner div 2
    k2 = inner - k1
    c1 = cols div 2
    c2 = cols - c1

  # Poczatek kazdego bloku w jednej wspolnej tablicy.
  let
    aLU = aStart
    aRU = aStart + k1
    aLD = aStart + r1 * stride
    aRD = aLD + k1
    bLU = bStart
    bRU = bStart + c1
    bLD = bStart + k1 * stride
    bRD = bLD + c1
    cLU = cStart
    cRU = cStart + c1
    cLD = cStart + r1 * stride
    cRD = cLD + c1

  # C11 = A11*B11 + A12*B21
  multiplyBlock(A, B, C, aLU, bLU, cLU, r1, k1, c1, stride, cutoff, accumulate, s)
  multiplyBlock(A, B, C, aRU, bLD, cLU, r1, k2, c1, stride, cutoff, true, s)

  # C12 = A11*B12 + A12*B22
  multiplyBlock(A, B, C, aLU, bRU, cRU, r1, k1, c2, stride, cutoff, accumulate, s)
  multiplyBlock(A, B, C, aRU, bRD, cRU, r1, k2, c2, stride, cutoff, true, s)

  # C21 = A21*B11 + A22*B21
  multiplyBlock(A, B, C, aLD, bLU, cLD, r2, k1, c1, stride, cutoff, accumulate, s)
  multiplyBlock(A, B, C, aRD, bLD, cLD, r2, k2, c1, stride, cutoff, true, s)

  # C22 = A21*B12 + A22*B22
  multiplyBlock(A, B, C, aLD, bRU, cRD, r2, k1, c2, stride, cutoff, accumulate, s)
  multiplyBlock(A, B, C, aRD, bRD, cRD, r2, k2, c2, stride, cutoff, true, s)

proc binet*(A, B: seq[float64], n, cutoff: int, s: var Stats): seq[float64] =
  if n < 1 or cutoff < 1 or A.len != n * n or B.len != n * n:
    raise newException(ValueError, "Niepoprawne dane macierzy")

  result = newSeq[float64](n * n)
  multiplyBlock(A, B, result, 0, 0, 0, n, n, n, n, cutoff, false, s)
