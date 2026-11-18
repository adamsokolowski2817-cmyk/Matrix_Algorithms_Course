import std/[random, times, monotimes, os, strutils]


# 1. REPREZENTACJA MACIERZY I LICZNIK FLOP

type
  Stats* = object
    adds*, subs*, muls*, divs*: int64

  # Wspolna pamiec dla macierzy i jej widokow.
  Storage = ref object
    values: seq[float64]

  Matrix* = ref object
    rows*, cols*: int
    stride, offset: int
    storage: Storage


# Suma wszystkich operacji zmiennoprzecinkowych.
proc flops*(s: Stats): int64 =
  result = s.adds + s.subs + s.muls + s.divs


# Tworzenie macierzy wypelnionej zerami.
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


# Odczytywanie elementu macierzy.
proc `[]`*(a: Matrix, i, j: int): float64 {.inline.} =
  result = a.storage.values[a.offset + i * a.stride + j]


# Zapisywanie elementu macierzy.
proc `[]=`*(a: Matrix, i, j: int, value: float64) {.inline.} =
  a.storage.values[a.offset + i * a.stride + j] = value


# Generowanie losowej macierzy z przedzialu (0.00000001, 1.0).
proc randomMatrix*(rows, cols: int): Matrix =
  result = newMatrix(rows, cols)

  for i in 0..<rows:
    for j in 0..<cols:
      result[i, j] = 0.00000002 + rand(0.99999996)



# OPTYMALIZACJA 1:
# OPTYMALIZACJA PAMIECI PRZEZ WIDOKI MACIERZY

# Zamiast kopiowac podmacierz, tworzymy widok na jej fragment.
# Widok przechowuje wspolna pamiec z macierza oryginalna.
# offset - pozycja pierwszego elementu bloku
# stride - odleglosc miedzy kolejnymi wierszami

# Nie kopiujemy wartosci macierzy.

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

# Dodawanie lub odejmowanie dwoch macierzy.
# sign = 1: dodawanie
# sign = -1: odejmowanie
proc addSubInto(c, a, b: Matrix, sign: int, s: var Stats) =
  for i in 0..<c.rows:
    for j in 0..<c.cols:
      if sign == 1:
        c[i, j] = a[i, j] + b[i, j]
      else:
        c[i, j] = a[i, j] - b[i, j]

  let count = int64(c.rows) * int64(c.cols)

  if sign == 1:
    s.adds += count
  else:
    s.subs += count


# Dodanie lub odjecie wyniku czastkowego od macierzy C.
proc accumulate(c, b: Matrix, sign: int, s: var Stats) =
  for i in 0..<c.rows:
    for j in 0..<c.cols:
      if sign == 1:
        c[i, j] = c[i, j] + b[i, j]
      else:
        c[i, j] = c[i, j] - b[i, j]

  let count = int64(c.rows) * int64(c.cols)

  if sign == 1:
    s.adds += count
  else:
    s.subs += count


# Kopiowanie wartosci macierzy.
# Nie jest to operacja FLOP.
proc copyInto(c, a: Matrix) =
  for i in 0..<c.rows:
    for j in 0..<c.cols:
      c[i, j] = a[i, j]


# Zerowanie macierzy.
proc clearMatrix(c: Matrix) =
  for i in 0..<c.rows:
    for j in 0..<c.cols:
      c[i, j] = 0.0



# 3. KLASYCZNE MNOZENIE MACIERZY

# Dla malych macierzy zwykle mnozenie jest szybsze.
# Kolejnosc petli i-k-j poprawia dostep do pamieci CPU.

proc classicInto(a, b, c: Matrix, s: var Stats) =

  for i in 0..<a.rows:

    # Pierwszy skladnik iloczynu skalarnego.
    for j in 0..<b.cols:
      c[i, j] = a[i, 0] * b[0, j]

    # Pozostale skladniki.
    for k in 1..<a.cols:
      let x = a[i, k]

      for j in 0..<b.cols:
        c[i, j] = c[i, j] + x * b[k, j]

  # Liczymy wszystkie mnozenia i dodawania.
  let elements = int64(a.rows) * int64(b.cols)

  s.muls += elements * int64(a.cols)
  s.adds += elements * int64(a.cols - 1)


# Klasyczne mnozenie do weryfikacji wyniku.
proc classicMultiply*(a, b: Matrix): Matrix =
  if a.cols != b.rows:
    raise newException(ValueError, "Niezgodne wymiary")

  result = newMatrix(a.rows, b.cols)

  var s: Stats
  classicInto(a, b, result, s)


