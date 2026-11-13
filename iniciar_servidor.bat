@echo off
title Comico & Mangie para iPad (iOS 9)
color 0A
:menu
cls
echo ==============================================================
echo       COMICO ^& MANGIE PARA iPAD (iOS 9) - MENU PRINCIPAL
echo ==============================================================
echo.
echo  [1] Iniciar Servidor Proxy (Para leer online en Mangie)
echo  [2] Descargar Comics / Mangas para leer sin conexion (Offline)
echo  [3] Reconfigurar IP / Reempaquetar Mangie para iPad
echo  [4] Salir
echo.
echo ==============================================================
set /p opt="Selecciona una opcion [1-4]: "

if "%opt%"=="1" goto server
if "%opt%"=="2" goto download
if "%opt%"=="3" goto config
if "%opt%"=="4" exit
goto menu

:server
cls
echo Iniciando Servidor Proxy Comico...
python "%~dp0comico_server.py"
if %ERRORLEVEL% NEQ 0 (
    py "%~dp0comico_server.py"
)
pause
goto menu

:download
cls
python "%~dp0descargar_comic.py"
if %ERRORLEVEL% NEQ 0 (
    py "%~dp0descargar_comic.py"
)
pause
goto menu

:config
cls
call "%~dp0cambiar_ip.bat"
goto menu
