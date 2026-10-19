<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="App-Symbol von WindTorrent">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>Deine Downloader. Eine Android-App.</strong></p>
<p align="center">Verwalte Aria2, qBittorrent und Transmission von deinem Smartphone aus.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">Free bei Google Play</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">Pro herunterladen</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">Website</a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · Deutsch<br>
  <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>

WindTorrent verbindet sich mit Downloadern, die bereits auf deinem NAS, Server oder Computer laufen. Prüfe den Fortschritt, füge Aufgaben hinzu und pausiere oder starte Downloads an einem Ort. Die Dateien werden vom verbundenen Downloader heruntergeladen und auf dessen Gerät gespeichert.

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Google-Play-Vorschaubild mit Downloader- und Aufgabenübersicht"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Google-Play-Vorschaubild mit Verbindungen zu Aria2, qBittorrent und Transmission"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Google-Play-Vorschaubild mit Aufgabensuche, Statusfiltern und Fortschritt"></a>
</p>

<p align="center"><sub>Offizielle englische Google-Play-Vorschaubilder. Zum Vergrößern anklicken; die installierte Version kann anders aussehen.</sub></p>

## Weniger wechseln, einfacher verwalten

- **Alle Downloader zusammen.** Verbinde mehrere Instanzen von Aria2, qBittorrent und Transmission.
- **Behalte den Überblick.** Sieh Status, Fortschritt sowie Download- und Uploadgeschwindigkeit deiner Aufgaben.
- **Erledige alltägliche Aufgaben.** Füge Links oder Torrent-Dateien hinzu und pausiere, setze fort oder entferne Aufgaben. Die unterstützten Eingaben hängen vom Downloader ab.
- **Schau bei Bedarf genauer hin.** Prüfe Aufgabendetails und, je nach Downloader, Dateien, Tracker, Peers und Optionen.
- **Passe die App an.** Wähle Design und Sprache und übertrage Downloader-Einstellungen per lokalem JSON-Export und -Import.

## Verbindung herstellen

1. Installiere [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) oder [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro).
2. Aktiviere die Fernzugriffsschnittstelle deines Downloaders und prüfe, ob dein Smartphone sie erreichen kann.
3. Öffne **Downloaders**, tippe auf **+**, wähle den Typ und gib Host, Port und Zugangsdaten ein. Stelle HTTPS passend zum Server ein und speichere.

| Downloader | Fernzugriff | Üblicher Port | Anleitung auf Englisch |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [Aria2 verbinden](docs/aria2.md) |
| qBittorrent | WebUI API | `8080` | [qBittorrent verbinden](docs/qbittorrent.md) |
| Transmission | RPC | `9091` | [Transmission verbinden](docs/transmission.md) |

Verwende den tatsächlich erreichbaren Port, einschließlich einer möglichen Docker-Portzuordnung. Trage nur einen Hostnamen oder eine IP-Adresse in das Adressfeld ein; die App ergänzt den API-Pfad automatisch. Hinweise zu Reverse-Proxys findest du in den Anleitungen.

## Free oder Pro?

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| Grundlegende Downloadverwaltung | Enthalten | Enthalten |
| Werbung | Nach sieben Tagen Einführungsphase, abhängig von den Datenschutzeinstellungen | Ohne Werbe-SDK |
| Kauf | Kostenlos installierbar | Separate kostenpflichtige App |
| Installation | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

Beide Apps können gleichzeitig installiert sein. Einstellungen lassen sich per lokaler JSON-Datei übertragen. Pro wird separat gekauft und ist kein In-App-Upgrade von Free. Beide Versionen verwenden Firebase Analytics. Einzelheiten stehen in der [Datenschutzerklärung auf Englisch und Chinesisch](https://hienao-apps.pages.dev/windtorrent/privacy/).

## Sprachen und Hilfe

Die App-Oberfläche ist auf Englisch, vereinfachtem Chinesisch und Japanisch verfügbar. Die Vorstellung in diesem Repository gibt es in acht Sprachen. Ausführliche Anleitungen und FAQ sind auf [Englisch](docs/faq.md) und [vereinfachtem Chinesisch](docs/zh-CN/faq.md) verfügbar.

[Melde ein Problem](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml) oder [schlage eine Funktion vor](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml). Formulare, [Hinweise zur Mitarbeit](CONTRIBUTING.md) und [Versionshinweise](CHANGELOG.md) sind auf Englisch und Chinesisch verfügbar.

Entferne vor dem Teilen von Screenshots oder Protokollen Passwörter, RPC-Schlüssel, private URLs und persönliche Aufgabendaten. Backups enthalten Zugangsdaten und gehören nicht in öffentliche Issues. Sensible Anliegen kannst du [per E-Mail](mailto:shiwentao666@gmail.com) melden.

## Über dieses Repository

Dies ist das offizielle öffentliche Repository für Dokumentation und Feedback zu WindTorrent. Die App ist Closed Source; ihr Quellcode ist hier nicht enthalten. Aria2, qBittorrent und Transmission sind eigenständige Projekte und nicht mit WindTorrent verbunden.

[Website (Englisch/Chinesisch)](https://hienao-apps.pages.dev/windtorrent/) · [Datenschutz (Englisch/Chinesisch)](https://hienao-apps.pages.dev/windtorrent/privacy/) · [Support](mailto:shiwentao666@gmail.com)
