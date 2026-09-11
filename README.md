<p align="center">
  <img src="https://user-images.githubusercontent.com/14097782/164502693-14cea4fe-3734-4867-9fc5-cd1577f9213c.png" />
</p>

# Gas4Oil

App para iOS y macOS que muestra el precio del carburante en las estaciones de servicio de España, con datos oficiales del Ministerio para la Transición Ecológica.

Encuentra las gasolineras más cercanas, ordénalas por precio, filtra por marca o por municipio, guarda las que te interesen y traza la ruta en Apple Maps con un toque. Si guardas tu vehículo, la app calcula lo que cuesta llenar el depósito en cada estación.

<p align="center">
  <img src="https://user-images.githubusercontent.com/14097782/164501962-bc7f0816-1d40-45dd-9d7e-d3f2924a836d.png" />
</p>

## Qué hace

- **Estaciones cercanas** ordenadas por proximidad, precio ascendente o descendente.
- **Filtros** por combustible (gasolina 95, gasolina 98 y diésel) y por marca, con su logo.
- **Búsqueda por municipio**, con sugerencias.
- **Favoritos**, que mantienen su precio actualizado.
- **Cómo llegar**: abre la ruta en Apple Maps con el destino ya nombrado.
- **Mi vehículo**: guarda el combustible y la capacidad del depósito y la app te dice entre cuánto y cuánto cuesta llenarlo en las estaciones que tienes cerca.
- **App de macOS** con vista dividida: lista a la izquierda, detalle y mapa a la derecha.

## Datos

Los precios vienen del servicio REST público del Ministerio:

```
https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/
```

Devuelve unas 11.500 estaciones en una sola respuesta de ~12 MB, actualizada varias veces al día. No requiere clave.

> **Nota sobre TLS.** Ese servidor aborta el handshake si el cliente ofrece TLS 1.3 y solo negocia suites sin ECDHE. La app fuerza `tlsMaximumSupportedProtocolVersion = .TLSv12` en su `URLSession` y declara una excepción de ATS para ese dominio. Sin ambas cosas la petición falla con `NSURLErrorSecureConnectionFailed`.

## Requisitos

| | |
|---|---|
| Xcode | 26 o superior |
| iOS | 18.0 |
| macOS | 15.0 |
| Swift | 5 (herramientas de Swift 6) |

## Cómo compilar

```bash
git clone https://github.com/aitorsola/gas4oil-ios.git
cd gas4oil-ios/Gas4Oil
open Gas4Oil.xcodeproj
```

Las dependencias se resuelven solas con Swift Package Manager. Desde línea de comandos:

```bash
xcodebuild -scheme "Gas4Oil (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16e' build
xcodebuild -scheme "Gas4Oil (macOS)" -destination 'platform=macOS' build
```

## Arquitectura

SwiftUI con MVVM. Los view models son `@Observable` y `@MainActor`; la capa de red usa `async/await` con *typed throws*.

```
Gas4Oil/
├── Managers/
│   ├── Network/            # URLSession, modelos de la API y su mapeo a dominio
│   ├── LocationManager     # CoreLocation y geocodificación inversa
│   └── BackgroundTaskManager
├── Shared/
│   ├── Domain Models/      # Station, VehicleStored y sus extensiones
│   ├── Scenes/             # StationsList, Map, Vehicle, FavoriteStations
│   └── Views/              # Celdas y componentes reutilizables
├── Helpers/                # Persistencia en UserDefaults
├── Extensions/
└── Resources/              # Assets, animaciones Lottie y localizaciones
```

## Idiomas

Español, inglés, catalán, gallego y euskera. Los datos del Ministerio llegan siempre en español.

## Dependencias

| Paquete | Uso |
|---|---|
| [Lottie](https://github.com/airbnb/lottie-ios) | Animación de la pantalla de permisos |
| [NotificationBanner](https://github.com/Daltron/NotificationBanner) | Avisos de error de red |
| [SwiftUI-Shimmer](https://github.com/markiv/SwiftUI-Shimmer) | Esqueleto de carga de la lista |

Todas fijadas a versión en `Package.resolved`.

## Licencia

MIT. Los logos de las marcas pertenecen a sus respectivos titulares y se usan únicamente para identificar cada estación.
