@echo off
title Servidor Proxy Comico para iPad (iOS 9)
color 0A
cls
echo Iniciando Servidor Proxy Comico...
python "%~dp0comico_server.py"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] No se pudo iniciar con 'python'. Intentando con 'py'...
    py "%~dp0comico_server.py"
)
pause

