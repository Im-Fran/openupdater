<div align="center">

# 🔄 OpenUpdater

**Actualizaciones automáticas para apps nativas de macOS, usando GitHub Releases.**

[![CI](https://img.shields.io/github/actions/workflow/status/Im-Fran/openupdater/ci.yml?branch=dev&label=CI)](https://github.com/Im-Fran/openupdater/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Im-Fran/openupdater)](LICENSE)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-F05138)](https://swift.org/package-manager/)
[![Last commit](https://img.shields.io/github/last-commit/Im-Fran/openupdater)](https://github.com/Im-Fran/openupdater/commits/dev)

[English](README.md) · **Español**

</div>

---

## 📖 Descripción

OpenUpdater es un paquete de Swift que mantiene tu app de macOS al día usando los releases que ya publicas en GitHub. Sin servidor de appcast ni feed XML: creas un release, subes un `.zip` firmado y tus usuarios reciben la actualización.

Está escrito en Swift con una interfaz en SwiftUI. Busca nuevas versiones con la frecuencia que el usuario elija (diaria, semanal o mensual) y muestra las notas del release. Luego el usuario puede instalar al momento o en el próximo inicio.

Cada actualización se verifica dos veces antes de tocar el disco: una **firma Ed25519** del zip y una **verificación de la firma de código**. Esta última exige que la app nueva tenga el mismo bundle ID y Team ID que la que está en ejecución. La interfaz viene en **inglés** y **español (Latinoamérica)**.

---

## ✨ Características

- **GitHub Releases como fuente:** lee los releases del repo con la API de GitHub y elige la versión más nueva que no sea borrador.
- **Instalar ahora o en el próximo inicio:** "Instalar y reiniciar" reemplaza la app y la vuelve a abrir. "Instalar en el próximo inicio" deja la actualización preparada y la aplica la próxima vez que se abra la app.
- **Búsqueda programada:** diaria, semanal o mensual, además de "Buscar ahora".
- **Actualizaciones firmadas:** firmas Ed25519 (CryptoKit) y validación del requisito designado (framework Security).
- **Canal de pre-releases:** los usuarios pueden optar por recibir versiones beta.
- **UI en SwiftUI lista para usar:** una ventana de actualización y un `UpdaterSettingsView` para tu escena `Settings`.
- **Localizado:** inglés y español (es-419) mediante un String Catalog.
- **Sin dependencias:** solo frameworks de Apple.
- **CLI incluido:** `openupdater-cli` genera claves y firma los zips de cada release.

---

## 🛠 Stack tecnológico

| Capa | Tecnología |
|-------|-----------|
| Lenguaje | Swift 6 (Swift Package Manager) |
| UI | SwiftUI + AppKit (`NSWindow` / `NSHostingController`) |
| Criptografía | CryptoKit (Curve25519 / Ed25519), Security (firma de código) |
| Localización | String Catalog (`.xcstrings`): `en`, `es-419` |
| Tests | Swift Testing |

---

## 📋 Requisitos

- **macOS 14** o superior (deployment target de la app)
- **Xcode 16** o superior (herramientas de Swift 6)
- Una app **sin sandbox**, firmada con **Developer ID**
- Un repositorio **público** en GitHub para los releases

---

## 🚀 Primeros pasos

### 1. Agrega el paquete

En Xcode: **File › Add Package Dependencies…** → `https://github.com/Im-Fran/openupdater`, producto **OpenUpdater**.

O en `Package.swift`:

```swift
.package(url: "https://github.com/Im-Fran/openupdater", branch: "dev"),
// dependencias del target:
.product(name: "OpenUpdater", package: "openupdater"),
```

### 2. Genera las claves de firma

```bash
git clone https://github.com/Im-Fran/openupdater.git
cd openupdater
swift run openupdater-cli generate-keys
```

La **clave pública** va en tu app. Guarda la **clave privada** en secreto, por ejemplo en tu gestor de contraseñas y como secreto del CI.

### 3. Intégralo en tu app

```swift
import OpenUpdater
import SwiftUI

@main
struct MyApp: App {
    @State private var updater = Updater(repo: "owner/MyApp", publicKey: "<clave pública en base64>")

    init() { updater.start() }

    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandGroup(after: .appInfo) {
                    Button("Buscar actualizaciones…") { updater.checkNow() }
                }
            }
        Settings { UpdaterSettingsView(updater: updater) }
    }
}
```

`start()` hace dos cosas. Primero instala una actualización que haya quedado preparada para el "próximo inicio" y reinicia la app. Si no hay ninguna, inicia la búsqueda automática programada.

> 🤖 ¿Usas un agente de IA para programar? Pásale [AGENT_SETUP.md](AGENT_SETUP.md). Es una guía de configuración paso a paso escrita para agentes (en inglés).

---

## 📦 Publicar un release

1. Sube `CFBundleShortVersionString` (p. ej. `1.2.0`). Luego archiva la app, fírmala con tu Developer ID y notarízala.
2. Comprime y firma la app:

   ```bash
   ditto -c -k --sequesterRsrc --keepParent MyApp.app MyApp.zip
   swift run openupdater-cli sign MyApp.zip private.key
   # o: OPENUPDATER_PRIVATE_KEY=<clave> swift run openupdater-cli sign MyApp.zip
   swift run openupdater-cli verify MyApp.zip "<clave pública>"   # comprobar antes de publicar
   ```

3. Publica ambos archivos con un tag que coincida con la versión (el prefijo `v` es opcional):

   ```bash
   gh release create v1.2.0 MyApp.zip MyApp.zip.sig --notes "Novedades…"
   ```

   Agrega `--prerelease` para que solo lo reciban los usuarios que activaron las versiones preliminares.

---

## ⚙️ Configuración

Estas preferencias del usuario se guardan en `UserDefaults` y son propiedades de `Updater`. `UpdaterSettingsView` se enlaza a ellas.

| Propiedad | Por defecto | Descripción |
|--------|---------|-------------|
| `automaticChecks` | `true` | Buscar actualizaciones en segundo plano |
| `frequency` | `.daily` | `.daily`, `.weekly` o `.monthly` |
| `includePrereleases` | `false` | Ofrecer también pre-releases de GitHub |

| Variable de entorno | Usada por | Descripción |
|----------|-------------|---------|
| `OPENUPDATER_PRIVATE_KEY` | `openupdater-cli sign` | Clave privada en base64; se usa si no pasas un archivo de clave |

---

## 🧪 Desarrollo

```bash
swift build   # compila la librería y el CLI
swift test    # ejecuta los tests
```

```
Sources/OpenUpdater/       Updater, API de GitHub, instalador, vistas SwiftUI, Localizable.xcstrings
Sources/openupdater-cli/   generate-keys / sign
Tests/OpenUpdaterTests/    comparación de versiones, programación, firmas, selección de release
```

---

## ⚠️ Limitaciones

- La app en ejecución necesita una firma estable (Developer ID). Las builds firmadas ad-hoc no pueden validar actualizaciones.
- El usuario debe poder escribir en la carpeta de la app, ya que no se pide contraseña de administrador. Las apps que se ejecutan desde una ubicación trasladada (p. ej. Descargas) deben moverse primero a Aplicaciones.
- Solo repositorios públicos. La API de GitHub sin autenticación permite 60 solicitudes por hora por IP.
- Solo se admiten assets `.zip`.

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Revisa [CONTRIBUTING.md](.github/CONTRIBUTING.md) (en inglés) para ver las pautas y la estructura del proyecto.

Flujo rápido:
1. Haz un fork del repo
2. Crea una rama: `git checkout -b feat/tu-feature`
3. Haz commit usando [Conventional Commits](https://www.conventionalcommits.org): `git commit -m "feat: add your feature"`
4. Asegúrate de que `swift test` pase, luego haz push y abre un PR

Por favor, respeta el [Código de Conducta](.github/CODE_OF_CONDUCT.md).

---

## 🔒 Seguridad

¿Encontraste una vulnerabilidad? Lee la [Política de Seguridad](.github/SECURITY.md) y repórtala de forma privada. No abras un issue público.

---

## 📄 Licencia

Este proyecto está licenciado bajo la **GNU General Public License v3.0**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<div align="center">
Hecho con ☕ por <a href="https://franciscosolis.cl">Fran</a>
</div>
