import std/[random, times, monotimes, os, strutils]


# 1. REPREZENTACJA MACIERZY I LICZNIK FLOP


type
  Stats* = object
    adds*, subs*, muls*, divs*: int64

  Storage = ref object
    values: seq[float64]

  Matrix* = ref object
    rows*, cols*: int
    stride, offset: int
    storage: Storage

  # Jeden skladnik kombinacji liniowej macierzy.
  # sign = 1 (dodawanie), sign = -1 (odejmowanie).
  Term = tuple[mat: Matrix, sign: int]


proc flops*(s: Stats): int64 =
  result = s.adds + s.subs + s.muls + s.divs


proc newMatrix*(rows, cols: int): Matrix =
  if rows <= 0 or cols <= 0:
    raise newException(ValueError, "Niepoprawne wymiary macierzy")

  result = Matrix(
    rows: rows,
    cols: cols,
    stride: cols,
    offset: 0,
    storage: Storage(values: newSeq[float64](rows * cols))
  )


# Odczyt i zapis elementow macierzy.
proc `[]`*(a: Matrix, i, j: int): float64 {.inline.} =
  result = a.storage.values[a.offset + i * a.stride + j]


proc `[]=`*(a: Matrix, i, j: int, value: float64) {.inline.} =
  a.storage.values[a.offset + i * a.stride + j] = value


# Losowe liczby z przedzialu (0.00000001, 1.0).
proc randomMatrix*(rows, cols: int): Matrix =
  result = newMatrix(rows, cols)

  for i in 0..<rows:
    for j in 0..<cols:
      result[i, j] = 0.00000002 + rand(0.99999996)



# OPTYMALIZACJA 1:
# OPTYMALIZACJA PAMIECI PRZEZ WIDOKI MACIERZY


# Zamiast kopiowac elementy podmacierzy, tworzymy widok.
# Wszystkie widoki wskazuja na te same dane w pamieci.

# offset - pozycja poczatkowego elementu podmacierzy
# stride - odleglosc miedzy kolejnymi wierszami

proc view*(a: Matrix, row, col, rows, cols: int): Matrix =

  if row < 0 or col < 0 or rows <= 0 or cols <= 0 or
     row + rows > a.rows or col + cols > a.cols:
    raise newException(ValueError, "Niepoprawny widok macierzy")

  result = Matrix(
    rows: rows,
    cols: cols,
    stride: a.stride,
    offset: a.offset + row * a.stride + col,
    storage: a.storage
  )


# 2. PODSTAWOWE OPERACJE NA MACIERZACH


# Tworzenie kombinacji liniowej blokow macierzy.
# Przyklad:
# A11 + A12 - A21
#
# Kazdy skladnik zapisujemy jako (macierz, znak).
# Dzieki temu mozemy wygodnie zapisac 23 wzory Ladermana.

proc combine(dest: Matrix, terms: openArray[Term], s: var Stats) =

  if terms.len == 0:
    raise newException(ValueError, "Pusta kombinacja macierzy")

  # Liczymy operacje dodawania i odejmowania.
  let elements = int64(dest.rows) * int64(dest.cols)

  for t in 1..<terms.len:
    if terms[t].sign == 1:
      s.adds += elements
    else:
      s.subs += elements

  # Obliczamy wynik kombinacji liniowej.
  for i in 0..<dest.rows:
    for j in 0..<dest.cols:

      var value = terms[0].mat[i, j]

      if terms[0].sign == -1:
        value = -value

      for t in 1..<terms.len:
        if terms[t].sign == 1:
          value += terms[t].mat[i, j]
        else:
          value -= terms[t].mat[i, j]

      dest[i, j] = value


# Kopiowanie macierzy, bez liczenia FLOP.
proc copyInto(c, a: Matrix) =
  for i in 0..<c.rows:
    for j in 0..<c.cols:
      c[i, j] = a[i, j]


# Dodanie obliczonego produktu do bloku wynikowego.

# Przy pierwszym produkcie kopiujemy wynik.
# Przy kolejnych produktach wykonujemy dodawanie.
# Pozwala to uniknac niepotrzebnego dodawania do zera.

proc addProduct(c, product: Matrix, written: var bool,
                s: var Stats) =

  if not written:
    copyInto(c, product)
    written = true

  else:
    for i in 0..<c.rows:
      for j in 0..<c.cols:
        c[i, j] = c[i, j] + product[i, j]

    s.adds += int64(c.rows) * int64(c.cols)



