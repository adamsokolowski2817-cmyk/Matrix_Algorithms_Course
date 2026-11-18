# LAB 2 - ALGORYTMY MACIERZOWE
# WYKRESY KONCOWE

set terminal svg enhanced size 1600,950 fname "Arial" fsize 17
set encoding utf8

set grid xtics ytics
set border 3 lw 1.2
set tics nomirror
set key outside right center spacing 1.4

set style line 1 lc rgb "#2563EB" lw 3 pt 7 ps 1.3
set style line 2 lc rgb "#EA580C" lw 3 pt 5 ps 1.3
set style line 3 lc rgb "#059669" lw 3 pt 9 ps 1.3
set style line 4 lc rgb "#9333EA" lw 3 pt 11 ps 1.3
set style line 5 lc rgb "#DC2626" lw 3 pt 13 ps 1.3
set style line 6 lc rgb "#64748B" lw 3 pt 3 ps 1.3

set xlabel "Rozmiar macierzy n"
set xrange [100:1020]
set xtics (128,256,384,512,768,1000)

# ==========================================
# 1. CZAS ODWROCENIA MACIERZY
# ==========================================

unset logscale y
set yrange [0:*]
set format y "%.1f"

set title "Czas odwracania macierzy"
set ylabel "Czas wykonania [s]"

set output "plots/01_odwracanie_czas.svg"

plot \
  "plot_strassen_inverse_strassen.dat" using 1:2 with linespoints ls 1 title "Strassen", \
  "plot_laderman_inverse_laderman.dat" using 1:2 with linespoints ls 2 title "Laderman"

unset output

# ==========================================
# 2. FLOP ODWROCENIA MACIERZY
# ==========================================

set title "Liczba operacji przy odwracaniu macierzy"
set ylabel "Liczba FLOP [mld]"
set format y "%.1f"

set output "plots/02_odwracanie_flop.svg"

plot \
  "plot_strassen_inverse_strassen.dat" using 1:($3/1e9) with linespoints ls 1 title "Strassen", \
  "plot_laderman_inverse_laderman.dat" using 1:($3/1e9) with linespoints ls 2 title "Laderman"

unset output

# ==========================================
# 3. CZAS FAKTORYZACJI LU
# ==========================================

set title "Faktoryzacja LU - czas wykonania"
set ylabel "Czas wykonania [s]"
set format y "%.1f"

set output "plots/03_lu_czas.svg"

plot \
  "plot_strassen_lu_strassen.dat" using 1:2 with linespoints ls 1 title "LU podstawowe", \
  "plot_strassen_lu_strassen_triangular.dat" using 1:2 with linespoints ls 3 title "LU ulepszone"

unset output

# ==========================================
# 4. FLOP FAKTORYZACJI LU
# ==========================================

set title "Faktoryzacja LU - liczba operacji"
set ylabel "Liczba FLOP [mld]"
set format y "%.1f"

set output "plots/04_lu_flop.svg"

plot \
  "plot_strassen_lu_strassen.dat" using 1:($3/1e9) with linespoints ls 1 title "LU podstawowe", \
  "plot_strassen_lu_strassen_triangular.dat" using 1:($3/1e9) with linespoints ls 3 title "LU ulepszone"

unset output

# ==========================================
# 5. SHERMAN-MORRISON - CZAS
# ==========================================

set title "Zmiana jednego elementu macierzy - czas"
set ylabel "Czas wykonania [s]"

set yrange [1e-5:*]
set logscale y
set format y "10^{%L}"

set output "plots/05_sherman_czas.svg"

plot \
  "plot_sherman_inverse_strassen.dat" using 1:2 with linespoints ls 1 title "Ponowne odwracanie", \
  "plot_sherman_sherman_morrison.dat" using 1:2 with linespoints ls 3 title "Sherman-Morrison"

unset output

# ==========================================
# 6. SHERMAN-MORRISON - FLOP
# ==========================================

set title "Zmiana jednego elementu macierzy - FLOP"
set ylabel "Liczba FLOP"

set yrange [1e4:*]

set output "plots/06_sherman_flop.svg"

plot \
  "plot_sherman_inverse_strassen.dat" using 1:3 with linespoints ls 1 title "Ponowne odwracanie", \
  "plot_sherman_sherman_morrison.dat" using 1:3 with linespoints ls 3 title "Sherman-Morrison"

unset output

# ==========================================
# 7. NEWTON-SCHULZ - DOKLADNOSC
# ==========================================

set title "Newton-Schulz - poprawa dokladnosci"
set ylabel "Maksymalny blad |AX - I|"

set yrange [1e-16:1e-1]

set output "plots/07_newton_blad.svg"

plot \
  "plot_newton_newton_approx.dat" using 1:5 with linespoints ls 2 title "Przed korekcja", \
  "plot_newton_newton_approx.dat" using 1:4 with linespoints ls 3 title "Po korekcji", \
  "plot_newton_newton_accurate.dat" using 1:4 with linespoints ls 4 title "Dokladna odwrotnosc"

unset output

# ==========================================
# 8. ZUZYCIE PAMIECI RAM
# ==========================================

unset logscale y
set yrange [0:*]
set format y "%.0f"

set title "Maksymalne zuzycie pamieci RAM"
set ylabel "Pamiec RAM [MiB]"

set output "plots/08_ram.svg"

plot \
  "plot_ram.dat" using 1:2 with linespoints ls 1 title "Strassen - inv", \
  "plot_ram.dat" using 1:3 with linespoints ls 2 title "Laderman - inv", \
  "plot_ram.dat" using 1:4 with linespoints ls 4 title "LU podstawowe", \
  "plot_ram.dat" using 1:5 with linespoints ls 3 title "LU ulepszone", \
  "plot_ram.dat" using 1:6 with linespoints ls 5 title "Octave - inv", \
  "plot_ram.dat" using 1:7 with linespoints ls 6 title "Octave - LU"

unset output

print "Wszystkie wykresy zostaly zapisane."