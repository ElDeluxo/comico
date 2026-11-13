@echo off
title Configurar IP para Mangie iPad Edition
color 0B
cls
echo ==============================================================
echo    CONFIGURADOR DE IP PARA MANGIE (iPad iOS 9)
echo ==============================================================
echo.
python patch_mangie.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] No se pudo ejecutar patch_mangie.py con 'python'. Intentando con 'py'...
    py patch_mangie.py
)
echo.
echo Reempaquetando IPA y DEB para iPad...
python package_mangie.py
if %ERRORLEVEL% NEQ 0 (
    py package_mangie.py
)
echo.
echo ==============================================================
echo  Listo! Los archivos Mangie_iPad_iOS9.ipa y .deb estan actualizados.
echo ==============================================================
echo.
pause