# 3. KLASYCZNE MNOZENIE MACIERZY

# Dla malych blokow uzywamy klasycznego mnozenia.
# Kolejnosc petli i-k-j poprawia lokalnosc pamieci.

proc classicInto(a, b, c: Matrix, s: var Stats) =

  for i in 0..<a.rows:

    for j in 0..<b.cols:
      c[i, j] = a[i, 0] * b[0, j]

    for k in 1..<a.cols:
      let x = a[i, k]

      for j in 0..<b.cols:
        c[i, j] = c[i, j] + x * b[k, j]

  let elements = int64(a.rows) * int64(b.cols)

  s.muls += elements * int64(a.cols)
  s.adds += elements * int64(a.cols - 1)


proc classicMultiply*(a, b: Matrix): Matrix =

  if a.cols != b.rows:
    raise newException(ValueError, "Niezgodne wymiary macierzy")

  result = newMatrix(a.rows, b.cols)

  var s: Stats
  classicInto(a, b, result, s)


# Iloczyn skalarny wiersza A i kolumny B.
proc dotProduct(a, b: Matrix, i, j: int,
                s: var Stats): float64 =

  result = a[i, 0] * b[0, j]
  s.muls += 1

  for k in 1..<a.cols:
    result += a[i, k] * b[k, j]
    s.muls += 1
    s.adds += 1


# 4. MNOZENIE PRZEZ SKALAR

proc multiplyScalars*(a, b: float64, s: var Stats): float64 =
  s.muls += 1
  result = a * b


proc multiplyScalar*(a: Matrix, number: float64,
                     s: var Stats): Matrix =

  result = newMatrix(a.rows, a.cols)

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      result[i, j] = a[i, j] * number
      s.muls += 1


proc ladermanInto(a, b, c: Matrix, cutoff: int, s: var Stats)



# OPTYMALIZACJA 2:
# MODYFIKACJA ALGORYTMU DO MACIERZY DOWOLNYCH ROZMIAROW
# DYNAMIC PEELING

# Laderman dzieli macierze na bloki 3x3.
# Wymiary musza wiec byc podzielne przez 3.

# Dla innych wymiarow:
# 1. Wyznaczamy najwieksze wielokrotnosci 3.
# 2. Rekurencyjnie mnozymy glowny blok.
# 3. Obliczamy brakujace wiersze i kolumny.
# 4. Uwzgledniamy pozostale skladniki iloczynu.
# Nie dopelniamy macierzy zerami.

proc multiplyRemainder(a, b, c: Matrix, cutoff: int,
                       s: var Stats) =

  let n = a.rows
  let k = a.cols
  let p = b.cols

  # KROK 1: Wyznaczenie wymiarow podzielnych przez 3.
  let ne = n - n mod 3
  let ke = k - k mod 3
  let pe = p - p mod 3

  # Gdy glowny blok jest za maly, mnozymy klasycznie.
  if ne == 0 or ke == 0 or pe == 0:
    classicInto(a, b, c, s)
    return

  # KROK 2: Mnozenie glownego bloku metoda Ladermana.
  ladermanInto(
    view(a, 0, 0, ne, ke),
    view(b, 0, 0, ke, pe),
    view(c, 0, 0, ne, pe),
    cutoff, s
  )

  # KROK 3: Pozostale skladniki wymiaru wewnetrznego.
  # k moze pozostawiac 1 lub 2 dodatkowe elementy.
  #
  # C[i,j] += A[i,t] * B[t,j]

  for i in 0..<ne:
    for j in 0..<pe:
      for t in ke..<k:
        c[i, j] = c[i, j] + a[i, t] * b[t, j]
        s.muls += 1
        s.adds += 1

  # KROK 4: Pozostale wiersze macierzy wynikowej.
  # Obliczamy je klasycznym iloczynem skalarnym.
  for i in ne..<n:
    for j in 0..<p:
      c[i, j] = dotProduct(a, b, i, j, s)

  # KROK 5: Pozostale kolumny macierzy wynikowej.
  # Pomijamy wiersze obliczone w poprzednim kroku.
  for i in 0..<ne:
    for j in pe..<p:
      c[i, j] = dotProduct(a, b, i, j, s)



# OPTYMALIZACJA 3:
# TRZY BUFORY ZAMIAST PRZECHOWYWANIA 23 WYNIKOW

