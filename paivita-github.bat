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

REM ---------- 1. Etsi uusin index.html automaattisesti ----------
REM Voit myos raahata html-tiedoston taman bat-tiedoston paalle.
set "NEW="
set "NEWTIME=0"

if not "%~1"=="" (
    if exist "%~1" (
        set "NEW=%~1"
        goto :kopioi
    )
)

call :etsi "%USERPROFILE%\Downloads"
call :etsi "%USERPROFILE%\OneDrive\Downloads"
call :etsi "%USERPROFILE%\OneDrive\Lataukset"
call :etsi "%USERPROFILE%\Desktop"
call :etsi "%USERPROFILE%\OneDrive\Desktop"
call :etsi "%USERPROFILE%\OneDrive\Työpöytä"
call :etsi "%USERPROFILE%\Documents"
goto :kopioi

:etsi
if not exist "%~1" exit /b
for /f "delims=" %%F in ('dir /b /a-d /o-d "%~1\index*.html" "%~1\limone*.html" 2^>nul') do (
    for /f %%T in ('powershell -nop -c "(Get-Item -LiteralPath '%~1\%%F').LastWriteTime.ToString(\"yyyyMMddHHmmss\")" 2^>nul') do (
        if %%T GTR !NEWTIME! (
            set "NEWTIME=%%T"
            set "NEW=%~1\%%F"
        )
    )
)
exit /b

:kopioi
if defined NEW (
    echo Uusin loydetty tiedosto:
    echo   !NEW!
    fc /b "!NEW!" "index.html" >nul 2>nul
    if errorlevel 1 (
        copy /y "!NEW!" "index.html" >nul
        echo Kopioitu kansioon nimella index.html
    ) else (
        echo Tiedosto on jo sama kuin kansiossa oleva index.html
    )
) else (
    echo Uutta tiedostoa ei loytynyt - kaytetaan kansiossa olevaa index.html
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
if errorlevel 1 git remote add origin https://github.com/mattsmatias/espoolimone.git

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
