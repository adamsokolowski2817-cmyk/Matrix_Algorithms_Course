import ../binet/binet

const pivotTolerance = 1.0e-12


# Wycinanie prostokatnego bloku z macierzy zapisanej wierszami.
proc getBlock(a: seq[float64], n, row, col, rows, cols: int): seq[float64] =
  result = newSeq[float64](rows * cols)

  for i in 0..<rows:
    for j in 0..<cols:
      result[i * cols + j] = a[(row + i) * n + col + j]


# Wstawianie bloku do macierzy wynikowej.
proc putBlock(a: var seq[float64], n, row, col, rows, cols: int,
              part: seq[float64]) =
  for i in 0..<rows:
    for j in 0..<cols:
      a[(row + i) * n + col + j] = part[i * cols + j]


proc add(a, b: seq[float64], s: var Stats): seq[float64] =
  result = newSeq[float64](a.len)

  for i in 0..<a.len:
    result[i] = a[i] + b[i]
    s.adds += 1


proc subtract(a, b: seq[float64], s: var Stats): seq[float64] =
  result = newSeq[float64](a.len)

  for i in 0..<a.len:
    result[i] = a[i] - b[i]
    s.subs += 1


proc negative(a: seq[float64], s: var Stats): seq[float64] =
  result = newSeq[float64](a.len)

  for i in 0..<a.len:
    result[i] = 0.0 - a[i]
    s.subs += 1


# Klasyczne odwracanie metoda Gaussa-Jordana bez wyboru elementu glownego.
# Ta sama konwencja obowiazuje w czesci rekurencyjnej: zbyt maly pivot
# oznacza, ze algorytm bez pivotingu nie moze kontynuowac.
proc inverseClassic(a: seq[float64], n: int,
                    s: var Stats): seq[float64] =
  var left = a
  result = newSeq[float64](n * n)

  for i in 0..<n:
    result[i * n + i] = 1.0

  for pivotIndex in 0..<n:
    let pivot = left[pivotIndex * n + pivotIndex]

    if abs(pivot) < pivotTolerance:
      raise newException(ValueError,
        "Zerowy lub zbyt maly pivot; odwracanie bez pivotingu przerwane")

    # Dzielimy caly wiersz przez pivot.
    for j in 0..<n:
      left[pivotIndex * n + j] /= pivot
      result[pivotIndex * n + j] /= pivot
      s.divs += 2

    # Zerujemy kolumne pivotu w pozostalych wierszach.
    for i in 0..<n:
      if i != pivotIndex:
        let factor = left[i * n + pivotIndex]

        for j in 0..<n:
          left[i * n + j] -= factor * left[pivotIndex * n + j]
          result[i * n + j] -= factor * result[pivotIndex * n + j]
          s.muls += 2
          s.subs += 2


# Rekurencyjne odwracanie z dopelnieniem Schura.
proc inverseBinet*(a: seq[float64], n, cutoff: int,
                   s: var Stats): seq[float64] =
  if n < 1 or cutoff < 1 or a.len != n * n:
    raise newException(ValueError, "Niepoprawne parametry odwracania")

  # Cutoff konczy rekurencje samego odwracania.
  if n <= cutoff:
    return inverseClassic(a, n, s)

  let
    h = n div 2
    r = n - h
    a11 = getBlock(a, n, 0, 0, h, h)
    a12 = getBlock(a, n, 0, h, h, r)
    a21 = getBlock(a, n, h, 0, r, h)
    a22 = getBlock(a, n, h, h, r, r)

  # E = A11^(-1)
  let e = inverseBinet(a11, h, cutoff, s)

  # T = E*A12, V = A21*E
  let t = binetRect(e, a12, h, h, r, cutoff, s)
  let v = binetRect(a21, e, r, h, h, cutoff, s)

  # S = A22 - A21*A11^(-1)*A12 = A22 - A21*T
  let schurPart = binetRect(a21, t, r, h, r, cutoff, s)
  let schur = subtract(a22, schurPart, s)
  let q = inverseBinet(schur, r, cutoff, s)

  # A^(-1) = [E + T*Q*V  -T*Q]
  #           [   -Q*V       Q  ]
  let u = binetRect(t, q, h, r, r, cutoff, s)
  let w = binetRect(q, v, r, r, h, cutoff, s)
  let correction = binetRect(u, v, h, r, h, cutoff, s)

  let c11 = add(e, correction, s)
  let c12 = negative(u, s)
  let c21 = negative(w, s)

  result = newSeq[float64](n * n)
  putBlock(result, n, 0, 0, h, h, c11)
  putBlock(result, n, 0, h, h, r, c12)
  putBlock(result, n, h, 0, r, h, c21)
  putBlock(result, n, h, h, r, r, q)
