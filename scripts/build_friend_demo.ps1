param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath,
    [string]$OutputRoot = (Join-Path (Get-Location) "releases")
)

$projectRoot = (Get-Location).Path
$stageDirectory = Join-Path $OutputRoot "ActionDash_Demo_WASD_U"
$zipPath = Join-Path $OutputRoot "ActionDash_Demo_WASD_U_Windows.zip"
$executablePath = Join-Path $stageDirectory "ActionDash_Demo_WASD_U.exe"
$localTemp = Join-Path $projectRoot ".tmp-godot"

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "No se encontró Godot en: $GodotPath"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
if (Test-Path -LiteralPath $stageDirectory) {
    Remove-Item -LiteralPath $stageDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
New-Item -ItemType Directory -Force -Path $stageDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $localTemp | Out-Null

$env:TEMP = $localTemp
$env:TMP = $localTemp
& $GodotPath --headless --path $projectRoot --export-release "ActionDash Demo - Windows" $executablePath
if ($LASTEXITCODE -ne 0) {
    throw "Godot no pudo exportar la demo. Codigo: $LASTEXITCODE"
}

$exportedFiles = @(Get-ChildItem -LiteralPath $stageDirectory -File)
if ($exportedFiles.Count -eq 0) {
    throw "La exportacion termino sin archivos en: $stageDirectory"
}

Compress-Archive -Path (Join-Path $stageDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal
Write-Output "Demo creada: $zipPath"
Write-Output "Archivos incluidos: $($exportedFiles.Name -join ', ')"
