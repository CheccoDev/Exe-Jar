Clear-Host
Write-Host "Paste the results copied on WinPrefetchView"
$lines = @()
while ($true) {
    $line = Read-Host
    if ([string]::IsNullOrWhiteSpace($line)) { break }
    $lines += $line
}
Clear-Host

$sicuri = @()
$sospetti = @()
$nonTrovati = @()

# Lista di stringhe cheat per il ModAnalyzer
$cheatStrings = @(
    "AimAssist","AnchorTweaks","AutoAnchor","AutoCrystal","AutoDoubleHand",
    "AutoHitCrystal","AutoPot","AutoTotem","AutoArmor","InventoryTotem",
    "Hitboxes","JumpReset","LegitTotem","PingSpoof","SelfDestruct",
    "ShieldBreaker","TriggerBot","Velocity","AxeSpam","WebMacro","FastPlace",
    "clicker","AutoClicker"
)

# Funzione ModAnalyzer: ritorna la stringa del cheat se presente
function Get-CheatReason {
    param([string]$filePath)
    try {
        $content = Get-Content -Raw -ErrorAction Stop $filePath
        foreach ($string in $cheatStrings) {
            if ($content -match $string) {
                return $string
            }
        }
    } catch {}
    return $null
}

function Get-ZoneIdentifier {
    param([string]$filePath)
    $ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
    if ($ads -match "HostUrl=(.+)") {
        return $matches[1]
    }
    return $null
}

foreach ($line in $lines) {
    if ($line -match '([A-Z]:\\.+?)\\VOLUME') {
        $fullPath = $matches[1]

        if (Test-Path $fullPath) {
            $item = Get-Item $fullPath
            $nome = $item.Name
            $dir = $item.DirectoryName

            $isSystemAttr = $item.Attributes -band [System.IO.FileAttributes]::System
            try {
                $sig = Get-AuthenticodeSignature $fullPath
                $subject = $sig.SignerCertificate.Subject
                $isMicrosoftSigned = $sig.Status -eq 'Valid' -and $subject -match "Microsoft"
                $isJavaSigned = $sig.Status -eq 'Valid' -and $subject -match "Oracle|Eclipse|Adoptium"
            } catch {
                $isMicrosoftSigned = $false
                $isJavaSigned = $false
            }

            if ($isSystemAttr -or $isMicrosoftSigned -or $isJavaSigned) {
                $sicuri += @{Name=$nome; Reason=""; Path=$dir; Link=""; Jar=$false}
            }
            else {
                $reason = $null
                $zoneId = $null
                if ($fullPath -match '\.jar$') {
                    $reason = Get-CheatReason $fullPath
                    $zoneId = Get-ZoneIdentifier $fullPath
                } else {
                    $zoneId = Get-ZoneIdentifier $fullPath
                }

                if ($reason -or $zoneId) {
                    if ($reason) { $r = $reason } else { $r = "--" }
                    if ($zoneId) { $l = $zoneId } else { $l = "" }

                    $sospetti += @{
                        Name = $nome
                        Reason = $r
                        Path = $dir
                        Jar = ($fullPath -match '\.jar$')
                        Link = $l
                    }
                }
                elseif (-not ($fullPath -match '\.jar$')) {
                    $sospetti += @{Name=$nome; Reason="--"; Path=$dir; Jar=$false; Link=""}
                }
            }
        } else {
            $nonTrovati += @{Name=$fullPath; Reason="--"; Path=""; Jar=$false; Link=""}
        }
    }
}

function Print-Table {
    param($items, $color)
    if ($items.Count -eq 0) { return }

    $sorted = $items | Sort-Object {[bool]($_.Jar)}

    $maxNameLen = ($sorted | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    $maxReasonLen = ($sorted | ForEach-Object { $_.Reason.Length } | Measure-Object -Maximum).Maximum
    $maxPathLen = ($sorted | ForEach-Object { $_.Path.Length } | Measure-Object -Maximum).Maximum
    $maxLinkLen = ($sorted | ForEach-Object { $_.Link.Length } | Measure-Object -Maximum).Maximum

    foreach ($item in $sorted) {
        if ([string]::IsNullOrWhiteSpace($item.Name)) { continue }

        $namePadded = $item.Name.PadRight($maxNameLen + 2)
        $reasonPadded = $item.Reason.PadRight($maxReasonLen + 2)
        $pathPadded = $item.Path.PadRight($maxPathLen + 2)
        $linkPadded = $item.Link.PadRight($maxLinkLen + 2)

        if ($color -eq "Red") {
            Write-Host "> " -NoNewline
            Write-Host $namePadded -ForegroundColor DarkRed -NoNewline
            Write-Host " $reasonPadded $pathPadded $linkPadded" -ForegroundColor $color
        } else {
            Write-Host "> $namePadded $reasonPadded $pathPadded $linkPadded" -ForegroundColor $color
        }
    }
}
Write-Host "SAFE:" -ForegroundColor Green
Print-Table $sicuri Green

Write-Host "`nSUSPECT:" -ForegroundColor Red
Print-Table $sospetti Red

Write-Host "`nNOT FOUND:" -ForegroundColor Yellow
Print-Table $nonTrovati Yellow

Write-Host "`n Developed by Orin144" -ForegroundColor Cyan

