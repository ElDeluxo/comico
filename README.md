# Comico 📚

Una app iOS nativa para leer cómics y manga online, desarrollada completamente en Swift con UIKit.

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![iOS](https://img.shields.io/badge/iOS-9.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 📖 Descripción

Comico es una aplicación iOS que te permite explorar, buscar y leer miles de cómics y mangas de forma gratuita utilizando la API pública de [MangaDex](https://mangadex.org). La app está diseñada con una interfaz limpia e intuitiva, optimizada tanto para iPhone como iPad.

## ✨ Características Principales

- 🔍 **Explorar y buscar** miles de cómics y manga
- 📖 **Lector integrado** con dos modos de lectura:
  - Horizontal con paginación (estilo occidental)
  - Scroll vertical continuo (estilo manga)
- 🔎 **Zoom** con pinch-to-zoom y doble tap
- ❤️ **Favoritos** para guardar tus cómics preferidos
- 📱 **Diseño responsive** adaptado a portrait y landscape
- 🚀 **Carga rápida** con sistema de cache de imágenes en memoria y disco
- 📄 **Paginación infinita** para explorar sin límites
- 🌐 **Multiidioma** - Capítulos en inglés y español

## 📸 Capturas de Pantalla

| Home | Detalle | Lector |
|------|---------|--------|
| *Screenshot* | *Screenshot* | *Screenshot* |

> Las capturas de pantalla se agregarán próximamente.

## 📋 Requisitos

- iOS 9.0 o superior
- Xcode 14 o superior
- Swift 5
- Conexión a internet

## 🚀 Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/tu-usuario/comico.git
   ```

2. Abre el proyecto en Xcode:
   ```bash
   cd comico
   open Comico/Comico.xcodeproj
   ```

3. Selecciona un simulador o dispositivo.

4. Compila y ejecuta (⌘R).

> **Nota:** No se requieren dependencias externas ni CocoaPods/SPM. El proyecto funciona directamente al abrirlo.

## 📦 Generar `.ipa` y `.deb` sin Mac (GitHub Actions)

Si estás en **Windows o Linux** y no tienes Mac, puedes compilar y obtener el `.ipa` y el `.deb` en la nube de forma 100% gratuita usando GitHub Actions:

1. Crea un repositorio nuevo en tu cuenta de [GitHub](https://github.com/new).
2. Sube este proyecto con tu terminal:
   ```bash
   git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
   git branch -M main
   git push -u origin main
   ```
3. En GitHub, ve a la pestaña **Actions** → Verás el workflow **Build iOS IPA and DEB** ejecutándose automáticamente en una máquina virtual Mac gratuita.
4. Al terminar (aprox. 2 minutos), ve al resumen del workflow y descarga el artefacto **`Comico-iOS-Packages.zip`**, que contiene:
   - `Comico.ipa` (para instalar con Sideloadly, AltStore o AppSync)
   - `Comico.deb` (para instalar en iOS 9 jailbroken con Filza, Cydia o dpkg)

### 📲 Instalación en iOS 9

- **Con Jailbreak (Recomendado para iOS 9):**
  - **Método .deb:** Copia `Comico.deb` al dispositivo y ábrelo con **Filza File Manager** → presiona **Instalar**. O por SSH: `dpkg -i Comico.deb && uicache`.
  - **Método .ipa (con AppSync Unified):** Instala el tweak *AppSync Unified* desde Cydia/Karen's Repo, y luego instala `Comico.ipa` con Filza o Sideloadly sin preocuparte por certificados de Apple.
- **Sin Jailbreak (Sideloading):**
  - Conecta tu dispositivo a Windows por USB y abre [Sideloadly](https://sideloadly.io/). Arrastra `Comico.ipa`, pon tu Apple ID y presiona Start.

## 🏗️ Arquitectura

El proyecto sigue el patrón **MVC (Model-View-Controller)**:

```
┌─────────────────────────────────────────┐
│              Controllers                │
│  (HomeVC, DetailVC, ReaderVC, etc.)     │
├──────────┬──────────────────────────────┤
│  Views   │         Models              │
│ (Cells)  │  (Comic, Chapter, Page)     │
├──────────┴──────────────────────────────┤
│            Networking                   │
│     (APIService, ImageCache)            │
└─────────────────────────────────────────┘
```

## 📂 Estructura de Carpetas

```
Comico/
├── Comico.xcodeproj/
├── AppDelegate.swift
├── Info.plist
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   └── AccentColor.colorset/
├── Base.lproj/
│   └── LaunchScreen.storyboard
├── Models/
│   ├── Comic.swift              # Modelos de datos (Comic, Chapter, Page)
│   └── APIResponse.swift        # Wrappers de respuesta de MangaDex
├── Networking/
│   ├── APIService.swift         # Servicio de API (singleton)
│   └── ImageCache.swift         # Cache de imágenes (memoria + disco)
├── Extensions/
│   └── String+HTML.swift        # Utilidad para limpiar HTML
├── Views/
│   ├── ComicCell.swift          # Celda de cómic (UICollectionView)
│   └── ChapterCell.swift        # Celda de capítulo (UITableView)
├── Controllers/
│   ├── MainTabBarController.swift       # Tab bar principal
│   ├── HomeViewController.swift         # Pantalla de inicio con grid
│   ├── ComicDetailViewController.swift  # Detalle del cómic
│   ├── ReaderViewController.swift       # Lector de páginas
│   └── FavoritesViewController.swift    # Favoritos guardados
└── Resources/
    └── Colors.swift             # Constantes de colores y estilos
```

## 🌐 API

La app utiliza la API pública de **MangaDex** (v5):
- Base URL: `https://api.mangadex.org`
- No requiere API key ni autenticación
- [Documentación oficial](https://api.mangadex.org/docs/)

### Endpoints utilizados:
| Endpoint | Descripción |
|----------|-------------|
| `GET /manga` | Listar y buscar manga |
| `GET /manga/{id}/feed` | Obtener capítulos de un manga |
| `GET /at-home/server/{chapter}` | Obtener URLs de páginas |
| `GET /covers` | Obtener imágenes de portada |

## 🛠️ Tecnologías

- **Swift 5** - Lenguaje de programación
- **UIKit** - Framework de interfaz
- **URLSession** - Networking nativo
- **NSCache** - Cache en memoria
- **FileManager** - Cache en disco
- **UserDefaults** - Persistencia de favoritos
- **Auto Layout** - Layout programático

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

```
MIT License

Copyright (c) 2024 Comico

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

Hecho con ❤️ y Swift
