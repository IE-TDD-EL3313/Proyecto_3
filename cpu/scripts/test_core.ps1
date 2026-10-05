$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    New-Item -ItemType Directory -Force -Path 'sim/results' | Out-Null
    foreach ($name in @('tb_stage3','tb_stage4','tb_riscv_core','tb_core_edges','tb_processor_subsystem')) {
        & iverilog -g2012 -s $name -o "sim/results/$name.vvp" -c core_sources.f "tb/$name.sv"
        if ($LASTEXITCODE -ne 0) { throw "Error compilando $name" }
        $result = @(& vvp "sim/results/$name.vvp")
        $simExit = $LASTEXITCODE
        $result | Tee-Object -FilePath "sim/results/$name.log"
        if ($simExit -ne 0) { throw "Fallo en $name" }
    }
    Write-Host 'PASS: 5 pruebas de la entrega CPU + memorias; sin modulos perifericos'
} finally { Pop-Location }
