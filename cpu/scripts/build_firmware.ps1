param(
    [string]$Toolchain = 'C:/AMDDesignTools/2026.1/gnu/riscv/nt/bin',
    [ValidateSet('integration','handoff')][string]$Program = 'integration'
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    New-Item -ItemType Directory -Force -Path 'build/firmware' | Out-Null
    $prefix = Join-Path $Toolchain 'riscv64-unknown-elf-'
    & ($prefix + 'as.exe') -march=rv32i -mabi=ilp32 -o "build/firmware/$Program.o" "firmware/$Program.S"
    if ($LASTEXITCODE -ne 0) { throw 'Error de ensamblador' }
    & ($prefix + 'ld.exe') -m elf32lriscv --no-relax -T firmware/link.ld -o "build/firmware/$Program.elf" "build/firmware/$Program.o"
    if ($LASTEXITCODE -ne 0) { throw 'Error de enlazador' }
    & ($prefix + 'objcopy.exe') -O binary "build/firmware/$Program.elf" "build/firmware/$Program.bin"
    if ($LASTEXITCODE -ne 0) { throw 'Error de objcopy' }
    $bytes = [IO.File]::ReadAllBytes((Join-Path (Get-Location) "build/firmware/$Program.bin"))
    if ($bytes.Length -gt 8192 -or $bytes.Length % 4 -ne 0) { throw 'Imagen ROM invalida' }
    $words = for ($i=0; $i -lt 2048; $i++) {
        if (4*$i -lt $bytes.Length) { '{0:x8}' -f [BitConverter]::ToUInt32($bytes,4*$i) }
        else { '00000013' }
    }
    $words | Set-Content -Encoding ascii "firmware/$Program.hex"
    & ($prefix + 'objdump.exe') -d -M no-aliases "build/firmware/$Program.elf" | Set-Content -Encoding ascii "build/firmware/$Program.dis"
    if ($LASTEXITCODE -ne 0) { throw 'Error de objdump' }
    Write-Host "ROM generada: $($bytes.Length) bytes de programa, capacidad 8192 bytes"
} finally { Pop-Location }
