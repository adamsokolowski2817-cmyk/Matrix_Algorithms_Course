import ../../strassen/strassen


# Oblicza R = I - A*X i maksymalny blad.
# Do kontroli bledu uzywamy mnozenia klasycznego.
proc calculateResidual(a, x: Matrix,
                       s: var Stats): tuple[r: Matrix, err: float64] =

  let n = a.rows
  let ax = classicMultiply(a, x)

  result.r = newMatrix(n, n)

  # FLOP klasycznego mnozenia macierzy.
  let size = int64(n)
  s.muls += size * size * size
  s.adds += size * size * (size - 1)

  for i in 0..<n:
    for j in 0..<n:
      let expected = (if i == j: 1.0 else: 0.0)
      let value = expected - ax[i, j]

      result.r[i, j] = value
      result.err = max(result.err, abs(value))
      s.subs += 1


# Adaptacyjny Newton-Schulz.
proc newtonSchulzAdaptive*(
    a, x0: Matrix,
    cutoff: int,
    s: var Stats,
    tolerance: float64 = 1e-12,
    maxIterations: int = 5
): tuple[x: Matrix, initialError, finalError: float64,
         iterations: int] =

  if a.rows != a.cols or a.rows < 1 or
     x0.rows != a.rows or x0.cols != a.cols or
     cutoff < 1 or tolerance <= 0.0 or maxIterations < 0:
    raise newException(ValueError, "Niepoprawne parametry")

  let n = a.rows
  result.x = x0

  # 1. Sprawdzenie poczatkowej dokladnosci.
  var current = calculateResidual(a, x0, s)

  result.initialError = current.err
  result.finalError = current.err

  # 2. Kolejne iteracje.
  for k in 0..<maxIterations:

    # Wystarczajaco dokladna odwrotnosc.
    if current.err <= tolerance:
      break

    # X_new = X + X * (I - A*X)
    let correction = multiplyStrassen(
      result.x, current.r, cutoff, s)

    let candidate = newMatrix(n, n)

    for i in 0..<n:
      for j in 0..<n:
        candidate[i, j] = result.x[i, j] + correction[i, j]
        s.adds += 1

    # 3. Niezalezna kontrola nowego przyblizenia.
    let nextResidual = calculateResidual(a, candidate, s)

    # Nie przyjmujemy korekty pogarszajacej blad.
    if not (nextResidual.err < current.err):
      break

    # 4. Akceptujemy lepszy wynik.
    result.x = candidate
    current = nextResidual

    result.finalError = current.err
    result.iterations += 1
