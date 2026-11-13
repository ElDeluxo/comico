# Comico 📚

Una app nativa para leer cómics y manga online en **iOS 9.0+**, compatible con procesadores **32-bit (armv7)** y **64-bit (arm64)**.

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-9.0%2B-blue)
![Arch](https://img.shields.io/badge/arch-armv7%20%7C%20arm64-brightgreen)
![Catalog](https://img.shields.io/badge/comics-Occidentales%20%7C%20Manhwa%20%7C%20Manga%20%7C%20Manhua-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 📖 Descripción

Comico es una aplicación iOS ligera y nativa que te permite explorar, buscar y leer cómics de todo el mundo utilizando la API de [MangaDex](https://mangadex.org).

### 🌍 Catálogo Internacional (No solo japonés):
- **🇺🇸 Cómics Occidentales / Americanos:** Cómics en inglés y español, novelas gráficas, cómics de superhéroes, cómics indie y webcomics globales.
- **🇰🇷 Manhwa / Webtoons:** Series populares coreanas a todo color en formato tira vertical.
- **🇯🇵 Manga:** Toda la variedad de manga japonés clásico y moderno.
- **🇨🇳 Manhua:** Cómics chinos de acción, fantasía y artes marciales.
- **🇪🇸 Cómics en Español:** Capítulos traducidos oficialmente y por la comunidad.

---

## ✨ Características Principales

- 🏷️ **Pestañas por categoría:** Acceso rápido entre *Todos*, *Occidentales*, *Manhwa* y *Manga*.
- 🔍 **Búsqueda global:** Encuentra cualquier cómic por título en cualquier idioma.
- 🔒 **Conexión segura compatible con iOS 9:** Manejador de certificados SSL modernos adaptado al almacén de claves de iOS 9 y compatibilidad RFC 3986.
- 📖 **Lector integrado:** Zoom fluido (pinch-to-zoom), paso de páginas táctil y slider de navegación rápida.
- ⚡ **Rendimiento ultra ligero:** Binario universal ARM (armv7 + arm64) en Objective-C nativo con consumo mínimo de RAM (~20 MB).
- ❤️ **Favoritos locales:** Guarda tus cómics para leerlos en cualquier momento.
- 🚀 **Caché en memoria y disco:** Carga instantánea de portadas y páginas sin re-descargas innecesarias.

---

## 📦 Descargar `.ipa` y `.deb`

Puedes descargar el binario universal compilado directamente desde GitHub:

1. Ve a la pestaña **Actions** en tu repositorio: [GitHub Actions](https://github.com/ElDeluxo/comico/actions).
2. Selecciona la ejecución más reciente del workflow **Build Comico Universal (iOS 9.0)**.
3. En la sección **Artifacts** al pie de la página, descarga el paquete **`Comico-iOS9-Universal`**.
4. Descomprime el archivo descargado para obtener:
   - `Comico_Universal_iOS9.ipa`: para instalar con **Sideloadly** o **AppSync**.
   - `Comico_Universal_iOS9.deb`: para instalar con **Filza** en dispositivos con Jailbreak.

---

## 📲 Instalación en Sideloadly (Windows)

1. Conecta tu iPhone o iPad por USB a tu PC.
2. Abre [Sideloadly](https://sideloadly.io/).
3. Arrastra `Comico_Universal_iOS9.ipa` a Sideloadly.
4. Ingresa tu Apple ID y presiona **Start**.
5. Al terminar, ve en tu dispositivo a: *Ajustes > General > Gestión de dispositivos / Perfiles* y pulsa **Confiar**.
