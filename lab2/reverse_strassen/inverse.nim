
import ../strassen/strassen

# Dodawanie dwoch macierzy.
proc add(a, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] + b[i, j]
      s.adds += 1


# Odejmowanie dwoch macierzy.
proc subtract(a, b: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] - b[i, j]
      s.subs += 1


# Zmiana znakow elementow macierzy.
proc negative(a: Matrix, s: var Stats): Matrix =
  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = 0.0 - a[i, j]
      s.subs += 1


# Wstawienie bloku do macierzy wynikowej.
proc putBlock(c, part: Matrix, row, col: int) =
  for i in 0..<part.rows:
    for j in 0..<part.cols:
      c[row + i, col + j] = part[i, j]


# Rekurencyjne odwracanie macierzy.
proc inverseStrassen*(a: Matrix, cutoff: int,
                      s: var Stats): Matrix =

  if a.rows != a.cols:
    raise newException(ValueError, "Macierz musi byc kwadratowa")

  if cutoff < 1:
    raise newException(ValueError, "Niepoprawny cutoff")

  let n = a.rows

  # Przypadek podstawowy: macierz 1x1.
  if n == 1:
    if abs(a[0, 0]) < 1e-12:
      raise newException(ValueError, "Zerowy lub zbyt maly pivot")

    result = newMatrix(1, 1)
    result[0, 0] = 1.0 / a[0, 0]
    s.divs += 1
    return

  # Podzial macierzy na cztery bloki.
  let h = n div 2
  let r = n - h

  let a11 = view(a, 0, 0, h, h)
  let a12 = view(a, 0, h, h, r)
  let a21 = view(a, h, 0, r, h)
  let a22 = view(a, h, h, r, r)

  # KROK 1: Odwrotnosc pierwszego bloku.
  let e = inverseStrassen(a11, cutoff, s)

  # KROK 2: Wyniki pomocnicze.
  let t = multiplyStrassen(e, a12, cutoff, s)
  let v = multiplyStrassen(a21, e, cutoff, s)

  # KROK 3: Dopelnienie Schura.
  let schurPart = multiplyStrassen(a21, t, cutoff, s)
  let schur = subtract(a22, schurPart, s)

  # KROK 4: Odwrotnosc dopelnienia Schura.
  let q = inverseStrassen(schur, cutoff, s)

  # KROK 5: Obliczenie blokow wyniku.
  let u = multiplyStrassen(t, q, cutoff, s)
  let w = multiplyStrassen(q, v, cutoff, s)

  let correction = multiplyStrassen(u, v, cutoff, s)

  let c11 = add(e, correction, s)
  let c12 = negative(u, s)
  let c21 = negative(w, s)

  # KROK 6: Zlozenie macierzy odwrotnej.
  result = newMatrix(n, n)

  putBlock(result, c11, 0, 0)
  putBlock(result, c12, 0, h)
  putBlock(result, c21, h, 0)
  putBlock(result, q, h, h)