# Obliczanie pojedynczego elementu iloczynu macierzy.
# count oznacza liczbe skladnikow iloczynu skalarnego.
proc dotPrefix(a, b: Matrix, i, j, count: int,
               s: var Stats): float64 =

  if count <= 0:
    return 0.0

  result = a[i, 0] * b[0, j]
  s.muls += 1

  for k in 1..<count:
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


proc strassenInto(a, b, c: Matrix, cutoff: int, s: var Stats)



# OPTYMALIZACJA 2:
# MODYFIKACJA ALGORYTMU DO MACIERZY DOWOLNYCH ROZMIAROW
# DYNAMIC PEELING


# W klasycznej wersji Strassena trzeba dzielic macierze
# na cztery bloki o rownych rozmiarach.

# Dla nieparzystych wymiarow:
# 1. Wydzielamy parzysta czesc macierzy.
# 2. Mnozymy ja rekurencyjnie.
# 3. Obliczamy brakujace wiersze i kolumny.
# Nie wypelniamy macierzy dodatkowymi zerami.

proc multiplyOdd(a, b, c: Matrix, cutoff: int,
                 s: var Stats) =

  let n = a.rows
  let k = a.cols
  let p = b.cols

  # KROK 1: Wyznaczenie glownych, parzystych wymiarow.
  let ne = n - n mod 2
  let ke = k - k mod 2
  let pe = p - p mod 2

  clearMatrix(c)

  # KROK 2: Rekurencyjne mnozenie glownego bloku.
  if ne > 0 and ke > 0 and pe > 0:
    strassenInto(
      view(a, 0, 0, ne, ke),
      view(b, 0, 0, ke, pe),
      view(c, 0, 0, ne, pe),
      cutoff, s
    )

  # KROK 3: Nieparzysty wymiar wewnetrzny k.
  # Dodajemy iloczyn ostatniej kolumny A
  # i ostatniego wiersza B do glownego bloku C.
  if k mod 2 != 0:

    for i in 0..<ne:
      for j in 0..<pe:
        c[i, j] = c[i, j] + a[i, ke] * b[ke, j]
        s.muls += 1
        s.adds += 1

  # KROK 4: Nieparzysta liczba wierszy.
  # Liczymy caly ostatni wiersz klasycznie.
  if n mod 2 != 0:

    for j in 0..<p:
      c[ne, j] = dotPrefix(a, b, ne, j, k, s)

  # KROK 5: Nieparzysta liczba kolumn.
  # Liczymy ostatnia kolumne poza ostatnim wierszem.
  if p mod 2 != 0:

    for i in 0..<ne:
      c[i, pe] = dotPrefix(a, b, i, pe, k, s)



# OPTYMALIZACJA 3:
# TRZY BUFORY ZAMIAST PRZECHOWYWANIA P1, P2, ..., P7
# W standardowej implementacji przechowujemy siedem
# wynikow mnozen Strassena.

# U nas wykorzystujemy trzy bufory:
# x       - lewa macierz pomocnicza
# y       - prawa macierz pomocnicza
# product - aktualny iloczyn
# Po obliczeniu kazdego P zapisujemy wynik do C.
# Nastepnie ponownie wykorzystujemy bufory.

