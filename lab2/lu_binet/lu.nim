import ../binet/binet

const pivotTolerance = 1.0e-12


proc getBlock(a: seq[float64], n, row, col, rows, cols: int): seq[float64] =
  result = newSeq[float64](rows * cols)

  for i in 0..<rows:
    for j in 0..<cols:
      result[i * cols + j] = a[(row + i) * n + col + j]


proc putBlock(a: var seq[float64], n, row, col, rows, cols: int,
              part: seq[float64]) =
  for i in 0..<rows:
    for j in 0..<cols:
      a[(row + i) * n + col + j] = part[i * cols + j]


proc subtract(a, b: seq[float64], s: var Stats): seq[float64] =
  result = newSeq[float64](a.len)

  for i in 0..<a.len:
    result[i] = a[i] - b[i]
    s.subs += 1


# Klasyczny rozklad Doolittle'a: L ma jedynki na przekatnej.
# Nie wykonujemy pivotingu, tak samo jak w wariancie rekurencyjnym.
proc luClassic(a: seq[float64], n: int,
               s: var Stats): tuple[l, u: seq[float64]] =
  result.l = newSeq[float64](n * n)
  result.u = newSeq[float64](n * n)

  for i in 0..<n:
    result.l[i * n + i] = 1.0

    # U[i,j] = A[i,j] - suma(L[i,k] * U[k,j])
    for j in i..<n:
      var value = a[i * n + j]

      for k in 0..<i:
        value -= result.l[i * n + k] * result.u[k * n + j]
        s.muls += 1
        s.subs += 1

      result.u[i * n + j] = value

    if abs(result.u[i * n + i]) < pivotTolerance:
      raise newException(ValueError,
        "Zerowy lub zbyt maly pivot; LU bez pivotingu przerwane")

    # L[j,i] = (A[j,i] - suma(L[j,k] * U[k,i])) / U[i,i]
    for j in (i + 1)..<n:
      var value = a[j * n + i]

      for k in 0..<i:
        value -= result.l[j * n + k] * result.u[k * n + i]
        s.muls += 1
        s.subs += 1

      result.l[j * n + i] = value / result.u[i * n + i]
      s.divs += 1


# Odwrotnosc macierzy dolnotrojkatnej z jedynkami na przekatnej.
proc inverseLower(a: seq[float64], n: int,
                  s: var Stats): seq[float64] =
  result = newSeq[float64](n * n)

  for col in 0..<n:
    for i in 0..<n:
      var value = (if i == col: 1.0 else: 0.0)

      for k in 0..<i:
        value -= a[i * n + k] * result[k * n + col]
        s.muls += 1
        s.subs += 1

      result[i * n + col] = value


# Odwrotnosc macierzy gornotrojkatnej.
proc inverseUpper(a: seq[float64], n: int,
                  s: var Stats): seq[float64] =
  result = newSeq[float64](n * n)

  for col in 0..<n:
    for i in countdown(n - 1, 0):
      var value = (if i == col: 1.0 else: 0.0)

      for k in (i + 1)..<n:
        value -= a[i * n + k] * result[k * n + col]
        s.muls += 1
        s.subs += 1

      if abs(a[i * n + i]) < pivotTolerance:
        raise newException(ValueError,
          "Zerowy lub zbyt maly pivot; LU bez pivotingu przerwane")

      result[i * n + col] = value / a[i * n + i]
      s.divs += 1


# Rekurencyjny rozklad LU z dopelnieniem Schura.
proc luBinet*(a: seq[float64], n, cutoff: int,
              s: var Stats): tuple[l, u: seq[float64]] =
  if n < 1 or cutoff < 1 or a.len != n * n:
    raise newException(ValueError, "Niepoprawne parametry LU")

  # Cutoff konczy rekurencje samego rozkladu LU.
  if n <= cutoff:
    return luClassic(a, n, s)

  let
    h = n div 2
    r = n - h
    a11 = getBlock(a, n, 0, 0, h, h)
    a12 = getBlock(a, n, 0, h, h, r)
    a21 = getBlock(a, n, h, 0, r, h)
    a22 = getBlock(a, n, h, h, r, r)

  # A11 = L11*U11
  let first = luBinet(a11, h, cutoff, s)

  # U12 = L11^(-1)*A12 oraz L21 = A21*U11^(-1).
  # To celowo jest prosty wariant z jawnymi odwrotnosciami,
  # analogiczny do podstawowego LU Strassena w repozytorium.
  let lInverse = inverseLower(first.l, h, s)
  let uInverse = inverseUpper(first.u, h, s)
  let u12 = binetRect(lInverse, a12, h, h, r, cutoff, s)
  let l21 = binetRect(a21, uInverse, r, h, h, cutoff, s)

  # S = A22 - L21*U12
  let product = binetRect(l21, u12, r, h, r, cutoff, s)
  let schur = subtract(a22, product, s)
  let second = luBinet(schur, r, cutoff, s)

  result.l = newSeq[float64](n * n)
  result.u = newSeq[float64](n * n)

  putBlock(result.l, n, 0, 0, h, h, first.l)
  putBlock(result.l, n, h, 0, r, h, l21)
  putBlock(result.l, n, h, h, r, r, second.l)

  putBlock(result.u, n, 0, 0, h, h, first.u)
  putBlock(result.u, n, 0, h, h, r, u12)
  putBlock(result.u, n, h, h, r, r, second.u)
