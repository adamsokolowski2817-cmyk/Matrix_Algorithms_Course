import ../../strassen/strassen


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


# Rozwiazuje L * X = B.
# L jest dolnotrojkatna z jedynkami na przekatnej.
proc solveLower(l, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(b.rows, b.cols)

  for i in 0..<b.rows:
    for j in 0..<b.cols:
      var value = b[i, j]

      for k in 0..<i:
        value -= l[i, k] * result[k, j]
        s.muls += 1
        s.subs += 1

      # Nie dzielimy przez L[i,i], bo wynosi 1.
      result[i, j] = value


# Rozwiazuje X * U = B.
# U jest gornotrojkatna.
proc solveRightUpper(b, u: Matrix, s: var Stats): Matrix =
  result = newMatrix(b.rows, b.cols)

  for i in 0..<b.rows:
    for j in 0..<b.cols:
      var value = b[i, j]

      for k in 0..<j:
        value -= result[i, k] * u[k, j]
        s.muls += 1
        s.subs += 1

      if abs(u[j, j]) < 1e-12:
        raise newException(ValueError, "Zerowy pivot")

      result[i, j] = value / u[j, j]
      s.divs += 1


# Rekurencyjna faktoryzacja LU bez jawnych odwrotnosci.
proc luStrassenTriangular*(a: Matrix, cutoff: int,
                           s: var Stats): tuple[l, u: Matrix] =

  if a.rows != a.cols or a.rows < 1 or cutoff < 1:
    raise newException(ValueError, "Niepoprawne parametry")

  let n = a.rows

  # Przypadek podstawowy.
  if n == 1:
    if abs(a[0, 0]) < 1e-12:
      raise newException(ValueError, "Zerowy pivot")

    result.l = newMatrix(1, 1)
    result.u = newMatrix(1, 1)

    result.l[0, 0] = 1.0
    result.u[0, 0] = a[0, 0]
    return

  # KROK 1: Podzial macierzy.
  let h = n div 2
  let r = n - h

  let a11 = view(a, 0, 0, h, h)
  let a12 = view(a, 0, h, h, r)
  let a21 = view(a, h, 0, r, h)
  let a22 = view(a, h, h, r, r)

  # KROK 2: LU dla pierwszego bloku.
  let first = luStrassenTriangular(a11, cutoff, s)

  # KROK 3: Rozwiazujemy uklady trojkatne.
  let u12 = solveLower(first.l, a12, s)
  let l21 = solveRightUpper(a21, first.u, s)

  # KROK 4: Dopelnienie Schura - mnozenie Strassena.
  let product = multiplyStrassen(l21, u12, cutoff, s)
  let schur = subtract(a22, product, s)

  # KROK 5: LU dla dopelnienia Schura.
  let second = luStrassenTriangular(schur, cutoff, s)

  # KROK 6: Skladamy macierze L i U.
  result.l = newMatrix(n, n)
  result.u = newMatrix(n, n)

  putBlock(result.l, first.l, 0, 0)
  putBlock(result.l, l21, h, 0)
  putBlock(result.l, second.l, h, h)

  putBlock(result.u, first.u, 0, 0)
  putBlock(result.u, u12, 0, h)
  putBlock(result.u, second.u, h, h)