proc multiplyEven(a, b, c: Matrix, cutoff: int,
                  s: var Stats) =

  let nh = a.rows div 2
  let kh = a.cols div 2
  let ph = b.cols div 2

  # KROK 1: Podzial macierzy na 4 bloki.
  let a11 = view(a, 0, 0, nh, kh)
  let a12 = view(a, 0, kh, nh, kh)
  let a21 = view(a, nh, 0, nh, kh)
  let a22 = view(a, nh, kh, nh, kh)

  let b11 = view(b, 0, 0, kh, ph)
  let b12 = view(b, 0, ph, kh, ph)
  let b21 = view(b, kh, 0, kh, ph)
  let b22 = view(b, kh, ph, kh, ph)

  let c11 = view(c, 0, 0, nh, ph)
  let c12 = view(c, 0, ph, nh, ph)
  let c21 = view(c, nh, 0, nh, ph)
  let c22 = view(c, nh, ph, nh, ph)

  # KROK 2: Przygotowujemy trzy bufory pomocnicze.
  let x = newMatrix(nh, kh)
  let y = newMatrix(kh, ph)
  let product = newMatrix(nh, ph)

  # KROK 3: Siedem mnozen Strassena.

  # P1 = (A11 + A22) * (B11 + B22)
  addSubInto(x, a11, a22, 1, s)
  addSubInto(y, b11, b22, 1, s)
  strassenInto(x, y, product, cutoff, s)

  copyInto(c11, product)
  copyInto(c22, product)

  # P2 = (A21 + A22) * B11
  addSubInto(x, a21, a22, 1, s)
  strassenInto(x, b11, product, cutoff, s)

  copyInto(c21, product)
  accumulate(c22, product, -1, s)

  # P3 = A11 * (B12 - B22)
  addSubInto(y, b12, b22, -1, s)
  strassenInto(a11, y, product, cutoff, s)

  copyInto(c12, product)
  accumulate(c22, product, 1, s)

  # P4 = A22 * (B21 - B11)
  addSubInto(y, b21, b11, -1, s)
  strassenInto(a22, y, product, cutoff, s)

  accumulate(c11, product, 1, s)
  accumulate(c21, product, 1, s)

  # P5 = (A11 + A12) * B22
  addSubInto(x, a11, a12, 1, s)
  strassenInto(x, b22, product, cutoff, s)

  accumulate(c11, product, -1, s)
  accumulate(c12, product, 1, s)

  # P6 = (A21 - A11) * (B11 + B12)
  addSubInto(x, a21, a11, -1, s)
  addSubInto(y, b11, b12, 1, s)
  strassenInto(x, y, product, cutoff, s)

  accumulate(c22, product, 1, s)

  # P7 = (A12 - A22) * (B21 + B22)
  addSubInto(x, a12, a22, -1, s)
  addSubInto(y, b21, b22, 1, s)
  strassenInto(x, y, product, cutoff, s)

  accumulate(c11, product, 1, s)




# 5. GLOWNA FUNKCJA REKURENCYJNA STRASSENA

proc strassenInto(a, b, c: Matrix, cutoff: int,
                  s: var Stats) =

  let n = a.rows
  let k = a.cols
  let p = b.cols

  # Dla malych macierzy uzywamy klasycznego mnozenia.
  if min(n, min(k, p)) <= cutoff:
    classicInto(a, b, c, s)

  # Dla nieparzystych wymiarow stosujemy dynamic peeling.
  elif n mod 2 != 0 or k mod 2 != 0 or p mod 2 != 0:
    multiplyOdd(a, b, c, cutoff, s)

  # Dla parzystych wymiarow wykonujemy 7 mnozen Strassena.
  else:
    multiplyEven(a, b, c, cutoff, s)


# funkcja mnozenia metoda Strassena.
proc multiplyStrassen*(a, b: Matrix, cutoff: int,
                       s: var Stats): Matrix =

  if a.cols != b.rows:
    raise newException(ValueError, "Niezgodne wymiary macierzy")

  if cutoff < 1:
    raise newException(ValueError, "Prog musi byc dodatni")

  result = newMatrix(a.rows, b.cols)
  strassenInto(a, b, result, cutoff, s)



# 6. SPRAWDZANIE POPRAWNOSCI

# Maksymalna roznica miedzy macierzami.
proc maxError*(a, b: Matrix): float64 =

  if a.rows != b.rows or a.cols != b.cols:
    raise newException(ValueError, "Rozne wymiary wynikow")

  for i in 0..<a.rows:
    for j in 0..<a.cols:
      let diff = abs(a[i, j] - b[i, j])

      if diff > result:
        result = diff


# Sprawdzamy trzy wybrane elementy duzej macierzy.
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

# Benchmark wykonuje pomiary dla n = 1, 2, ..., maxN.
# Dla malych macierzy mierzymy serie mnozen,
# aby uniknac zerowych lub niedokladnych czasow.

