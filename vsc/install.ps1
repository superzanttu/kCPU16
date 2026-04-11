# install.ps1
# Asentaa kCPU16 Assembler -extensionin VS Codeen kopioimalla
# extension-kansion .vscode/extensions/-hakemistoon.
# Suorita tama skripti projektin juurihakemistosta.

$extensionName = "kcpu16-asm-0.1.0"
$source = Join-Path $PSScriptRoot "kcpu16-asm"
$target = Join-Path $env:USERPROFILE ".vscode\extensions\$extensionName"

if (-not (Test-Path $source)) {
    Write-Error "Extension-kansio ei loydy: $source"
    exit 1
}

if (Test-Path $target) {
    Write-Host "Poistetaan vanha versio: $target"
    Remove-Item $target -Recurse -Force
}

Write-Host "Kopioidaan: $source -> $target"
Copy-Item $source $target -Recurse

Write-Host ""
Write-Host "Asennus valmis! Kaynnnista VS Code uudelleen aktivoidaksesi kCPU16-syntaksivarityksen."
Write-Host "Tiedostot .k16 tunnistetaan automaattisesti."
Write-Host ".asm-tiedostoille kay .vscode/settings.json jo maaritelty (files.associations)."
