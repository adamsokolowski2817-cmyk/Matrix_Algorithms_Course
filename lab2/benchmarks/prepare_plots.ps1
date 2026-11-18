$ErrorActionPreference = "Stop"
$base = $PSScriptRoot

# Finalne pomiary Newtona dla n = 128..512.
$newtonSmall = "newton_large_c32_final.csv"

if (-not (Test-Path (Join-Path $base $newtonSmall))) {
    $newtonSmall = "newton.csv"
}

$groups = @{
    strassen = @(
        "strassen_large_c32.csv",
        "strassen_n768_c32.csv",
        "strassen_n1000_c32.csv"
    )

    laderman = @(
        "laderman_large_c32.csv",
        "laderman_n768_c32.csv",
        "laderman_n1000_c32.csv"
    )

    sherman = @(
        "sherman_large_c32.csv",
        "sherman_n768_c32.csv",
        "sherman_n1000_c32.csv"
    )

    newton = @(
        $newtonSmall,
        "newton_n768_c32_final.csv",
        "newton_n1000_c32_final.csv"
    )
}

$expectedSizes = @(128, 256, 384, 512, 768, 1000)

foreach ($group in @("strassen", "laderman", "sherman", "newton")) {

    $rows = @(
        foreach ($file in $groups[$group]) {
            $path = Join-Path $base $file

            if (-not (Test-Path $path)) {
                throw "Brakuje pliku: $path"
            }

            Import-Csv $path
        }
    )

    $algorithms = @(
        $rows | Select-Object -ExpandProperty algorithm -Unique
    )

    foreach ($algorithm in $algorithms) {

        $selected = @(
            $rows |
                Where-Object { $_.algorithm -eq $algorithm } |
                Sort-Object { [int]$_.n }
        )

        $sizes = @($selected | ForEach-Object { [int]$_.n })

        if (($sizes -join ",") -ne ($expectedSizes -join ",")) {
            throw "Niekompletne dane: $group / $algorithm"
        }

        $lines = @(
            "# n time_s flops error error_before iterations"
        )

        foreach ($r in $selected) {

            $before = if ($r.error_before) {
                $r.error_before
            } else {
                "NaN"
            }

            $iterations = if ($r.iterations) {
                $r.iterations
            } else {
                "0"
            }

            $lines += "$($r.n) $($r.time_s) $($r.flops) $($r.error) $before $iterations"
        }

        $output = Join-Path $base "plot_${group}_${algorithm}.dat"

        $lines | Set-Content -Path $output -Encoding ascii

        Write-Host "OK: $(Split-Path $output -Leaf)"
    }
}

# Osobno przygotowujemy dane RAM.
$ramPath = Join-Path $base "memory_results.csv"

if (-not (Test-Path $ramPath)) {
    throw "Brakuje memory_results.csv"
}

$ramRows = @(Import-Csv $ramPath | Sort-Object { [int]$_.n })

$ramSizes = @($ramRows | ForEach-Object { [int]$_.n })

if (($ramSizes -join ",") -ne ($expectedSizes -join ",")) {
    throw "Niekompletne dane RAM"
}

$ramLines = @(
    "# n invStr invLad luBasic luImproved octInv octLu"
)

foreach ($r in $ramRows) {
    $ramLines += "$($r.n) $($r.inverse_strassen_mib) $($r.inverse_laderman_mib) $($r.lu_strassen_mib) $($r.lu_improved_mib) $($r.octave_inverse_mib) $($r.octave_lu_mib)"
}

$ramLines | Set-Content `
    -Path (Join-Path $base "plot_ram.dat") `
    -Encoding ascii

Write-Host "`nDane do wykresow przygotowane."
