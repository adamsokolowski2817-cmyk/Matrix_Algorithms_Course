
import std/random
import laderman



# TEST 1: OPTYMALIZACJA PAMIECI PRZEZ WIDOKI

proc testViews() =

  let a = newMatrix(6, 6)
  let v = view(a, 1, 1, 3, 3)

  # Zmiana przez widok modyfikuje oryginalna macierz.
  v[0, 0] = 42.0
  doAssert a[1, 1] == 42.0

  # Zmiana oryginalnej macierzy modyfikuje widok.
  a[3, 3] = 18.0
  doAssert v[2, 2] == 18.0

  # Widok utworzony z innego widoku.
  let nested = view(v, 1, 1, 2, 2)
  nested[0, 0] = 25.0

  doAssert a[2, 2] == 25.0

  echo "OK - optymalizacja pamieci przez widoki"



# TEST 2: PODSTAWOWE MNOZENIE 3x3

proc testSimple() =

  let a = newMatrix(3, 3)
  let b = newMatrix(3, 3)

  let valuesA = [
    [1.0, 2.0, 3.0],
    [4.0, 5.0, 6.0],
    [7.0, 8.0, 9.0]
  ]

  let valuesB = [
    [9.0, 8.0, 7.0],
    [6.0, 5.0, 4.0],
    [3.0, 2.0, 1.0]
  ]

  for i in 0..<3:
    for j in 0..<3:
      a[i, j] = valuesA[i][j]
      b[i, j] = valuesB[i][j]

  var s: Stats
  let c = multiplyLaderman(a, b, 1, s)

  # Oczekiwany wynik:
  # 30   24   18
  # 84   69   54
  # 138  114  90

  let expected = [
    [30.0, 24.0, 18.0],
    [84.0, 69.0, 54.0],
    [138.0, 114.0, 90.0]
  ]

  for i in 0..<3:
    for j in 0..<3:
      doAssert abs(c[i, j] - expected[i][j]) < 1e-10

  # Laderman wykonuje 23 mnozenia skalarne.
  doAssert s.muls == 23

  echo "OK - mnozenie Ladermana 3x3"



# TEST 3: MACIERZE O DOWOLNYCH ROZMIARACH

proc testAllSizes() =

  var tests = 0

  # A ma wymiary n x k.
  # B ma wymiary k x p.
  for n in 1..9:
    for k in 1..9:
      for p in 1..9:

        let a = randomMatrix(n, k)
        let b = randomMatrix(k, p)

        let expected = classicMultiply(a, b)

        for cutoff in [1, 2, 4]:

          var s: Stats
          let c = multiplyLaderman(a, b, cutoff, s)

          doAssert c.rows == n
          doAssert c.cols == p

          # Wynik musi zgadzac sie z klasycznym mnozeniem.
          doAssert maxError(c, expected) < 1e-8

          doAssert s.muls > 0

          tests += 1

  echo "OK - dowolne rozmiary: ", tests, " testow"



# TEST 4: WIEKSZE MACIERZE

proc testLarge() =

  # Rozmiary podzielne i niepodzielne przez 3.
  for n in [12, 13, 24, 27, 28, 32, 64]:

    let a = randomMatrix(n, n)
    let b = randomMatrix(n, n)

    let expected = classicMultiply(a, b)

    var s: Stats
    let c = multiplyLaderman(a, b, 4, s)

    doAssert maxError(c, expected) < 1e-8

  echo "OK - wieksze macierze"



# TEST 5: LICZNIKI FLOP

