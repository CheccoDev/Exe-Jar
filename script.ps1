Write-Host "Paste the resuòts copied on WinPrefetchView"
$lines = @()
while ($true) {
    $line = Read-Host
    if ([string]::IsNullOrWhiteSpace($line)) { break }
    $lines += $line
}
Clear-Host

$recognized = @()
$unrecognized = @()
$notFound = @()

foreach ($line in $lines) {
    if ($line -match '([A-Z]:\\.+?)\\VOLUME') {
        $fullPath = $matches[1]

        if (Test-Path $fullPath) {
            # Verifica attributo "System"
            $isSystemAttr = (Get-Item $fullPath).Attributes -band [System.IO.FileAttributes]::System

            # Verifica firma digitale
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
                if ($isJavaSigned) {
                    $recognized += "$fullPath -> Java file ($subject)"
                } elseif ($isMicrosoftSigned) {
                    $recognized += "$fullPath -> Microsoft file ($subject)"
                } else {
                    $recognized += "$fullPath -> File system"
                }
            } else {
                $unrecognized += "$fullPath -> Unknown as file system"
            }
        } else {
            $notFound += "$fullPath -> File not found"
        }
    }
}

foreach ($r in $recognized) {
    Write-Host $r -ForegroundColor Green
}
Write-Host ""
foreach ($u in $unrecognized) {
    Write-Host $u -ForegroundColor Red
}
foreach ($n in $notFound) {
    Write-Host $n -ForegroundColor Yellow
}
Write-Host " Developed by Orin144" -ForegroundColor Cyan




