@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo.
echo ==========================================
echo    LIMONE BISTRO ESPOO - PAIVITYS
echo ==========================================
echo Kansio: %CD%
echo.

REM ---------- 1. Etsi uusin ladattu index.html ----------
set "NEW="
set "DL1=%USERPROFILE%\Downloads"
set "DL2=%USERPROFILE%\OneDrive\Downloads"

for /f "delims=" %%F in ('dir /b /o-d "%DL1%\index*.html" 2^>nul') do (
    set "NEW=%DL1%\%%F"
    goto :loytyi
)
for /f "delims=" %%F in ('dir /b /o-d "%DL2%\index*.html" 2^>nul') do (
    set "NEW=%DL2%\%%F"
    goto :loytyi
)

:loytyi
if defined NEW (
    echo Loytyi uusi tiedosto:
    echo   !NEW!
    copy /y "!NEW!" "index.html" >nul
    echo Kopioitu tahan kansioon nimella index.html
) else (
    echo Latauksista ei loytynyt index.html-tiedostoa.
    echo Kaytetaan kansiossa jo olevaa index.html-tiedostoa.
)
echo.

if not exist "index.html" (
    echo VIRHE: index.html puuttuu. Lataa tiedosto ensin.
    echo.
    pause
    exit /b
)

REM ---------- 2. Varmista git ----------
where git >nul 2>nul
if errorlevel 1 (
    echo VIRHE: Gitia ei loydy koneelta.
    echo Asenna Git osoitteesta https://git-scm.com/download/win
    echo.
    pause
    exit /b
)

if not exist ".git" (
    echo Alustetaan git-repo...
    git init >nul
    git branch -M main
    git remote add origin https://github.com/mattsmatias/espoolimone.git
)

git remote get-url origin >nul 2>nul
if errorlevel 1 (
    git remote add origin https://github.com/mattsmatias/espoolimone.git
)

REM ---------- 3. Commit ja push ----------
git add -A

git diff --cached --quiet
if not errorlevel 1 (
    echo Ei muutoksia - kaikki on jo ajan tasalla.
    echo.
    pause
    exit /b
)

for /f "tokens=1-3 delims=." %%a in ("%date%") do set "PVM=%%a.%%b.%%c"
set "KLO=%time:~0,5%"
git commit -m "Paivitys %PVM% %KLO%" >nul
echo Commit tehty: Paivitys %PVM% %KLO%

echo Lahetetaan GitHubiin...
git push -u origin main
if errorlevel 1 (
    echo.
    echo Push ei onnistunut. Haetaan etamuutokset ja yritetaan uudelleen...
    git pull --rebase origin main
    git push -u origin main
)

echo.
echo ==========================================
echo  VALMIS. Sivusto paivittyy noin minuutissa.
echo  Paina selaimessa Ctrl+F5 jos vanha nakyy.
echo ==========================================
echo.
pause
