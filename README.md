# Comico 📚

Una app nativa para leer cómics y manga online en **iOS 9.0+**, compatible tanto con dispositivos **32-bit (armv7)** como **64-bit (arm64)**.

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-9.0%2B-blue)
![Arch](https://img.shields.io/badge/arch-armv7%20%7C%20arm64-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)

## 📖 Descripción

Comico es una aplicación iOS ligera y nativa que te permite explorar, buscar y leer miles de cómics y mangas de forma gratuita utilizando la API pública de [MangaDex](https://mangadex.org).

Está diseñada específicamente para funcionar con fluidez en dispositivos clásicos con **iOS 9** (como iPhone 4s, iPhone 5, iPhone 5c, iPad 2, iPad 3, iPad 4, iPad mini 1, iPod touch 5, y también iPhone 5s, iPhone 6, etc.), sin dependencias pesadas ni dylibs externos.

## ✨ Características Principales

- 🔍 **Explorar y buscar** mangas y cómics en tiempo real
- 📖 **Lector integrado** con zoom fluido (pinch-to-zoom), paso de páginas por gestos y slider
- ⚡ **Rendimiento ultra ligero**: compilado en código nativo para procesadores ARM de 32 y 64 bits con consumo mínimo de RAM (~20 MB)
- ❤️ **Favoritos**: guarda tus cómics favoritos localmente para acceder rápidamente
- 🚀 **Cache inteligente** en memoria y disco para carga instantánea
- 🌐 **Capítulos disponibles en español e inglés**

---

## 📦 Descargar `.ipa` y `.deb` (Compilación Automática en GitHub)

Puedes obtener el binario compilado listo para instalar sin necesidad de una Mac:

1. Ve a la pestaña **Actions** en tu repositorio: [GitHub Actions](https://github.com/ElDeluxo/comico/actions).
2. Selecciona la ejecución más reciente del workflow **Build Comico Universal (iOS 9.0)**.
3. En la sección **Artifacts** al pie de la página, descarga el paquete **`Comico-iOS9-Universal`**.
4. Descomprime el archivo descargado para obtener:
   - `Comico_Universal_iOS9.ipa`: para sideloading vía Sideloadly o AppSync.
   - `Comico_Universal_iOS9.deb`: para instalar con Filza, Zebra o Cydia.

---

## 📲 Cómo Instalar en tu Dispositivo iOS 9

### 1. Con Jailbreak (Recomendado para iOS 9)
- **Instalación directa con Filza (.deb):**
  1. Pasa `Comico_Universal_iOS9.deb` a tu dispositivo (por AirDrop, Telegram, Google Drive o Safari).
  2. Ábrelo en **Filza File Manager** y pulsa **Instalar**.
  3. Al terminar, el icono aparecerá de inmediato en tu pantalla de inicio.
- **Instalación con AppSync (.ipa):**
  1. Instala el tweak **AppSync Unified** desde Cydia (repo: `https://cydia.akemi.ai`).
  2. Instala `Comico_Universal_iOS9.ipa` directamente desde Filza o usando Sideloadly sin preocuparte por límites de certificados de 7 días.

### 2. Sin Jailbreak (Sideloadly en Windows)
1. Conecta tu iPhone o iPad por USB a tu PC con Windows.
2. Abre [Sideloadly](https://sideloadly.io/).
3. Arrastra `Comico_Universal_iOS9.ipa` a la ventana de Sideloadly.
4. Ingresa tu Apple ID y presiona **Start**.
5. Al terminar, ve en tu dispositivo a: *Ajustes > General > Gestión de dispositivos / Perfiles* y pulsa **Confiar**.

---

## 🛠️ Tecnologías y Arquitectura

- **Compilador:** Theos Toolchain (LLVM/Clang) con SDK `iPhoneOS9.3.sdk`.
- **Arquitecturas:** Universal Mach-O Fat Binary (`armv7` + `arm64`).
- **Frameworks:** UIKit, Foundation, CoreGraphics, QuartzCore (sin dylibs externos).
- **API:** MangaDex REST API v5.