# Standardowo mozna przechowywac m1, m2, ..., m23.

# My wykorzystujemy:
# x       - lewa macierz pomocnicza
# y       - prawa macierz pomocnicza
# product - aktualny wynik mnozenia

# Wyniki dopisujemy bezposrednio do blokow macierzy C.
# Bufory x, y i product sa wykorzystywane wielokrotnie.

proc multiplyDivisible(a, b, c: Matrix, cutoff: int,
                       s: var Stats) =

  let nh = a.rows div 3
  let kh = a.cols div 3
  let ph = b.cols div 3

  # KROK 1: Podzial macierzy A na 9 blokow.
  let a11 = view(a, 0, 0, nh, kh)
  let a12 = view(a, 0, kh, nh, kh)
  let a13 = view(a, 0, 2*kh, nh, kh)

  let a21 = view(a, nh, 0, nh, kh)
  let a22 = view(a, nh, kh, nh, kh)
  let a23 = view(a, nh, 2*kh, nh, kh)

  let a31 = view(a, 2*nh, 0, nh, kh)
  let a32 = view(a, 2*nh, kh, nh, kh)
  let a33 = view(a, 2*nh, 2*kh, nh, kh)

  # KROK 2: Podzial macierzy B na 9 blokow.
  let b11 = view(b, 0, 0, kh, ph)
  let b12 = view(b, 0, ph, kh, ph)
  let b13 = view(b, 0, 2*ph, kh, ph)

  let b21 = view(b, kh, 0, kh, ph)
  let b22 = view(b, kh, ph, kh, ph)
  let b23 = view(b, kh, 2*ph, kh, ph)

  let b31 = view(b, 2*kh, 0, kh, ph)
  let b32 = view(b, 2*kh, ph, kh, ph)
  let b33 = view(b, 2*kh, 2*ph, kh, ph)

  # KROK 3: Podzial macierzy wynikowej C.
  let c11 = view(c, 0, 0, nh, ph)
  let c12 = view(c, 0, ph, nh, ph)
  let c13 = view(c, 0, 2*ph, nh, ph)

  let c21 = view(c, nh, 0, nh, ph)
  let c22 = view(c, nh, ph, nh, ph)
  let c23 = view(c, nh, 2*ph, nh, ph)

  let c31 = view(c, 2*nh, 0, nh, ph)
  let c32 = view(c, 2*nh, ph, nh, ph)
  let c33 = view(c, 2*nh, 2*ph, nh, ph)

  # KROK 4: Tworzymy trzy bufory.
  let x = newMatrix(nh, kh)
  let y = newMatrix(kh, ph)
  let product = newMatrix(nh, ph)

  # Informacja, czy dany blok C ma juz pierwszy skladnik.
  # Dzieki temu unikamy dodawania do poczatkowego zera.
  var written: array[3, array[3, bool]]


  # KROK 5: 23 MNOZENIA LADERMANA

  # m1 = (a11+a12+a13-a21-a22-a32-a33)*b22
  combine(x, [(a11, 1), (a12, 1), (a13, 1),
              (a21, -1), (a22, -1), (a32, -1),
              (a33, -1)], s)

  ladermanInto(x, b22, product, cutoff, s)
  addProduct(c12, product, written[0][1], s)


  # m2 = (a11-a21)*(-b12+b22)
  combine(x, [(a11, 1), (a21, -1)], s)
  combine(y, [(b12, -1), (b22, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c22, product, written[1][1], s)


  # m3 = a22*(-b11+b12+b21-b22-b23-b31+b33)
  combine(y, [(b11, -1), (b12, 1), (b21, 1),
              (b22, -1), (b23, -1), (b31, -1),
              (b33, 1)], s)

  ladermanInto(a22, y, product, cutoff, s)
  addProduct(c21, product, written[1][0], s)


  # m4 = (-a11+a21+a22)*(b11-b12+b22)
  combine(x, [(a11, -1), (a21, 1), (a22, 1)], s)
  combine(y, [(b11, 1), (b12, -1), (b22, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c22, product, written[1][1], s)


  # m5 = (a21+a22)*(-b11+b12)
  combine(x, [(a21, 1), (a22, 1)], s)
  combine(y, [(b11, -1), (b12, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c22, product, written[1][1], s)


  # m6 = a11*b11
  ladermanInto(a11, b11, product, cutoff, s)

  addProduct(c11, product, written[0][0], s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c22, product, written[1][1], s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c33, product, written[2][2], s)


  # m7 = (-a11+a31+a32)*(b11-b13+b23)
  combine(x, [(a11, -1), (a31, 1), (a32, 1)], s)
  combine(y, [(b11, 1), (b13, -1), (b23, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c33, product, written[2][2], s)


  # m8 = (-a11+a31)*(b13-b23)
  combine(x, [(a11, -1), (a31, 1)], s)
  combine(y, [(b13, 1), (b23, -1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c33, product, written[2][2], s)


  # m9 = (a31+a32)*(-b11+b13)
  combine(x, [(a31, 1), (a32, 1)], s)
  combine(y, [(b11, -1), (b13, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c33, product, written[2][2], s)


  # m10 = (a11+a12+a13-a22-a23-a31-a32)*b23
  combine(x, [(a11, 1), (a12, 1), (a13, 1),
              (a22, -1), (a23, -1), (a31, -1),
              (a32, -1)], s)

  ladermanInto(x, b23, product, cutoff, s)
  addProduct(c13, product, written[0][2], s)


  # m11 = a32*(-b11+b13+b21-b22-b23-b31+b32)
  combine(y, [(b11, -1), (b13, 1), (b21, 1),
              (b22, -1), (b23, -1), (b31, -1),
              (b32, 1)], s)

  ladermanInto(a32, y, product, cutoff, s)
  addProduct(c31, product, written[2][0], s)


  # m12 = (-a13+a32+a33)*(b22+b31-b32)
  combine(x, [(a13, -1), (a32, 1), (a33, 1)], s)
  combine(y, [(b22, 1), (b31, 1), (b32, -1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c32, product, written[2][1], s)


  # m13 = (a13-a33)*(b22-b32)
  combine(x, [(a13, 1), (a33, -1)], s)
  combine(y, [(b22, 1), (b32, -1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c32, product, written[2][1], s)


  # m14 = a13*b31
  ladermanInto(a13, b31, product, cutoff, s)

  addProduct(c11, product, written[0][0], s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c23, product, written[1][2], s)
  addProduct(c31, product, written[2][0], s)
  addProduct(c32, product, written[2][1], s)


  # m15 = (a32+a33)*(-b31+b32)
  combine(x, [(a32, 1), (a33, 1)], s)
  combine(y, [(b31, -1), (b32, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c12, product, written[0][1], s)
  addProduct(c32, product, written[2][1], s)


  # m16 = (-a13+a22+a23)*(b23+b31-b33)
  combine(x, [(a13, -1), (a22, 1), (a23, 1)], s)
  combine(y, [(b23, 1), (b31, 1), (b33, -1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c23, product, written[1][2], s)


  # m17 = (a13-a23)*(b23-b33)
  combine(x, [(a13, 1), (a23, -1)], s)
  combine(y, [(b23, 1), (b33, -1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c21, product, written[1][0], s)
  addProduct(c23, product, written[1][2], s)


  # m18 = (a22+a23)*(-b31+b33)
  combine(x, [(a22, 1), (a23, 1)], s)
  combine(y, [(b31, -1), (b33, 1)], s)

  ladermanInto(x, y, product, cutoff, s)
  addProduct(c13, product, written[0][2], s)
  addProduct(c23, product, written[1][2], s)


  # m19 = a12*b21
  ladermanInto(a12, b21, product, cutoff, s)
  addProduct(c11, product, written[0][0], s)


  # m20 = a23*b32
  ladermanInto(a23, b32, product, cutoff, s)
  addProduct(c22, product, written[1][1], s)


  # m21 = a21*b13
  ladermanInto(a21, b13, product, cutoff, s)
  addProduct(c23, product, written[1][2], s)


  # m22 = a31*b12
  ladermanInto(a31, b12, product, cutoff, s)
  addProduct(c32, product, written[2][1], s)


  # m23 = a33*b33
  ladermanInto(a33, b33, product, cutoff, s)
  addProduct(c33, product, written[2][2], s)


  # KROK 6: Macierz wynikowa zostala juz zlozona.
  


# 5. GLOWNA FUNKCJA REKURENCYJNA LADERMANA

proc ladermanInto(a, b, c: Matrix, cutoff: int,
                  s: var Stats) =

  let n = a.rows
  let k = a.cols
  let p = b.cols

  # Male macierze mnozymy klasycznie.
  if min(n, min(k, p)) <= cutoff:
    classicInto(a, b, c, s)

  # Gdy ktorys wymiar nie jest podzielny przez 3,
  # oddzielamy odstajace fragmenty.
  elif n mod 3 != 0 or k mod 3 != 0 or p mod 3 != 0:
    multiplyRemainder(a, b, c, cutoff, s)

  # Dla wymiarow podzielnych przez 3 wykonujemy
  # 23 rekurencyjne mnozenia Ladermana.
  else:
    multiplyDivisible(a, b, c, cutoff, s)


# Publiczna funkcja mnozenia macierzy metoda Ladermana.
proc multiplyLaderman*(a, b: Matrix, cutoff: int,
                       s: var Stats): Matrix =

  if a.cols != b.rows:
    raise newException(ValueError, "Niezgodne wymiary macierzy")

  if cutoff < 1:
    raise newException(ValueError, "Prog musi byc dodatni")

  result = newMatrix(a.rows, b.cols)
  ladermanInto(a, b, result, cutoff, s)


# 6. WERYFIKACJA POPRAWNOSCI

proc maxError*(a, b: Matrix): float64 =

  if a.rows != b.rows or a.cols != b.cols:
    raise newException(ValueError, "Rozne wymiary wynikow")

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let diff = abs(a[i, j] - b[i, j])

      if diff > result:
        result = diff


# Kontrola trzech wybranych elementow duzej macierzy.
proc sampleError(a, b, c: Matrix): float64 =

  let positions = [
    (0, 0),
    (a.rows div 2, b.cols div 2),
    (a.rows - 1, b.cols - 1)
  ]

  for position in positions:

    let i = position[0]
    let j = position[1]

    var expected = a[i, 0] * b[0, j]

    for k in 1..<a.cols:
      expected += a[i, k] * b[k, j]

    let diff = abs(expected - c[i, j])

    if diff > result:
      result = diff



# 7. POMIARY CZASU, FLOP I GFLOPS

# Zapisujemy wyniki do laderman_results.csv.
# Dla malych macierzy mierzymy serie mnozen,
# poniewaz pojedynczy pomiar moze byc zbyt krotki.

proc benchmark(maxN, step, cutoff, repeats: int) =

  if maxN < 1 or step < 1 or cutoff < 1 or repeats < 1:
    raise newException(ValueError, "Niepoprawne parametry")

  let f = open("laderman_results.csv", fmWrite)
  defer: f.close()

  f.writeLine(
    "n,time_s,flops,mul,add,sub,div,gflops,error_sample"
  )

  for n in countup(1, maxN, step):

    let a = randomMatrix(n, n)
    let b = randomMatrix(n, n)

    var bestTime = 1.0e100
    var bestStats: Stats
    var bestResult: Matrix

    # Liczba mnozen w jednej mierzonej serii.
    var batch = 1

    for rep in 0..<repeats:

      var elapsed = 0.0
      var currentStats: Stats
      var currentResult: Matrix

      # Wydluzamy pomiar, jesli jest bardzo krotki.
      while true:

        let startTime = getMonoTime()

        for t in 0..<batch:
          var s: Stats

          currentResult = multiplyLaderman(a, b, cutoff, s)
          currentStats = s

        elapsed = float64(
          (getMonoTime() - startTime).inNanoseconds
        ) / 1e9

        if elapsed >= 0.01 or batch >= 65536:
          break

        batch *= 2

      # Sredni czas jednego mnozenia w serii.
      let avgTime = elapsed / float64(batch)

      if avgTime < bestTime:
        bestTime = avgTime
        bestStats = currentStats
        bestResult = currentResult

    # Liczba operacji arytmetycznych.
    let operations = flops(bestStats)

    # Wydajnosc w GFLOPS.
    var gflops = 0.0

    if bestTime > 0.0:
      gflops = float64(operations) / bestTime / 1e9

    # Sprawdzamy wybrane elementy wyniku.
    let err = sampleError(a, b, bestResult)

    # Zapis do CSV.
    f.writeLine(
      $n & "," &
      $bestTime & "," &
      $operations & "," &
      $bestStats.muls & "," &
      $bestStats.adds & "," &
      $bestStats.subs & "," &
      $bestStats.divs & "," &
      $gflops & "," &
      $err
    )

    if n == 1 or n mod 50 == 0 or n == maxN:
      echo "n=", n,
           " czas=", bestTime,
           " s FLOP=", operations,
           " GFLOPS=", gflops

  echo "Zapisano laderman_results.csv"


# 8. EKSPORT WYNIKU DO GNU OCTAVE

proc octaveMatrix(a: Matrix): string =

  result = "["

  for i in 0..<a.rows:

    if i > 0:
      result.add("; ")

    for j in 0..<a.cols:

      if j > 0:
        result.add(", ")

      result.add(formatFloat(a[i, j], ffScientific, 17))

  result.add("]")


proc exportOctave(n, cutoff: int) =

  if n < 4 or cutoff < 1:
    raise newException(ValueError, "Wybierz n >= 4")

  let a = randomMatrix(n, n)
  let b = randomMatrix(n, n)

  var s: Stats

  let startTime = getMonoTime()
  let c = multiplyLaderman(a, b, cutoff, s)

  let nimTime = float64(
    (getMonoTime() - startTime).inNanoseconds
  ) / 1e9

  var code = "A = " & octaveMatrix(a) & ";\n"
  code.add("B = " & octaveMatrix(b) & ";\n")
  code.add("C_nim = " & octaveMatrix(c) & ";\n")

  # Wbudowane mnozenie macierzy w Octave.
  code.add("tic;\n")
  code.add("C_octave = A * B;\n")
  code.add("t_octave = toc;\n")

  code.add("disp('Wynik Ladermana w Nim:');\n")
  code.add("disp(C_nim);\n")

  code.add("disp('Wynik Octave:');\n")
  code.add("disp(C_octave);\n")

  code.add("err = max(abs(C_nim(:) - C_octave(:)));\n")
  code.add("fprintf('Maksymalny blad: %.12g\\n', err);\n")
  code.add("fprintf('Czas Octave: %.9f s\\n', t_octave);\n")
  code.add("fprintf('Czas Nim: %.9f s\\n', " & $nimTime & ");\n")

  writeFile("laderman_octave_check.m", code)

  echo "Zapisano laderman_octave_check.m"
  echo "FLOP Ladermana: ", flops(s)



# 9. POJEDYNCZE MNOZENIE DO POMIARU PAMIECI

proc memoryCase(n, cutoff: int) =

  let a = randomMatrix(n, n)
  let b = randomMatrix(n, n)

  var s: Stats
  let c = multiplyLaderman(a, b, cutoff, s)

  echo "Wynik kontrolny: ", c[0, 0]
  echo "FLOP: ", flops(s)



# 10. PRZYKLADOWE URUCHOMIENIE

proc demo(n, k, p, cutoff: int) =

  let a = randomMatrix(n, k)
  let b = randomMatrix(k, p)

  var s: Stats

  let startTime = getMonoTime()
  let c = multiplyLaderman(a, b, cutoff, s)

  let elapsed = float64(
    (getMonoTime() - startTime).inNanoseconds
  ) / 1e9

  let expected = classicMultiply(a, b)

  echo "Wymiary: ", n, "x", k, " * ", k, "x", p
  echo "Prog rekurencji: ", cutoff

  echo "Czas: ", elapsed, " s"
  echo "Mnozenia: ", s.muls
  echo "Dodawania: ", s.adds
  echo "Odejmowania: ", s.subs
  echo "Dzielenia: ", s.divs

  echo "FLOP: ", flops(s)
  echo "Maksymalny blad: ", maxError(c, expected)



# 11. PROGRAM GLOWNY

when isMainModule:

  randomize(12345)

  let args = commandLineParams()

  if args.len == 0:
    demo(5, 5, 5, 1)

  elif args[0] == "--demo" and args.len == 5:
    demo(
      parseInt(args[1]),
      parseInt(args[2]),
      parseInt(args[3]),
      parseInt(args[4])
    )

  elif args[0] == "--bench" and args.len == 5:
    benchmark(
      parseInt(args[1]),
      parseInt(args[2]),
      parseInt(args[3]),
      parseInt(args[4])
    )

  elif args[0] == "--octave" and args.len == 3:
    exportOctave(
      parseInt(args[1]),
      parseInt(args[2])
    )

  elif args[0] == "--memcase" and args.len == 3:
    memoryCase(
      parseInt(args[1]),
      parseInt(args[2])
    )

  else:
    echo "Dostepne komendy:"
    echo "  --demo n k p cutoff"
    echo "  --bench maxN step cutoff repeats"
    echo "  --octave n cutoff"
    echo "  --memcase n cutoff"
