
function wykresy()

    % Silnik do generowania wykresow bez wyswietlania okien.
    graphics_toolkit("gnuplot");

  % ==========================================================
  % 1. ODCZYT WYNIKOW STRASSENA I OCTAVE
  % ==========================================================

  % Pomijamy pierwszy wiersz z nazwami kolumn.
  nim = dlmread("strassen_results.csv", ",", 1, 0);
  octave = dlmread("octave_results.csv", ",", 1, 0);

  % Wybieramy rozmiary obecne w obu plikach.
  [sizes, idxNim, idxOctave] = intersect(nim(:,1), octave(:,1));

  if isempty(sizes)
    error("Brak wspolnych rozmiarow macierzy");
  endif

  nim = nim(idxNim, :);
  octave = octave(idxOctave, :);

  % Kolumny Strassena:
  % 1 - n
  % 2 - czas [s]
  % 3 - FLOP
  % 4 - mnozenia
  % 5 - dodawania
  % 6 - odejmowania
  % 7 - dzielenia
  % 8 - GFLOPS
  % 9 - blad

  % Kolumny Octave:
  % 1 - n
  % 2 - czas [s]
  % 3 - teoretyczne FLOP
  % 4 - teoretyczne GFLOPS
  % 5 - blad

  % Dla skali logarytmicznej pomijamy czasy zerowe.
  timeNim = nim(:,2);
  timeOctave = octave(:,2);

  timeNim(timeNim <= 0) = NaN;
  timeOctave(timeOctave <= 0) = NaN;


  % ==========================================================
  % 2. WYKRES CZASU WYKONANIA
  % ==========================================================

  figure("visible", "off");

  semilogy(sizes, timeNim, "b-", "linewidth", 1.5);
  hold on;

  semilogy(sizes, timeOctave, "r-", "linewidth", 1.5);

  title("Czas mnozenia macierzy");
  xlabel("Rozmiar macierzy n");
  ylabel("Czas wykonania [s]");

  legend("Strassen Nim", "Octave BLAS", ...
         "location", "northwest");

  grid on;

  print("wykres_czas.png", "-dpng", "-r200");
  close();


  % ==========================================================
  % 3. WYKRES LICZBY OPERACJI FLOP
  % ==========================================================

  figure("visible", "off");

  semilogy(sizes, nim(:,3), "b-", "linewidth", 1.5);
  hold on;

  semilogy(sizes, octave(:,3), "r-", "linewidth", 1.5);

  title("Liczba operacji zmiennoprzecinkowych");
  xlabel("Rozmiar macierzy n");
  ylabel("Liczba FLOP");

  legend("Strassen - licznik FLOP", ...
         "Model klasyczny - teoretyczne FLOP", ...
         "location", "northwest");

  grid on;

  print("wykres_flop.png", "-dpng", "-r200");
  close();


  % ==========================================================
  % 4. WYKRES WYDAJNOSCI GFLOPS
  % ==========================================================

  figure("visible", "off");

  plot(sizes, nim(:,8), "b-", "linewidth", 1.5);
  hold on;

  plot(sizes, octave(:,4), "r-", "linewidth", 1.5);

  title("Wydajnosc mnozenia macierzy");
  xlabel("Rozmiar macierzy n");
  ylabel("GFLOPS");

  legend("Strassen Nim", ...
         "Octave - model klasyczny / czas", ...
         "location", "northwest");

  grid on;

  print("wykres_gflops.png", "-dpng", "-r200");
  close();


  % ==========================================================
  % 5. STRUKTURA OPERACJI ALGORYTMU STRASSENA
  % ==========================================================

  figure("visible", "off");

  plot(sizes, nim(:,4), "b-", "linewidth", 1.5);
  hold on;

  plot(sizes, nim(:,5), "g-", "linewidth", 1.5);
  plot(sizes, nim(:,6), "r-", "linewidth", 1.5);

  title("Rodzaje operacji w algorytmie Strassena");
  xlabel("Rozmiar macierzy n");
  ylabel("Liczba operacji");

  legend("Mnozenia", "Dodawania", "Odejmowania", ...
         "location", "northwest");

  grid on;

  print("wykres_operacje.png", "-dpng", "-r200");
  close();


  % ==========================================================
  % 6. ZBIORCZA PLANSZA DO SPRAWOZDANIA
  % ==========================================================

  figure("visible", "off", ...
         "position", [100, 100, 1500, 450]);

  % Wykres 1 - czas.
  subplot(1, 3, 1);

  semilogy(sizes, timeNim, "b-", ...
           sizes, timeOctave, "r-");

  title("Czas wykonania");
  xlabel("Rozmiar n");
  ylabel("Czas [s]");
  legend("Strassen", "Octave", "location", "northwest");
  grid on;


  % Wykres 2 - FLOP.
  subplot(1, 3, 2);

  semilogy(sizes, nim(:,3), "b-", ...
           sizes, octave(:,3), "r-");

  title("Liczba FLOP");
  xlabel("Rozmiar n");
  ylabel("FLOP");
  grid on;


  % Wykres 3 - GFLOPS.
  subplot(1, 3, 3);

  plot(sizes, nim(:,8), "b-", ...
       sizes, octave(:,4), "r-");

  title("Wydajnosc GFLOPS");
  xlabel("Rozmiar n");
  ylabel("GFLOPS");
  grid on;

  print("wykres_porownanie.png", "-dpng", "-r200");
  close();

  disp("Wszystkie wykresy zostaly wygenerowane!");

endfunction
