[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [ValidateSet('16:9', '9:16', '4:3', '3:4', '1:1')]
    [string]$AspectRatio = '9:16',

    [switch]$CreateZip,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-TargetSize {
    param([string]$Ratio)
    switch ($Ratio) {
        '9:16' { return @{ Width = 1080; Height = 1920 } }
        '16:9' { return @{ Width = 1920; Height = 1080 } }
        '4:3' { return @{ Width = 1440; Height = 1080 } }
        '3:4' { return @{ Width = 1080; Height = 1440 } }
        '1:1' { return @{ Width = 1080; Height = 1080 } }
    }
}

function Test-HasTransparency {
    param([System.Drawing.Bitmap]$Bitmap)

    $stepX = [Math]::Max(1, [int]($Bitmap.Width / 24))
    $stepY = [Math]::Max(1, [int]($Bitmap.Height / 24))
    for ($y = 0; $y -lt $Bitmap.Height; $y += $stepY) {
        for ($x = 0; $x -lt $Bitmap.Width; $x += $stepX) {
            if ($Bitmap.GetPixel($x, $y).A -lt 250) {
                return $true
            }
        }
    }
    return $false
}

function Save-NormalizedScene {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$TargetWidth,
        [int]$TargetHeight
    )

    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    try {
        $targetRatio = $TargetWidth / [double]$TargetHeight
        $sourceRatio = $source.Width / [double]$source.Height

        if ($sourceRatio -gt $targetRatio) {
            $cropHeight = $source.Height
            $cropWidth = [int][Math]::Floor($cropHeight * $targetRatio)
            $cropX = [int][Math]::Floor(($source.Width - $cropWidth) / 2)
            $cropY = 0
        }
        else {
            $cropWidth = $source.Width
            $cropHeight = [int][Math]::Floor($cropWidth / $targetRatio)
            $cropX = 0
            $cropY = [int][Math]::Floor(($source.Height - $cropHeight) / 2)
        }

        $output = New-Object System.Drawing.Bitmap(
            $TargetWidth,
            $TargetHeight,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($output)
            try {
                $graphics.Clear([System.Drawing.Color]::Black)
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $destinationRectangle = New-Object System.Drawing.Rectangle(0, 0, $TargetWidth, $TargetHeight)
                $sourceRectangle = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropWidth, $cropHeight)
                $graphics.DrawImage(
                    $source,
                    $destinationRectangle,
                    $sourceRectangle,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            }
            finally {
                $graphics.Dispose()
            }
            $output.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $output.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

$manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $manifestFullPath -PathType Leaf)) {
    throw "Manifest not found: $manifestFullPath"
}

$outputFullPath = [System.IO.Path]::GetFullPath($OutputDir)
$outputRoot = [System.IO.Path]::GetPathRoot($outputFullPath)
if ($outputFullPath.TrimEnd('\\') -eq $outputRoot.TrimEnd('\\')) {
    throw 'OutputDir must not be a drive root.'
}

$items = @(Get-Content -LiteralPath $manifestFullPath -Raw -Encoding UTF8 | ConvertFrom-Json)
if ($items.Count -eq 0) {
    throw 'Manifest is empty.'
}

$items = @($items | Sort-Object { [int]$_.index })
for ($i = 0; $i -lt $items.Count; $i++) {
    $expectedIndex = $i + 1
    if ([int]$items[$i].index -ne $expectedIndex) {
        throw "Manifest indices must be continuous from 1. Expected $expectedIndex."
    }
    if ($items[$i].kind -notin @('transparent', 'scene')) {
        throw "Invalid kind at index $expectedIndex. Use transparent or scene."
    }
    $sourcePath = [System.IO.Path]::GetFullPath([string]$items[$i].source)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Source file not found at index $expectedIndex`: $sourcePath"
    }
    $items[$i].source = $sourcePath
}

if (-not (Test-Path -LiteralPath $outputFullPath)) {
    New-Item -ItemType Directory -Path $outputFullPath | Out-Null
}

$digits = [Math]::Max(2, $items.Count.ToString().Length)
$nameFormat = '图片{0:D' + $digits + '}.png'
$targetSize = Get-TargetSize -Ratio $AspectRatio
Add-Type -AssemblyName System.Drawing

$mappingPath = Join-Path $outputFullPath '00_图片编号清单.md'
$zipPath = if ($CreateZip) { "$outputFullPath.zip" } else { $null }
$plannedTargets = @(
    $items | ForEach-Object {
        Join-Path $outputFullPath ($nameFormat -f [int]$_.index)
    }
)
$plannedTargets += $mappingPath
if ($zipPath) {
    $plannedTargets += $zipPath
}

if (-not $Force) {
    $existingTargets = @($plannedTargets | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingTargets.Count -gt 0) {
        throw "Output targets already exist. Choose a new OutputDir or use -Force only when replacement is intended:`n$($existingTargets -join [Environment]::NewLine)"
    }
}

$mappingLines = @(
    '# 图片编号清单',
    '',
    "画幅：$AspectRatio（$($targetSize.Width)×$($targetSize.Height)）",
    '',
    '| 文件名 | 类型 | 说明 |',
    '|---|---|---|'
)

foreach ($item in $items) {
    $targetName = $nameFormat -f [int]$item.index
    $targetPath = Join-Path $outputFullPath $targetName

    if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
        throw "Target already exists: $targetPath. Use -Force only when replacement is intended."
    }

    if ($item.kind -eq 'transparent') {
        $bitmap = [System.Drawing.Bitmap]::FromFile([string]$item.source)
        try {
            if (-not (Test-HasTransparency -Bitmap $bitmap)) {
                throw "Transparent asset has no detectable transparent pixels: $($item.source)"
            }
        }
        finally {
            $bitmap.Dispose()
        }
        Copy-Item -LiteralPath ([string]$item.source) -Destination $targetPath -Force:$Force
    }
    else {
        Save-NormalizedScene `
            -SourcePath ([string]$item.source) `
            -DestinationPath $targetPath `
            -TargetWidth $targetSize.Width `
            -TargetHeight $targetSize.Height
    }

    $kindLabel = if ($item.kind -eq 'transparent') { '透明素材' } else { '完整场景' }
    $label = [string]$item.label
    $mappingLines += "| $targetName | $kindLabel | $label |"
}

[System.IO.File]::WriteAllText(
    $mappingPath,
    ($mappingLines -join [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)

if ($CreateZip) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $outputFullPath,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}

[PSCustomObject]@{
    OutputDir = $outputFullPath
    AssetCount = $items.Count
    AspectRatio = $AspectRatio
    Width = $targetSize.Width
    Height = $targetSize.Height
    Mapping = $mappingPath
    Zip = $zipPath
}

