import ../../strassen/strassen

# Aktualizacja odwrotnosci po zmianie jednego elementu.
# row, col - pozycja zmienianego elementu
# delta    - wartosc zmiany

proc updateInverseEntry*(invA: Matrix, row, col: int,
                         delta: float64,
                         s: var Stats): Matrix =

  let n = invA.rows

  if invA.rows != invA.cols:
    raise newException(ValueError, "Macierz musi byc kwadratowa")

  if row < 0 or row >= n or col < 0 or col >= n:
    raise newException(ValueError, "Niepoprawny indeks")

  # Mianownik wzoru Shermana-Morrisona.
  let denominator = 1.0 + delta * invA[col, row]
  s.muls += 1
  s.adds += 1

  if abs(denominator) < 1e-12:
    raise newException(ValueError, "Aktualizacja prowadzi do osobliwej macierzy")

  let factor = delta / denominator
  s.divs += 1

  result = newMatrix(n, n)

  # Aktualizacja wszystkich elementow odwrotnosci.
  for i in 0..<n:
    let scaled = factor * invA[i, row]
    s.muls += 1

    for j in 0..<n:
      result[i, j] = invA[i, j] - scaled * invA[col, j]
      s.muls += 1
      s.subs += 1
