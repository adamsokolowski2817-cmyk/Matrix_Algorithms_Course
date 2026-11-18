# BENCHMARK ZUZYCIA RAM
# LAB 2 - ODWROCENIA I FAKTORYZACJA LU

$ErrorActionPreference = "Stop"

$base = $PSScriptRoot

$strassen = Join-Path $base "memory\mem_strassen.exe"
$laderman = Join-Path $base "memory\mem_laderman.exe"

$octave = "C:\Program Files\GNU Octave\Octave-11.3.0\mingw64\bin\octave-cli.exe"

# Pierwsza seria - wieksze rozmiary.
$sizes = @(128, 256, 384, 512, 768, 1000)

# Po sprawdzeniu mozna dodac 768 i 1000.
# $sizes = @(128, 256, 384, 512, 768, 1000)

$cutoff = 32
$repeats = 3

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$useOctave = Test-Path $octave


# 1. POMIAR MAKSYMALNEGO ZUZYCIA RAM

function Measure-Memory {

    param(
        [string]$program,
        [string[]]$arguments
    )

    # Konfiguracja procesu.
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $program
    $info.WorkingDirectory = $base
    $info.UseShellExecute = $false

    # Poprawne przekazanie argumentow, takze do Octave.
    $quotedArgs = foreach ($arg in $arguments) {
        '"' + $arg.Replace('"', '\"') + '"'
    }

    $info.Arguments = $quotedArgs -join " "

    # Uruchomienie procesu.
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info

    $peak = 0L

    try {
        if (-not $process.Start()) {
            throw "Nie udalo sie uruchomic: $program"
        }

        # Obserwujemy maksymalne zuzycie RAM.
        while ($true) {
            $process.Refresh()

            try {
                $memory = [long]$process.PeakWorkingSet64

                if ($memory -gt $peak) {
                    $peak = $memory
                }
            }
            catch {
                # Proces mogl sie juz zakonczyc.
            }

            if ($process.HasExited) {
                break
            }

            Start-Sleep -Milliseconds 5
        }

        $process.WaitForExit()

        # Kontrola poprawnego zakonczenia.
        $exitCode = $process.ExitCode

        if ($exitCode -ne 0) {
            throw "Blad programu: $program (kod: $exitCode)"
        }

        if ($peak -eq 0) {
            throw "Nie udalo sie odczytac pamieci"
        }

        return [double]$peak / 1MB
    }
    finally {
        $process.Dispose()
    }
}



# 2. MEDIANA Z KILKU POMIAROW
function Measure-Median {

    param(
        [string]$program,
        [string[]]$arguments
    )

    $values = @()

    for ($rep = 0; $rep -lt $repeats; $rep++) {
        $values += Measure-Memory `
            -program $program `
            -arguments $arguments
    }

    $values = @($values | Sort-Object)

    return $values[[int][math]::Floor($values.Count / 2)]
}


# 3. FORMATOWANIE DO CSV
function Fmt {

    param([object]$value)

    if ($null -eq $value) {
        return ""
    }

    return ([double]$value).ToString("F3", $culture)
}


# 4. BENCHMARK
$lines = [System.Collections.Generic.List[string]]::new()

$lines.Add(
    "n,inverse_strassen_mib,inverse_laderman_mib,lu_strassen_mib,lu_improved_mib,octave_inverse_mib,octave_lu_mib"
)

foreach ($n in $sizes) {

    Write-Host "`n=== Macierz ${n}x${n} ==="

    # Strassen - odwracanie.
    $invStrassen = Measure-Median `
        -program $strassen `
        -arguments @("inverse", "$n", "$cutoff")

    # Laderman - odwracanie.
    $invLaderman = Measure-Median `
        -program $laderman `
        -arguments @("inverse", "$n", "$cutoff")

    # Podstawowa faktoryzacja LU.
    $luBasic = Measure-Median `
        -program $strassen `
        -arguments @("lu", "$n", "$cutoff")

    # Ulepszona faktoryzacja LU.
    $luImproved = Measure-Median `
        -program $strassen `
        -arguments @("lu_improved", "$n", "$cutoff")


    # GNU Octave - ta sama macierz.
    $octInverse = $null
    $octLU = $null

    if ($useOctave) {

        $matrix = "n=$n;A=0.8*eye(n)+(0.01/n)*(ones(n)-eye(n));"

        $inverseExpression =
            $matrix + "X=inv(A);disp(X(1,1));"

        $luExpression =
            $matrix + "[L,U,P]=lu(A);disp(U(1,1));"

        $octInverse = Measure-Median `
            -program $octave `
            -arguments @("--quiet", "--eval", $inverseExpression)

        $octLU = Measure-Median `
            -program $octave `
            -arguments @("--quiet", "--eval", $luExpression)
    }


    Write-Host "Inverse Strassen: $invStrassen MiB"
    Write-Host "Inverse Laderman: $invLaderman MiB"
    Write-Host "LU podstawowe:    $luBasic MiB"
    Write-Host "LU ulepszone:     $luImproved MiB"

    if ($useOctave) {
        Write-Host "Octave inverse:   $octInverse MiB"
        Write-Host "Octave LU:        $octLU MiB"
    }


    $row = @(
        "$n",
        (Fmt $invStrassen),
        (Fmt $invLaderman),
        (Fmt $luBasic),
        (Fmt $luImproved),
        (Fmt $octInverse),
        (Fmt $octLU)
    ) -join ","

    $lines.Add($row)
}


# 5. ZAPIS DO CSV
$output = Join-Path $base "memory_results.csv"

$lines | Set-Content -Path $output -Encoding ascii

Write-Host "`nZapisano: $output"