proc testFlops() =

  let a = randomMatrix(3, 3)
  let b = randomMatrix(3, 3)

  # Pelny Laderman dla macierzy 3x3.
  var s: Stats
  discard multiplyLaderman(a, b, 1, s)

  doAssert s.muls == 23
  doAssert flops(s) == 121

  # Klasyczne mnozenie 3x3.
  var classicStats: Stats
  discard multiplyLaderman(a, b, 3, classicStats)

  # 27 mnozen + 18 dodawan.
  doAssert classicStats.muls == 27
  doAssert classicStats.adds == 18
  doAssert flops(classicStats) == 45

  # Laderman dla rozmiaru niepodzielnego przez 3.
  let a5 = randomMatrix(5, 5)
  let b5 = randomMatrix(5, 5)

  var s5: Stats
  discard multiplyLaderman(a5, b5, 1, s5)

  doAssert s5.muls == 121
  doAssert flops(s5) == 301

  echo "OK - liczniki FLOP"



# TEST 6: MNOZENIE PRZEZ SKALAR

proc testScalar() =

  let a = randomMatrix(3, 3)

  var s: Stats
  let b = multiplyScalar(a, 3.0, s)

  for i in 0..<3:
    for j in 0..<3:
      doAssert abs(b[i, j] - 3.0 * a[i, j]) < 1e-12

  doAssert s.muls == 9

  doAssert multiplyScalars(3.0, 4.0, s) == 12.0
  doAssert s.muls == 10

  echo "OK - mnozenie przez skalar"



# TEST 7: BLEDNE DANE WEJSCIOWE

proc testInvalid() =

  let a = newMatrix(2, 3)
  let b = newMatrix(4, 2)

  var s: Stats
  var caught = false

  # Niezgodne wymiary mnozonych macierzy.
  try:
    discard multiplyLaderman(a, b, 1, s)
  except ValueError:
    caught = true

  doAssert caught

  # Niepoprawny prog rekurencji.
  caught = false

  try:
    discard multiplyLaderman(a, newMatrix(3, 2), 0, s)
  except ValueError:
    caught = true

  doAssert caught

  # Niepoprawny widok macierzy.
  caught = false

  try:
    discard view(a, 0, 0, 5, 5)
  except ValueError:
    caught = true

  doAssert caught

  echo "OK - bledne dane wejsciowe"



# TEST 8: DANE LOSOWE I MACIERZE WEJSCIOWE

proc testInput() =

  let a = randomMatrix(9, 9)
  let b = randomMatrix(9, 9)

  # Sprawdzenie przedzialu losowanych wartosci.
  for i in 0..<9:
    for j in 0..<9:
      doAssert a[i, j] > 1e-8
      doAssert a[i, j] < 1.0

  let oldA = a[0, 0]
  let oldB = b[4, 5]

  var s: Stats
  discard multiplyLaderman(a, b, 1, s)

  # Mnozenie nie powinno modyfikowac danych wejsciowych.
  doAssert a[0, 0] == oldA
  doAssert b[4, 5] == oldB

  echo "OK - dane losowe i macierze wejsciowe"



# TEST 9: MACIERZE Z LICZBAMI UJEMNYMI I ZERAMI

proc testNegative() =

  let a = newMatrix(6, 9)
  let b = newMatrix(9, 3)

  # Tworzymy dane zawierajace liczby ujemne i zera.
  for i in 0..<a.rows:
    for j in 0..<a.cols:
      a[i, j] = float64((i + j) mod 5 - 2)

  for i in 0..<b.rows:
    for j in 0..<b.cols:
      b[i, j] = float64((i * 2 + j) mod 7 - 3)

  let expected = classicMultiply(a, b)

  var s: Stats
  let c = multiplyLaderman(a, b, 1, s)

  doAssert maxError(c, expected) < 1e-10

  echo "OK - liczby ujemne i zera"



# URUCHOMIENIE WSZYSTKICH TESTOW

when isMainModule:

  randomize(2026)

  testViews()
  testSimple()
  testAllSizes()
  testLarge()
  testFlops()
  testScalar()
  testInvalid()
  testInput()
  testNegative()

  echo ""
  echo "WSZYSTKIE TESTY LADERMANA ZAKONCZONE POMYSLNIE"
