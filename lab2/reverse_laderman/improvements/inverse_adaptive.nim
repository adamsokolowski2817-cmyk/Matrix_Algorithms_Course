import ../../laderman/laderman
import split_strategy

# Dodawanie macierzy.
proc add(a, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] + b[i, j]
      s.adds += 1


# Odejmowanie macierzy.
proc subtract(a, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] - b[i, j]
      s.subs += 1


# Zmiana znakow.
proc negative(a: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = 0.0 - a[i, j]
      s.subs += 1


# Wstawianie fragmentu macierzy.
proc putBlock(c, part: Matrix, row, col: int) =
  for i in 0..<part.rows:
    for j in 0..<part.cols:
      c[row + i, col + j] = part[i, j]


# Rekurencyjne odwracanie z adaptacyjnym podzialem.
proc inverseLadermanAdaptive*(a: Matrix, cutoff: int,
                              s: var Stats): Matrix =

  if a.rows != a.cols or cutoff < 1:
    raise newException(ValueError, "Niepoprawne parametry")

  let n = a.rows

  # Przypadek podstawowy 1x1.
  if n == 1:
    if abs(a[0, 0]) < 1e-12:
      raise newException(ValueError, "Zerowy lub zbyt maly pivot")

    result = newMatrix(1, 1)
    result[0, 0] = 1.0 / a[0, 0]
    s.divs += 1
    return

  # KROK 1: Adaptacyjny podzial macierzy.
  let h = splitPoint(n, smDivisibleBy3)
  let r = n - h

  let a11 = view(a, 0, 0, h, h)
  let a12 = view(a, 0, h, h, r)
  let a21 = view(a, h, 0, r, h)
  let a22 = view(a, h, h, r, r)

  # KROK 2: Odwracamy pierwszy blok.
  let e = inverseLadermanAdaptive(a11, cutoff, s)

  # KROK 3: Wyniki pomocnicze.
  let t = multiplyLaderman(e, a12, cutoff, s)
  let v = multiplyLaderman(a21, e, cutoff, s)

  # KROK 4: Dopelnienie Schura.
  let schurPart = multiplyLaderman(a21, t, cutoff, s)
  let schur = subtract(a22, schurPart, s)

  # KROK 5: Odwracamy dopelnienie Schura.
  let q = inverseLadermanAdaptive(schur, cutoff, s)

  # KROK 6: Obliczamy bloki odwrotnosci.
  let u = multiplyLaderman(t, q, cutoff, s)
  let w = multiplyLaderman(q, v, cutoff, s)
  let correction = multiplyLaderman(u, v, cutoff, s)

  let c11 = add(e, correction, s)
  let c12 = negative(u, s)
  let c21 = negative(w, s)

  # KROK 7: Skladamy macierz odwrotna.
  result = newMatrix(n, n)

  putBlock(result, c11, 0, 0)
  putBlock(result, c12, 0, h)
  putBlock(result, c21, h, 0)
  putBlock(result, q, h, h)
