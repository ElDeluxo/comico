@echo off
title Descargador de Comics y Mangas para Leer Offline
color 0E
cls
echo ==============================================================
echo    DESCARGADOR DE COMICS Y MANGAS PARA LEER SIN CONEXION
echo ==============================================================
echo.
python "%~dp0descargar_comic.py" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Intentando con 'py'...
    py "%~dp0descargar_comic.py" %*
)
echo.
echo Presiona cualquier tecla para salir...
pause > nul
