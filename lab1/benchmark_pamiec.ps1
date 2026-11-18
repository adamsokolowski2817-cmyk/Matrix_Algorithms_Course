# BENCHMARK ZUZYCIA PAMIECI RAM
# STRASSEN - LADERMAN - OCTAVE


$ErrorActionPreference = "Stop"

$base = $PSScriptRoot
$strassen = Join-Path $base "strassen\strassen.exe"
$laderman = Join-Path $base "laderman\laderman.exe"

$octave = "C:\Program Files\GNU Octave\Octave-11.3.0\mingw64\bin\octave-cli.exe"

$sizes = @(128, 256, 384, 512)
$cutoff = 32


=
# 1. POMIAR PAMIECI POJEDYNCZEGO PROCESU

function Measure-Memory {

    param(
        [string]$program,
        [string[]]$arguments
    )

    # Uruchamiamy nowy proces.
    $process = Start-Process `
        -FilePath $program `
        -ArgumentList $arguments `
        -WorkingDirectory $base `
        -NoNewWindow `
        -PassThru

    $peak = 0L

    # Obserwujemy maksymalne zuzycie pamieci.
    while (-not $process.HasExited) {

        try {
            $process.Refresh()

            $memory = $process.PeakWorkingSet64

            if ($memory -gt $peak) {
                $peak = $memory
            }
        }
        catch {
            # Proces mogl juz sie zakonczyc.
        }

        Start-Sleep -Milliseconds 5
    }

    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Warning "Proces zakonczyl sie kodem $($process.ExitCode)"
    }

    if ($peak -eq 0) {
        throw "Nie udalo sie odczytac pamieci procesu"
    }

    
    return [math]::Round($peak / 1MB, 3)
}


# 2. POMIAR TRZECH METOD

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("n,strassen_mib,laderman_mib,octave_mib")

$culture = [System.Globalization.CultureInfo]::InvariantCulture

foreach ($n in $sizes) {

    Write-Host "`nRozmiar macierzy: ${n}x${n}"

    # Strassen w Nim.
    $memStrassen = Measure-Memory `
        -program $strassen `
        -arguments @("--memcase", "$n", "$cutoff")

    # Laderman w Nim.
    $memLaderman = Measure-Memory `
        -program $laderman `
        -arguments @("--memcase", "$n", "$cutoff")

    
    $expression = "n=$n;A=rand(n,n);B=rand(n,n);C=A*B;disp(C(1,1));"

    $memOctave = Measure-Memory `
        -program $octave `
        -arguments @("--quiet", "--eval", $expression)

    Write-Host "Strassen: $memStrassen MiB"
    Write-Host "Laderman: $memLaderman MiB"
    Write-Host "Octave:   $memOctave MiB"

   
    $a = $memStrassen.ToString("F3", $culture)
    $b = $memLaderman.ToString("F3", $culture)
    $c = $memOctave.ToString("F3", $culture)

    $lines.Add("$n,$a,$b,$c")
}



# 3. ZAPIS WYNIKOW


$output = Join-Path $base "strassen\pamiec_results.csv"
$lines | Set-Content -Path $output -Encoding ascii

Write-Host "`nZapisano pamiec_results.csv"
