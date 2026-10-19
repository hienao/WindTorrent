<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="Icono de la aplicación WindTorrent">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>Tus herramientas de descarga. Una sola aplicación Android.</strong></p>
<p align="center">Gestiona Aria2, qBittorrent y Transmission desde tu teléfono.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">Versión gratuita en Google Play</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">Obtener Pro</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">Sitio web</a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.de.md">Deutsch</a><br>
  Español · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>

WindTorrent se conecta a las herramientas de descarga que ya tienes en un NAS, servidor u ordenador. Consulta el progreso, añade tareas y pausa o reanuda descargas desde un solo lugar. Los archivos se descargan y se guardan en el equipo que ejecuta la herramienta conectada.

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Imagen de Google Play con el resumen de conexiones y tareas"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Imagen de Google Play con conexiones a Aria2, qBittorrent y Transmission"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Imagen de Google Play con búsqueda, filtros de estado y progreso de tareas"></a>
</p>

<p align="center"><sub>Imágenes oficiales de Google Play en inglés. Pulsa para ampliarlas; la interfaz puede variar según la versión instalada.</sub></p>

## Menos cambios de aplicación, más control

- **Reúne tus conexiones.** Conecta varias instancias de Aria2, qBittorrent y Transmission.
- **Consulta lo que ocurre.** Revisa el estado, el progreso y las velocidades de descarga y subida de las tareas.
- **Resuelve las tareas habituales.** Añade enlaces o archivos torrent y pausa, reanuda o elimina tareas. Los formatos admitidos dependen de la herramienta conectada.
- **Consulta más detalles cuando los necesites.** Accede a archivos, trackers, pares y opciones de las tareas cuando la herramienta los admita.
- **Adapta la aplicación a tus preferencias.** Elige el tema y el idioma, y transfiere la configuración mediante exportación e importación de JSON local.

## Empieza a usarla

1. Instala [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) o [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro).
2. Activa la interfaz de control remoto de tu herramienta de descarga y comprueba que el teléfono puede acceder a ella.
3. Abre **Downloaders**, pulsa **+**, selecciona el tipo e introduce el host, el puerto y las credenciales. Ajusta HTTPS según la configuración del servidor y guarda la conexión.

| Herramienta | Interfaz remota | Puerto habitual | Guía en inglés |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [Conectar Aria2](docs/aria2.md) |
| qBittorrent | WebUI API | `8080` | [Conectar qBittorrent](docs/qbittorrent.md) |
| Transmission | RPC | `9091` | [Conectar Transmission](docs/transmission.md) |

Usa el puerto realmente accesible, teniendo en cuenta cualquier mapeo de puertos de Docker. En el campo de dirección introduce un nombre de host o una IP; la aplicación añade la ruta de la API automáticamente. Las guías explican los requisitos de los proxies inversos.

## ¿Free o Pro?

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| Funciones principales de gestión | Incluidas | Incluidas |
| Publicidad | Tras siete días de prueba, según tus opciones de privacidad | Sin SDK publicitario |
| Compra | Instalación gratuita | Aplicación de pago independiente |
| Instalación | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

Puedes instalar ambas aplicaciones a la vez y transferir la configuración mediante JSON local. Pro se compra por separado; no es una actualización mediante compra integrada en Free. Ambas versiones usan Firebase Analytics. Consulta la [política de privacidad en inglés y chino](https://hienao-apps.pages.dev/windtorrent/privacy/) para más información.

## Idiomas y ayuda

La interfaz de la aplicación está disponible en inglés, chino simplificado y japonés. Este repositorio ofrece una presentación en ocho idiomas. Las guías detalladas y las preguntas frecuentes están disponibles en [inglés](docs/faq.md) y [chino simplificado](docs/zh-CN/faq.md).

[Informa de un problema](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml) o [propón una función](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml). Los formularios, la [guía de contribución](CONTRIBUTING.md) y las [notas de versión](CHANGELOG.md) están en inglés y chino.

Antes de compartir capturas o registros, elimina contraseñas, secretos RPC, URL privadas e información personal sobre las tareas. Las copias de seguridad contienen credenciales y no deben adjuntarse a incidencias públicas. Para asuntos sensibles, contacta con [soporte por correo](mailto:shiwentao666@gmail.com).

## Acerca de este repositorio

Este es el repositorio público oficial de documentación y comentarios de WindTorrent. La aplicación es de código cerrado; su código fuente no se distribuye aquí. Aria2, qBittorrent y Transmission son proyectos independientes y no están afiliados a WindTorrent.

[Sitio web (inglés/chino)](https://hienao-apps.pages.dev/windtorrent/) · [Privacidad (inglés/chino)](https://hienao-apps.pages.dev/windtorrent/privacy/) · [Soporte](mailto:shiwentao666@gmail.com)
