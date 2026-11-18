# POROWNANIE STRASSEN - LADERMAN - OCTAVE
# ==========================================================

# Pliki CSV z wynikami pomiarow.
strassen = "strassen_results.csv"
laderman = "../laderman/laderman_results.csv"
octave = "octave_results.csv"


# ==========================================================
# USTAWIENIA WYGLADU WYKRESOW
# ==========================================================

set datafile separator ","

set terminal pngcairo size 1400,800 enhanced font "Arial,12"

# Legenda nad wykresem, poza obszarem danych.
set key outside top center vertical

# Siatka i opisy osi.
set grid xtics ytics
set xlabel "Rozmiar macierzy n"

# Czytelna os X dla pomiarow od 1 do 100.
set xrange [0:100]
set xtics 0,20,100

# Drobniejsze linie siatki.
set grid linewidth 0.5

# Marginesy.
set lmargin 12
set rmargin 4
set bmargin 5


# ==========================================================
# WYKRES 1: CZAS WYKONANIA
# ==========================================================

set output "wykres_czas.png"
set title "Czas mnozenia macierzy"
set ylabel "Czas wykonania [s]"
set logscale y

# Zerowe czasy nie sa rysowane na osi logarytmicznej.
plot strassen every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Strassen (Nim)", \
     laderman every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Laderman (Nim)", \
     octave every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Octave (BLAS)"

unset logscale y


# ==========================================================
# WYKRES 2: LICZBA OPERACJI FLOP
# ==========================================================

set output "wykres_flop.png"
set title "Liczba operacji zmiennoprzecinkowych"
set ylabel "Liczba FLOP"
set logscale y

plot strassen every ::1 using 1:3 with lines lw 2 title "Strassen - zliczone", \
     laderman every ::1 using 1:3 with lines lw 2 title "Laderman - zliczone", \
     octave every ::1 using 1:3 with lines lw 2 title "Klasyczne - model teoretyczny"

unset logscale y


# ==========================================================
# WYKRES 3: WYDAJNOSC GFLOPS
# ==========================================================

set output "wykres_gflops.png"
set title "Wydajnosc mnozenia macierzy"
set ylabel "GFLOPS"

plot strassen every ::1 using 1:8 with lines lw 2 title "Strassen (Nim)", \
     laderman every ::1 using 1:8 with lines lw 2 title "Laderman (Nim)", \
     octave every ::1 using 1:4 with lines lw 2 title "Octave - model klasyczny / czas"


# ==========================================================
# WYKRES 4: ZBIORCZE POROWNANIE DO SPRAWOZDANIA
# ==========================================================

set terminal pngcairo size 2100,750 enhanced font "Arial,11"
set output "wykres_porownanie.png"

set multiplot layout 1,3 title "Porownanie algorytmow mnozenia macierzy"

# Wykres A - czas wykonania.
set title "Czas wykonania"
set ylabel "Czas [s]" offset 1,0
set logscale y

plot strassen every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Strassen", \
     laderman every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Laderman", \
     octave every ::1 using 1:($2>0?$2:1/0) with lines lw 2 title "Octave"


# Wykres B - liczba FLOP.
set title "Liczba FLOP"
set ylabel "FLOP" offset 0,0

plot strassen every ::1 using 1:3 with lines lw 2 title "Strassen", \
     laderman every ::1 using 1:3 with lines lw 2 title "Laderman", \
     octave every ::1 using 1:3 with lines lw 2 title "Model klasyczny"

unset logscale y


# Wykres C - GFLOPS.
set title "Wydajnosc"
set ylabel "GFLOPS"

plot strassen every ::1 using 1:8 with lines lw 2 title "Strassen", \
     laderman every ::1 using 1:8 with lines lw 2 title "Laderman", \
     octave every ::1 using 1:4 with lines lw 2 title "Octave"

unset multiplot
set output

# ==========================================================
# WYKRES 5: SZCZYTOWE ZUZYCIE PAMIECI RAM
# ==========================================================

set terminal pngcairo size 1400,800 enhanced font "Arial,12"
set output "wykres_pamiec.png"
set title "Szczytowe zuzycie pamieci RAM"
set xlabel "Rozmiar macierzy n"
set ylabel "Peak Working Set [MiB]"
set xrange [100:540]
set xtics 128,128,512
set key outside top center vertical
set grid
plot "pamiec_results.csv" every ::1 using 1:2 with linespoints lw 2 pt 7 title "Strassen Nim", "pamiec_results.csv" every ::1 using 1:3 with linespoints lw 2 pt 5 title "Laderman Nim", "pamiec_results.csv" every ::1 using 1:4 with linespoints lw 2 pt 9 title "Octave"
set output

