# Limone Espoo - paivita sivusto GitHubiin
# Kayttö: klikkaa tiedostoa hiiren oikealla -> "Suorita PowerShellillä"
# Skripti hakee uusimman index.html-tiedoston Lataukset-kansiosta,
# kopioi sen tahan kansioon ja pushaa muutoksen GitHubiin.

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

Write-Host ""
Write-Host "=== Limone Espoo - paivitys ===" -ForegroundColor Cyan
Write-Host "Kansio: $repo"
Write-Host ""

# 1. Etsi uusin index.html Lataukset-kansiosta
$downloads = Join-Path $env:USERPROFILE "Downloads"
$uusin = Get-ChildItem -Path $downloads -Filter "index*.html" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $uusin) {
    Write-Host "Lataukset-kansiosta ei loytynyt index.html-tiedostoa." -ForegroundColor Yellow
    Write-Host "Lataa tiedosto ensin, tai kopioi se itse tahan kansioon nimella index.html."
    Read-Host "Paina Enter sulkeaksesi"
    exit
}

Write-Host "Loytyi: $($uusin.Name)  ($($uusin.LastWriteTime))" -ForegroundColor Green
Copy-Item $uusin.FullName (Join-Path $repo "index.html") -Force
Write-Host "Kopioitu -> index.html" -ForegroundColor Green
Write-Host ""

# 2. Alusta git-repo jos sita ei viela ole
if (-not (Test-Path (Join-Path $repo ".git"))) {
    Write-Host "Alustetaan git-repo..." -ForegroundColor Cyan
    git init | Out-Null
    git branch -M main
    git remote add origin "https://github.com/mattsmatias/espoolimone.git"
}

# 3. Varmista etta remote osoittaa oikeaan repoon
$remote = git remote get-url origin 2>$null
if ([string]::IsNullOrWhiteSpace($remote)) {
    git remote add origin "https://github.com/mattsmatias/espoolimone.git"
} elseif ($remote -notmatch "espoolimone") {
    git remote set-url origin "https://github.com/mattsmatias/espoolimone.git"
}

# 4. Commit ja push
$muutokset = git status --porcelain
if ([string]::IsNullOrWhiteSpace($muutokset)) {
    Write-Host "Ei muutoksia - tiedosto on jo ajan tasalla." -ForegroundColor Yellow
    Read-Host "Paina Enter sulkeaksesi"
    exit
}

git add .
$viesti = "Paivitys " + (Get-Date -Format "d.M.yyyy HH:mm")
git commit -m $viesti | Out-Null
Write-Host "Commit: $viesti" -ForegroundColor Green

Write-Host "Lahetetaan GitHubiin..." -ForegroundColor Cyan
try {
    git push -u origin main
} catch {
    Write-Host "Push ei onnistunut. Kokeillaan hakea etamuutokset ensin..." -ForegroundColor Yellow
    git pull --rebase origin main
    git push -u origin main
}

Write-Host ""
Write-Host "Valmis. Sivusto paivittyy noin minuutissa." -ForegroundColor Green
Write-Host "Selaimessa kannattaa painaa Ctrl+F5, jos vanha versio jaa nakyviin."
Read-Host "Paina Enter sulkeaksesi"
