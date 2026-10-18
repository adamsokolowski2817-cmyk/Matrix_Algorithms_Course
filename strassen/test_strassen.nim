
import std/random
import strassen



# TEST 1: OPTYMALIZACJA PAMIECI PRZEZ WIDOKI

proc testViews() =

  let a = newMatrix(4, 4)
  let v = view(a, 1, 1, 2, 2)

  # Zmiana przez widok powinna zmienic oryginalna macierz.
  v[0, 0] = 42.0
  doAssert a[1, 1] == 42.0

  # Zmiana oryginalnej macierzy powinna zmienic widok.
  a[2, 2] = 18.0
  doAssert v[1, 1] == 18.0

  # Sprawdzamy widok utworzony z innego widoku.
  let nested = view(v, 1, 1, 1, 1)
  nested[0, 0] = 25.0

  doAssert a[2, 2] == 25.0

  echo "OK - optymalizacja pamieci przez widoki"



# TEST 2: PROSTE MNOZENIE 2x2

proc testSimple() =

  let a = newMatrix(2, 2)
  let b = newMatrix(2, 2)

  a[0, 0] = 1.0
  a[0, 1] = 2.0
  a[1, 0] = 3.0
  a[1, 1] = 4.0

  b[0, 0] = 5.0
  b[0, 1] = 6.0
  b[1, 0] = 7.0
  b[1, 1] = 8.0

  var s: Stats
  let c = multiplyStrassen(a, b, 1, s)

  # Oczekiwany wynik:
  # 19 22
  # 43 50

  doAssert abs(c[0, 0] - 19.0) < 1e-10
  doAssert abs(c[0, 1] - 22.0) < 1e-10
  doAssert abs(c[1, 0] - 43.0) < 1e-10
  doAssert abs(c[1, 1] - 50.0) < 1e-10

  # 7 mnozen i 18 dodawan/odejmowan.
  doAssert flops(s) == 25

  echo "OK - mnozenie Strassena 2x2"



# TEST 3: MACIERZE O DOWOLNYCH ROZMIARACH

proc testAllSizes() =

  var tests = 0

  # Sprawdzamy rozne wymiary macierzy.
  # A: n x k
  # B: k x p

  for n in 1..9:
    for k in 1..9:
      for p in 1..9:

        let a = randomMatrix(n, k)
        let b = randomMatrix(k, p)

        # Wynik referencyjny.
        let expected = classicMultiply(a, b)

        # Testujemy rozne progi rekurencji.
        for cutoff in [1, 2, 4]:

          var s: Stats

          let c = multiplyStrassen(a, b, cutoff, s)

          # Sprawdzamy rozmiar wyniku.
          doAssert c.rows == n
          doAssert c.cols == p

          # Porownujemy wyniki.
          doAssert maxError(c, expected) < 1e-8

          # Algorytm musi wykonac mnozenia.
          doAssert s.muls > 0

          tests += 1

  echo "OK - dowolne rozmiary: ", tests, " testow"



# TEST 4: WIEKSZE MACIERZE

proc testLarge() =

  # Rozmiary parzyste i nieparzyste.
  for n in [16, 17, 31, 32, 33, 64]:

    let a = randomMatrix(n, n)
    let b = randomMatrix(n, n)

    let expected = classicMultiply(a, b)

    var s: Stats
    let c = multiplyStrassen(a, b, 4, s)

    doAssert maxError(c, expected) < 1e-8

  echo "OK - wieksze macierze"



# TEST 5: LICZNIK OPERACJI FLOP

proc testFlops() =

  let a = randomMatrix(5, 5)
  let b = randomMatrix(5, 5)

  # Strassen z progiem rekurencji 2.
  var s: Stats
  discard multiplyStrassen(a, b, 2, s)

  doAssert s.muls == 117
  doAssert s.adds == 128
  doAssert s.subs == 24
  doAssert s.divs == 0
  doAssert flops(s) == 269

  # Dla progu 5 powinno wykonac sie
  # klasyczne mnozenie macierzy 5x5.
  var classicStats: Stats
  discard multiplyStrassen(a, b, 5, classicStats)

  # n^3 mnozen + n^2*(n-1) dodawan.
  doAssert flops(classicStats) == 225

  echo "OK - liczniki FLOP"



# TEST 6: MNOZENIE PRZEZ SKALAR

proc testScalar() =

  let a = randomMatrix(3, 3)

  var s: Stats
  let b = multiplyScalar(a, 3.0, s)

  for i in 0..<3:
    for j in 0..<3:
      doAssert abs(b[i, j] - 3.0 * a[i, j]) < 1e-12

  # 9 mnozen elementow macierzy.
  doAssert s.muls == 9

  # Dodatkowe mnozenie dwoch skalarow.
  doAssert multiplyScalars(3.0, 4.0, s) == 12.0
  doAssert s.muls == 10

  echo "OK - mnozenie przez skalar"



# TEST 7: BLEDNE DANE WEJSCIOWE

proc testInvalid() =

  let a = newMatrix(2, 3)
  let b = newMatrix(4, 2)

  var s: Stats
  var caught = false

  # Niezgodne wymiary macierzy.
  try:
    discard multiplyStrassen(a, b, 2, s)
  except ValueError:
    caught = true

  doAssert caught

  # Niepoprawny prog rekurencji.
  caught = false

  try:
    discard multiplyStrassen(a, newMatrix(3, 2), 0, s)
  except ValueError:
    caught = true

  doAssert caught

  # Niepoprawny zakres widoku.
  caught = false

  try:
    discard view(a, 0, 0, 5, 5)
  except ValueError:
    caught = true

  doAssert caught

  echo "OK - bledne dane wejsciowe"



# TEST 8: DANE LOSOWE I BRAK MODYFIKACJI WEJSCIA

proc testInput() =

  let a = randomMatrix(8, 8)
  let b = randomMatrix(8, 8)

  # Sprawdzamy zakres losowanych liczb.
  for i in 0..<8:
    for j in 0..<8:
      doAssert a[i, j] > 1e-8
      doAssert a[i, j] < 1.0

  # Zapamietujemy wybrane elementy.
  let oldA = a[0, 0]
  let oldB = b[0, 0]

  var s: Stats
  discard multiplyStrassen(a, b, 1, s)

  # Mnozenie nie moze modyfikowac macierzy wejsciowych.
  doAssert a[0, 0] == oldA
  doAssert b[0, 0] == oldB

  echo "OK - dane losowe i macierze wejsciowe"



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

  echo ""
  echo "WSZYSTKIE TESTY ZAKONCZONE POMYSLNIE"
