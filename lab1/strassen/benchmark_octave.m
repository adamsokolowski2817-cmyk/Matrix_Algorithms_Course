
function benchmark_octave(maxN, step, repeats)

  % ========================================================
  % 1. SPRAWDZENIE PARAMETROW
  % ========================================================

  if maxN < 1 || step < 1 || repeats < 1
    error("Parametry musza byc dodatnie");
  endif

  % Otwieramy plik CSV do zapisu wynikow.
  file = fopen("octave_results.csv", "w");

  if file == -1
    error("Nie mozna utworzyc pliku CSV");
  endif

  fprintf(file, ...
    "n,time_s,flops_theoretical,gflops_theoretical,error_sample\n");

  % ========================================================
  % 2. GENEROWANIE MACIERZY O ROZNYCH WYMIARACH
  % ========================================================

  for n = 1:step:maxN

    % Powtarzalne losowanie.
    rng(12345 + n, "twister");

    % Liczby float64 z przedzialu (0.00000001, 1.0).
    low = 0.00000002;
    high = 0.99999998;

    A = low + (high - low) * rand(n, n);
    B = low + (high - low) * rand(n, n);

    % ======================================================
    % 3. MNOZENIE MACIERZY WBUDOWANA BIBLIOTEKA
    % ======================================================

    % Rozgrzewka biblioteki.
    C = A * B;


    bestTime = Inf;
    batch = 1;

    for r = 1:repeats

      while true

        startTime = tic();

        % Wykonujemy serie mnozen zamiast pojedynczego.
        for t = 1:batch
          C = A * B;
        endfor

        elapsed = toc(startTime);

        % Minimum 10 ms pomiaru.
        if elapsed >= 0.01 || batch >= 65536
          break;
        endif

        batch = batch * 2;

      endwhile

      % Sredni czas jednego mnozenia.
      avgTime = elapsed / batch;

      if avgTime < bestTime
        bestTime = avgTime;
      endif

    endfor


    

    % ======================================================
    % 4. TEORETYCZNA LICZBA FLOP
    % ======================================================

    % Klasyczne mnozenie:
    % n^3 mnozen i n^2*(n-1) dodawan.
    %
    % Nie jest to rzeczywisty licznik operacji BLAS.

    flopCount = 2 * n^3 - n^2;

    gflops = 0;

    if bestTime > 0
      gflops = flopCount / bestTime / 1e9;
    endif

    % ======================================================
    % 5. KONTROLA POPRAWNOSCI WYNIKU
    % ======================================================

    positions = [
      1, 1;
      ceil(n / 2), ceil(n / 2);
      n, n
    ];

    maxError = 0;

    for t = 1:3

      i = positions(t, 1);
      j = positions(t, 2);

      % Klasyczny iloczyn skalarny.
      expected = sum(A(i, :) .* B(:, j)');

      difference = abs(C(i, j) - expected);
      maxError = max(maxError, difference);

    endfor

    % ======================================================
    % 6. ZAPIS POMIAROW DO CSV
    % ======================================================

    fprintf(file, "%.0f,%.17g,%.0f,%.17g,%.17g\n", ...
      n, bestTime, flopCount, gflops, maxError);

    fprintf("n=%d, czas=%.9f s, GFLOPS=%.4f\n", ...
      n, bestTime, gflops);

  endfor

  fclose(file);

  disp("Zapisano octave_results.csv");

endfunction