proc benchmark(maxN, step, cutoff, repeats: int) =

  if maxN < 1 or step < 1 or cutoff < 1 or repeats < 1:
    raise newException(ValueError, "Niepoprawne parametry")

  let f = open("strassen_results.csv", fmWrite)
  defer: f.close()

  f.writeLine(
    "n,time_s,flops,mul,add,sub,div,gflops,error_sample"
  )

  # KROK 1: Kolejne rozmiary macierzy.
  for n in countup(1, maxN, step):

    let a = randomMatrix(n, n)
    let b = randomMatrix(n, n)

    var bestTime = 1.0e100
    var bestStats: Stats
    var bestResult: Matrix

    # Liczba mnozen wykonywanych w jednej serii.
    var batch = 1

    # KROK 2: Powtarzamy pomiar kilka razy.
    for rep in 0..<repeats:

      var elapsed = 0.0
      var currentStats: Stats
      var currentResult: Matrix

      # KROK 3: Automatyczne wydluzanie pomiaru.
      while true:

        let startTime = getMonoTime()

        for t in 0..<batch:

          var s: Stats

          currentResult = multiplyStrassen(a, b, cutoff, s)
          currentStats = s

        elapsed = float64(
          (getMonoTime() - startTime).inNanoseconds
        ) / 1e9

        # Mierzymy przynajmniej 10 ms,
        # chyba ze osiagnelismy limit powtorzen.
        if elapsed >= 0.01 or batch >= 65536:
          break

        batch *= 2

      # KROK 4: Sredni czas pojedynczego mnozenia.
      let avgTime = elapsed / float64(batch)

      # Wybieramy najlepszy czas z kilku prob.
      if avgTime < bestTime:
        bestTime = avgTime
        bestStats = currentStats
        bestResult = currentResult

    # KROK 5: Liczba operacji zmiennoprzecinkowych.
    let operations = flops(bestStats)

    # KROK 6: Wydajnosc GFLOPS.
    var gflops = 0.0

    if bestTime > 0.0:
      gflops = float64(operations) / bestTime / 1e9

    # KROK 7: Weryfikacja wybranych elementow.
    let err = sampleError(a, b, bestResult)

    # KROK 8: Zapis wynikow do CSV.
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

  echo "Zapisano strassen_results.csv"




# 8. POROWNANIE Z OCTAVE

# Zamiana macierzy na format Octave:
# [1, 2; 3, 4]
proc octaveMatrix(a: Matrix): string =
  result = "["

  for i in 0..<a.rows:

    if i > 0:
      result.add("; ")

    for j in 0..<a.cols:

      if j > 0:
        result.add(", ")

      # Zachowujemy precyzje liczb float64.
      result.add(formatFloat(a[i, j], ffScientific, 17))

  result.add("]")


# Przygotowanie tego samego przykladu do Octave.
proc exportOctave(n, cutoff: int) =

  if n < 4 or cutoff < 1:
    raise newException(ValueError, "Wybierz n >= 4")

  let a = randomMatrix(n, n)
  let b = randomMatrix(n, n)

  var s: Stats

  # Obliczamy wynik naszym algorytmem.
  let startTime = epochTime()
  let c = multiplyStrassen(a, b, cutoff, s)
  let nimTime = epochTime() - startTime

  # Zapisujemy macierze A, B i wynik Nim.
  var code = "A = " & octaveMatrix(a) & ";\n"
  code.add("B = " & octaveMatrix(b) & ";\n")
  code.add("C_nim = " & octaveMatrix(c) & ";\n")

  # Octave policzy wynik wbudowanym mnozeniem.
  code.add("tic;\n")
  code.add("C_octave = A * B;\n")
  code.add("t_octave = toc;\n")

  code.add("disp('Wynik Nim:');\n")
  code.add("disp(C_nim);\n")

  code.add("disp('Wynik Octave:');\n")
  code.add("disp(C_octave);\n")

  # Porownanie wynikow.
  code.add("err = max(abs(C_nim(:) - C_octave(:)));\n")

  code.add("fprintf('Maksymalny blad: %.12g\\n', err);\n")
  code.add("fprintf('Czas Octave: %.9f s\\n', t_octave);\n")
  code.add("fprintf('Czas Nim: %.9f s\\n', " & $nimTime & ");\n")

  writeFile("octave_check.m", code)

  echo "Zapisano octave_check.m"
  echo "FLOP Strassena: ", flops(s)



# 9. POJEDYNCZE MNOZENIE DO POMIARU PAMIECI

# Funkcja przydatna do zewnetrznego pomiaru pamieci procesu.
proc memoryCase(n, cutoff: int) =

  let a = randomMatrix(n, n)
  let b = randomMatrix(n, n)

  var s: Stats
  let c = multiplyStrassen(a, b, cutoff, s)

  echo "Wynik kontrolny: ", c[0, 0]
  echo "FLOP: ", flops(s)



# 10. PRZYKLADOWE URUCHOMIENIE

proc demo(n, k, p, cutoff: int) =

  let a = randomMatrix(n, k)
  let b = randomMatrix(k, p)

  var s: Stats

  # Pomiar czasu Strassena.
  let startTime = epochTime()
  let c = multiplyStrassen(a, b, cutoff, s)
  let elapsed = epochTime() - startTime

  # Wynik klasyczny do porownania.
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

  # Powtarzalne losowanie.
  randomize(12345)

  let args = commandLineParams()

  if args.len == 0:
    demo(5, 5, 5, 2)

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
