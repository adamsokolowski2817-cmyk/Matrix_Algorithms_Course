import ../strassen/strassen


# Odejmowanie macierzy.
proc subtract(a, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] - b[i, j]
      s.subs += 1


# Wstawianie bloku do macierzy.
proc putBlock(c, part: Matrix, row, col: int) =
  for i in 0..<part.rows:
    for j in 0..<part.cols:
      c[row + i, col + j] = part[i, j]


# Odwrotnosc macierzy dolnotrojkatnej.
proc inverseLower(a: Matrix, s: var Stats): Matrix =
  let n = a.rows
  result = newMatrix(n, n)

  for col in 0..<n:
    for i in 0..<n:
      var value = (if i == col: 1.0 else: 0.0)

      for k in 0..<i:
        value -= a[i, k] * result[k, col]
        s.muls += 1
        s.subs += 1

      result[i, col] = value / a[i, i]
      s.divs += 1


# Odwrotnosc macierzy gornotrojkatnej.
proc inverseUpper(a: Matrix, s: var Stats): Matrix =
  let n = a.rows
  result = newMatrix(n, n)

  for col in 0..<n:
    for i in countdown(n - 1, 0):
      var value = (if i == col: 1.0 else: 0.0)

      for k in (i + 1)..<n:
        value -= a[i, k] * result[k, col]
        s.muls += 1
        s.subs += 1

      if abs(a[i, i]) < 1e-12:
        raise newException(ValueError, "Zerowy pivot")

      result[i, col] = value / a[i, i]
      s.divs += 1


# Rekurencyjna faktoryzacja LU.
proc luStrassen*(a: Matrix, cutoff: int,
                 s: var Stats): tuple[l, u: Matrix] =

  if a.rows != a.cols or a.rows < 1 or cutoff < 1:
    raise newException(ValueError, "Niepoprawne parametry")

  let n = a.rows

  # Przypadek podstawowy: macierz 1x1.
  if n == 1:
    if abs(a[0, 0]) < 1e-12:
      raise newException(ValueError, "Zerowy pivot")

    result.l = newMatrix(1, 1)
    result.u = newMatrix(1, 1)

    result.l[0, 0] = 1.0
    result.u[0, 0] = a[0, 0]
    return

  # KROK 1: Podzial na cztery bloki.
  let h = n div 2
  let r = n - h

  let a11 = view(a, 0, 0, h, h)
  let a12 = view(a, 0, h, h, r)
  let a21 = view(a, h, 0, r, h)
  let a22 = view(a, h, h, r, r)

  # KROK 2: Rekurencyjne LU dla A11.
  let first = luStrassen(a11, cutoff, s)

  let l11 = first.l
  let u11 = first.u

  # KROK 3: Odwrotnosci blokow trojkatnych.
  let lInv = inverseLower(l11, s)
  let uInv = inverseUpper(u11, s)

  # KROK 4: Pozostale bloki L i U.
  let u12 = multiplyStrassen(lInv, a12, cutoff, s)
  let l21 = multiplyStrassen(a21, uInv, cutoff, s)

  # KROK 5: Dopelnienie Schura.
  let product = multiplyStrassen(l21, u12, cutoff, s)
  let schur = subtract(a22, product, s)

  # KROK 6: Rekurencyjne LU dla Schura.
  let second = luStrassen(schur, cutoff, s)

  # KROK 7: Skladamy wynik.
  result.l = newMatrix(n, n)
  result.u = newMatrix(n, n)

  putBlock(result.l, l11, 0, 0)
  putBlock(result.l, l21, h, 0)
  putBlock(result.l, second.l, h, h)

  putBlock(result.u, u11, 0, 0)
  putBlock(result.u, u12, 0, h)
  putBlock(result.u, second.u, h, h)
