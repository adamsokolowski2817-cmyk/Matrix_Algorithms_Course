import std/[math, random]


# Proste mnozenie macierzy przez wektor.
# Freivalds nie tworzy pelnego iloczynu dwoch macierzy.
proc multiplyMatrixVector*(a, x: seq[float64], n: int): seq[float64] =
  if a.len != n * n or x.len != n:
    raise newException(ValueError, "Niepoprawne wymiary macierzy lub wektora")

  result = newSeq[float64](n)

  for i in 0..<n:
    for j in 0..<n:
      result[i] += a[i * n + j] * x[j]


proc randomBinaryVector(n: int, rng: var Rand): seq[float64] =
  result = newSeq[float64](n)

  for i in 0..<n:
    result[i] = float64(rand(rng, 1))


# Tolerancja jest wzgledna wobec skali porownywanych wartosci.
proc vectorsClose(a, b: seq[float64], tolerance: float64): bool =
  for i in 0..<a.len:
    if classify(a[i]) in {fcNan, fcInf, fcNegInf} or
       classify(b[i]) in {fcNan, fcInf, fcNegInf}:
      return false

    let scale = max(1.0, max(abs(a[i]), abs(b[i])))

    if abs(a[i] - b[i]) > tolerance * scale:
      return false

  return true


# Sprawdzamy L*(U*r) ~= A*r.
# Wynik jest probabilistyczny, bo losowy wektor moze nie ujawnic bledu.
# Dla float64 klasyczna granica prawdopodobienstwa z arytmetyki dokladnej
# nie jest gwarancja: na wynik wplywaja tez bledy zaokraglen.
proc verifyLUFreivalds*(a, l, u: seq[float64], n, trials: int,
                        rng: var Rand,
                        tolerance = 1.0e-10): bool =
  if n < 1 or trials < 1 or a.len != n * n or
     l.len != n * n or u.len != n * n:
    raise newException(ValueError, "Niepoprawne parametry testu Freivaldsa")

  for trial in 0..<trials:
    let randomVector = randomBinaryVector(n, rng)
    let rightSide = multiplyMatrixVector(a, randomVector, n)
    let upperProduct = multiplyMatrixVector(u, randomVector, n)
    let leftSide = multiplyMatrixVector(l, upperProduct, n)

    if not vectorsClose(leftSide, rightSide, tolerance):
      return false

  return true


# Sprawdzamy A*(A^(-1)*r) ~= r.
proc verifyInverseFreivalds*(a, inverse: seq[float64], n, trials: int,
                             rng: var Rand,
                             tolerance = 1.0e-10): bool =
  if n < 1 or trials < 1 or a.len != n * n or inverse.len != n * n:
    raise newException(ValueError, "Niepoprawne parametry testu Freivaldsa")

  for trial in 0..<trials:
    let randomVector = randomBinaryVector(n, rng)
    let inverseProduct = multiplyMatrixVector(inverse, randomVector, n)
    let obtained = multiplyMatrixVector(a, inverseProduct, n)

    if not vectorsClose(obtained, randomVector, tolerance):
      return false

  return true
