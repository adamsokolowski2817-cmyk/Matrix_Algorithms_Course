# Dwa sposoby dzielenia macierzy.
type SplitMode* = enum
  smHalf,           # Zwykly podzial na pol
  smDivisibleBy3    # Podzial dopasowany do Ladermana


proc splitPoint*(n: int, mode: SplitMode): int =
  # Standardowo dzielimy na pol.
  result = n div 2

  # Dla wielokrotnosci 3 dobieramy podzial
  # tak, aby obie czesci byly podzielne przez 3.
  if mode == smDivisibleBy3 and n >= 6 and n mod 3 == 0:
    result = (result div 3) * 3

