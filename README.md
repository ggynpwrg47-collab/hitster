# Jahrgang – Musik-Zeitleisten-Quiz (PWA)

Ein freundliches Musik-Quiz für Gruppen: Ein Song läuft, niemand sieht Titel oder Jahr, und alle raten,
wo er in ihre persönliche Zeitleiste gehört. Dazu gibt es einen einfachen Modus „Jahr raten“,
1–10 Spieler oder Teams, Veto-Chips, Überspringen, zufällige Reihenfolge und eine einstellbare
Rundenzahl. Jahrgang ist eigenständig gestaltet, nutzt keine Karten, Logos oder Inhalte von Hitster und
ist eine installierbare Progressive Web App ohne Konto, Werbung oder Abo.

> **Wichtig – Spotify:** Die [Spotify Developer Policy](https://developer.spotify.com/policy) verbietet
> Apps, die Spotify-Schnittstellen für **Spiele einschließlich Trivia-Quizze** nutzen. Außerdem liefert
> die Web-API seit Februar 2026 Playlist-Inhalte nur noch für **eigene oder kollaborative** Playlists.
> Jahrgang verwendet deshalb **keinen Spotify-Login, keine Web-API und kein Web Playback SDK**.
> Stattdessen: eigene Song-Listen (auch als CSV-Export), eigene Audiodateien oder normale Links bzw.
> Websuchen, die eure Musik-App öffnen. Details, Quellen und eine Beschreibung, wie eine Integration
> aussähe, falls Spotify die Regeln ändert: [docs/SPOTIFY.md](docs/SPOTIFY.md).

---

## Inhalt

1. [Funktionen und was davon abhängt](#funktionen)
2. [Architektur und Tech-Stack](#architektur)
3. [Lokal installieren und starten](#1-lokal-installieren-und-starten)
4. [Im lokalen Browser testen](#2-im-lokalen-browser-testen)
5. [Online über HTTPS bereitstellen](#3-online-über-https-bereitstellen)
6. [Spotify-Dashboard, Redirect-URLs und Umgebungsvariablen](#4-spotify-dashboard-redirect-urls-und-umgebungsvariablen)
7. [Spätere Veröffentlichung als native App](#5-spätere-veröffentlichung-als-native-app)
8. [Song-Listen und Jahreszahlen](#song-listen-und-jahreszahlen)
9. [Spielregeln inklusive Veto-Chips](#spielregeln)
10. [Datenspeicherung und Sicherheit](#datenspeicherung-und-sicherheit)
11. [Fehlerbehebung](#fehlerbehebung)

---

## Funktionen

| Funktion | Zuverlässig? | Abhängig von |
|---|---|---|
| Zeitleisten-Modus und „Jahr raten“, 1–10 Spieler/Teams, Runden, Zielkarten, Überspringen, Zufall | ✅ ja | – |
| Veto-Chips (ein-/ausschaltbar, Startanzahl einstellbar) | ✅ ja | – |
| Beispiel-Deck mit 62 Hits (1956–2022) | ✅ ja | – |
| Eigene Listen per Text, CSV oder TSV (u. a. mit Spalten aus gängigen Playlist-Exporten) | ✅ ja | Qualität der Daten |
| Eigene Spotify-Playlists aus dem offiziellen Spotify-Datenexport (JSON) einlesen | ✅ ja | Export muss bei Spotify angefordert werden; enthält keine Jahre |
| Jahres-Prüfung: Genauigkeit, Warnungen bei Remaster/Live/Compilation/Duplikaten, Korrektur | ✅ ja | – |
| Jahre online prüfen (MusicBrainz: früheste Veröffentlichung der Aufnahme, Vorschläge bei Abweichung) | ⚠️ meistens | Internet; Song muss in MusicBrainz erfasst sein; Datenqualität der Datenbank |
| Spotify-Songs direkt in der Spotify-App öffnen (ohne neuen Browser-Tab) | ✅ ja | installierte Spotify-App; Browser fragt beim ersten Mal nach |
| Eigene Audiodateien abspielen, ohne Titel zu verraten | ✅ ja | Dateiformat muss der Browser unterstützen (MP3/AAC überall) |
| Song über Link/Suche in Spotify, YouTube o. Ä. öffnen | ⚠️ teilweise | Konto und Abo beim Dienst; die Dienst-App zeigt den Titel an |
| QR-Code, um auf einem zweiten Gerät abzuspielen | ✅ ja | Kamera-App auf dem zweiten Gerät |
| Installation als App, offline spielbar | ✅ ja | Browser mit PWA-Unterstützung; Links brauchen Internet |
| Spotify-Login, Playlist-Auswahl aus dem Konto, Wiedergabe-Steuerung | ❌ nein | durch die Spotify-Policy ausgeschlossen |

## Architektur

- **Reine Frontend-App (statische Dateien)**, kein eigener Server, kein Backend, keine Datenbank.
  Das ist die einfachste sichere Variante für Einsteiger: Ohne Server gibt es keine Secrets, keine
  Tokens und nichts, was angegriffen werden könnte.
- **Tech-Stack:** [Vite](https://vite.dev) + React 19 + TypeScript, [Vitest](https://vitest.dev) für Tests,
  `qrcode` für QR-Codes. Service Worker und Manifest sind handgeschrieben (keine Build-Magie).
- **Spiel-Engine** (`src/lib/game.ts`): ein reiner Reducer ohne UI-Abhängigkeiten, vollständig getestet.
  Alle Aktionen (Raten, Bestätigen, Veto, Zurücknehmen, Aufdecken, Überspringen, Weiter, Neustart,
  Beenden) prüfen ihre Regeln selbst, sodass auch eine fehlerhafte Bedienung keinen ungültigen Zustand
  erzeugen kann.

```
src/
  App.tsx                 Ansichten, Zustand, Speicherung
  types.ts                Datenmodell
  lib/game.ts             Spielregeln und Veto-Chips (Reducer)
  lib/years.ts            Datum/Genauigkeit, Warnungen, Duplikate
  lib/importer.ts         Text-/CSV-Import, Dateinamen
  lib/id3.ts              MP3-Tags lesen (inkl. Original-Datum TDOR/TORY)
  lib/links.ts            Link-Prüfung, Suchlinks
  lib/storage.ts          localStorage (nur lokal)
  lib/demoDeck.ts         Beispiel-Deck
  components/             Startseite, Import, Prüfansicht, Setup, Spiel, Ergebnis, Dialoge …
public/                   Manifest, Service Worker, Icons, Sicherheits-Header
docs/                     Spotify-Analyse, Testplan, Sicherheitsprüfung
```

---

## 1. Lokal installieren und starten

**Voraussetzungen:** [Node.js](https://nodejs.org) ab Version 20 (empfohlen: 22 LTS) und Git.

```bash
git clone <URL-dieses-Repositorys> jahrgang
cd jahrgang
npm install
npm run dev
```

Dann im Browser **http://127.0.0.1:5173** öffnen. Änderungen am Code werden sofort neu geladen.
Eine `.env`-Datei ist nicht nötig. Nur wenn du in einem Unterordner hosten willst, kopierst du
`.env.example` nach `.env.local` und passt `VITE_BASE_PATH` an.

## 2. Im lokalen Browser testen

```bash
npm test            # automatische Tests
npm run build       # Produktions-Build nach dist/
npm run preview     # Build lokal ausliefern: http://127.0.0.1:4173
```

- Der **Service Worker** (Offline-Modus, Installation) ist nur im Build aktiv, also mit `npm run preview` testen.
- **Handy-Ansicht:** In den Chrome-DevTools (F12) den Gerätemodus einschalten (Strg+Shift+M).
- **Auf dem echten Handy im WLAN:** `npm run dev -- --host` bzw. `npm run preview -- --host` und die
  angezeigte Netzwerk-Adresse öffnen. Ohne HTTPS funktionieren Spielen und Audiodateien; die
  Installation als App und der Offline-Modus brauchen aber HTTPS (siehe Abschnitt 3).
- Eine ausführliche Checkliste steht in [docs/TESTING.md](docs/TESTING.md).

## 3. Online über HTTPS bereitstellen

Jahrgang besteht nur aus statischen Dateien (`dist/`), daher eignet sich jeder kostenlose Static-Hoster.
Alle folgenden Anbieter liefern automatisch **HTTPS**, was für die PWA-Installation nötig ist.

**Netlify (empfohlen, am einfachsten)**
1. Repository bei GitHub hochladen.
2. Auf netlify.com „Add new site → Import from Git“ wählen.
3. Build command `npm run build`, Publish directory `dist`.
4. Die Sicherheits-Header aus `public/_headers` werden automatisch übernommen.

**Cloudflare Pages:** gleiche Einstellungen (Framework „Vite“, Ausgabe `dist`); `_headers` wird ebenfalls unterstützt.

**Vercel:** „Import Project“, Framework „Vite“; die Header kommen aus `vercel.json`.

**GitHub Pages:** In den Repository-Einstellungen unter *Pages* als Quelle „GitHub Actions“ wählen und dann
unter *Actions* den Workflow **„Deploy to GitHub Pages“** manuell starten. Er setzt `VITE_BASE_PATH`
automatisch auf `/<repo-name>/`. Hinweis: GitHub Pages unterstützt keine eigenen HTTP-Header, die CSP
aus `_headers` greift dort also nicht.

Danach die HTTPS-Adresse auf dem Handy öffnen und „Zum Startbildschirm hinzufügen“ wählen:
- **Android/Chrome:** Menü ⋮ → „App installieren“
- **iPhone/iPad (Safari):** Teilen → „Zum Home-Bildschirm“
- **Desktop Chrome/Edge:** Installieren-Symbol in der Adressleiste

## 4. Spotify-Dashboard, Redirect-URLs und Umgebungsvariablen

**Für Jahrgang ist kein Spotify-Developer-Dashboard nötig.** Es gibt keine Client-ID, kein Client-Secret
und keine Redirect-URL, weil die App aus den oben genannten Policy-Gründen keine Spotify-Schnittstelle
verwendet. **Lege bitte auch keine Spotify-App für Jahrgang an.**

Umgebungsvariablen (`.env.example`):

| Variable | Zweck | Standard |
|---|---|---|
| `VITE_BASE_PATH` | Unterordner beim Hosting (z. B. `/jahrgang/`) | `/` |

Alle `VITE_`-Variablen landen im öffentlichen JavaScript. Dort niemals Secrets eintragen. `.env` und
`.env.local` sind per `.gitignore` vom Repository ausgeschlossen.

Falls Spotify Spiele künftig erlaubt, beschreibt [docs/SPOTIFY.md](docs/SPOTIFY.md#5-falls-spotify-die-regeln-eines-tages-ändert)
die korrekte Einrichtung: Authorization Code mit PKCE ohne Secret, minimale Scopes, Redirect-URIs
`http://127.0.0.1:5173/callback` (lokal, nicht `localhost`) und `https://<deine-domain>/callback`.

## 5. Spätere Veröffentlichung als native App

1. **Android (am einfachsten):** Die PWA mit [Bubblewrap](https://github.com/GoogleChromeLabs/bubblewrap)
   oder [PWABuilder](https://www.pwabuilder.com) als *Trusted Web Activity* verpacken. Dafür brauchst du
   die HTTPS-Adresse, `/.well-known/assetlinks.json` auf der Domain, einen Signierschlüssel und ein
   Google-Play-Entwicklerkonto (einmalige Gebühr).
2. **iOS und Android mit eigenem Code:** Mit [Capacitor](https://capacitorjs.com) das `dist/`-Verzeichnis
   in eine native Hülle einbetten (`npx cap add ios/android`). Für iOS sind ein Mac mit Xcode und eine
   Apple-Developer-Mitgliedschaft (jährliche Gebühr) nötig. Für Audiodateien aus dem Dateisystem
   empfiehlt sich ein Datei-Plugin.
3. **Store-Anforderungen:** Datenschutzerklärung (es werden keine Daten erhoben), App-Icons und
   Screenshots, Altersfreigabe. Apple verlangt, dass eine App mehr bietet als eine verpackte Website
   (Guideline 4.2). Offline-Modus und lokale Audiodateien helfen dabei.
4. **Marken:** Keine fremden Marken im Namen, Icon oder in den Screenshots verwenden. Musikdienste nur
   textlich als Link-Ziel nennen. Eine native Spotify-Integration (iOS/Android SDK) unterliegt derselben
   Developer Policy und ist für Spiele ebenfalls nicht erlaubt.

---

## Song-Listen und Jahreszahlen

**Formate beim Import:**
- **Eigene Spotify-Playlists über den offiziellen Datenexport:** Im Spotify-Konto unter *Datenschutzeinstellungen →
  „Deine Daten herunterladen“* die Kontodaten anfordern. Danach die Datei `Playlist1.json` (bzw. `YourLibrary.json` für die
  Lieblingssongs) im Reiter *Spotify-Datenexport* wählen und die gewünschten Playlists ankreuzen. Titel, Interpret, Album
  und Spotify-Link werden übernommen. **Jahre enthält der Export nicht**; die werden in der Prüfansicht ergänzt. Das
  Dateiformat ist von Spotify nicht öffentlich dokumentiert, darum akzeptiert der Import mehrere übliche Feldnamen.
- **CSV aus einem Export-Tool** (z. B. Exportify): enthält zusätzlich das Album-Datum und spart so Tipparbeit.
- Freitext, eine Zeile pro Song: `Interpret - Titel (Jahr)`, `Interpret – Titel; Jahr` und optional ein Link
  (`https://…` oder `spotify:track:…`, wird zu einem normalen Web-Link). `#` leitet einen Kommentar ein.
- CSV/TSV mit Kopfzeile (Trennzeichen Komma, Semikolon oder Tab). Erkannt werden z. B. `Titel/Title/Track Name`,
  `Interpret/Artist/Artist Name(s)`, `Jahr/Year`, `Release Date` + `Release Date Precision`, `Album`, `Link/URL/Track URI`.
- Eigene Audiodateien: ID3v2-Tags (`TDOR`/`TORY` = Original-Veröffentlichung, `TDRC`/`TYER` = Jahr der Datei)
  oder der Dateiname `Interpret - Titel (Jahr).mp3`.

**Umgang mit Jahreszahlen:**
- Die **Genauigkeit** der Quelle bleibt erhalten: `1985` wird als „nur Jahr bekannt“ angezeigt,
  `1985-03` als „03/1985“. Eine Angabe wie `release_date_precision = year` verringert die Genauigkeit;
  aus einem Jahr wird nie ein Tagesdatum.
- **Album-/Release-Daten gelten nie automatisch als Erstveröffentlichung.** Sie werden als „Album-/Release-Datum –
  evtl. Neuauflage“ markiert und müssen bestätigt werden.
- **Warnungen** erscheinen bei Remaster, Live, Remix/Edit, Neuaufnahme („Taylor's Version“), Deluxe-/Jubiläumsausgaben,
  Compilations („Greatest Hits“, „Best of“ …), unscharfen Angaben (`ca. 1975`, `1975/76`, `1975?`), Datei-Tags ohne
  Original-Datum, Duplikaten und widersprüchlichen Jahren.
- **Online prüfen:** In der Prüfansicht unter *Jahre online prüfen* sucht Jahrgang in der offenen Datenbank
  [MusicBrainz](https://musicbrainz.org) nach der frühesten Veröffentlichung einer Aufnahme mit gleichem Titel und
  Interpreten. Zusätze wie „- Remastered 2011“, „(Live …)“ oder „(feat. …)“ werden vorher entfernt. Ergebnis:
  ✓ bestätigt, fehlendes Jahr ergänzt, oder bei Abweichung ein Vorschlag („1975 übernehmen“ / „2011 behalten“, auch
  „Alle Vorschläge übernehmen“). Es werden nur Interpret und Titel gesendet, mit höchstens 1 Anfrage pro Sekunde
  (Vorgabe von MusicBrainz). Die Prüfung startet nur auf Knopfdruck.
- In der **Prüfansicht** korrigiert oder bestätigt man die Jahre; ein von Hand eingetragenes Jahr gilt als geprüft.
  Songs ohne Jahr werden nicht gespielt. Beim Aufdecken ungeprüfter oder gewarnter Songs erscheint „⚠ Jahr unsicher“.

## Spielregeln

- **Zeitleiste:** Jeder startet mit einer aufgedeckten Karte. Der aktive Spieler ordnet den unbekannten Song in eine
  Lücke seiner Zeitleiste ein und bestätigt. Richtig = Karte bleibt liegen, +1 Punkt. Gleiche Jahre dürfen links
  oder rechts liegen.
- **Jahr raten:** Jahr schätzen; exakt 3 Punkte, ±1 Jahr 2 Punkte, ±2–3 Jahre 1 Punkt.
- **Veto-Chips:** Nach dem Bestätigen und vor dem Aufdecken darf jeder andere Spieler einen Chip setzen (ein Veto pro
  Spieler und Zug), und zwar auf eine andere Lücke in der Zeitleiste des aktiven Spielers bzw. auf ein anderes Jahr.
  Auf jeder Position liegt höchstens ein Chip, nie auf der Position des aktiven Spielers. Vor dem Einsatz erscheint ein
  Bestätigungsdialog mit dem Chipstand. Liegt der aktive Spieler falsch und ein Veto richtig, ordnet der Veto-Spieler
  die Karte in **seine eigene** Zeitleiste ein (+1 Punkt; bei mehreren richtigen Chips gewinnt der zuerst gesetzte).
  Im Jahres-Modus übernimmt die nähere Veto-Schätzung die Punkte. Ein gesetzter Chip ist verbraucht. Vor dem Aufdecken
  kann er zurückgenommen werden, und beim Überspringen wird er erstattet. Nach dem ersten Veto ist die Wahl des aktiven
  Spielers gesperrt. Beim Neustart werden alle Chips auf den Startwert zurückgesetzt.
- **Spielende:** nach der eingestellten Rundenzahl, beim Erreichen der Zielkarten oder wenn der Stapel leer ist.

## Datenspeicherung und Sicherheit

- **Lokal im Browser** (`localStorage`): eigene Song-Listen, Einstellungen, Spielernamen und ein laufendes Spiel.
- **Nicht gespeichert:** Audiodateien (nur im Arbeitsspeicher), Passwörter, Tokens, Konten. Es gibt keinen Server,
  kein Tracking und keine Cookies.
- **Einzige Verbindung zu einem fremden Dienst:** die optionale Online-Prüfung der Jahre (Interpret + Titel an musicbrainz.org).
- Unter *Info & Datenschutz → Alle lokalen Daten löschen* lässt sich alles entfernen.
- Die Ergebnisse der Sicherheitsprüfung (Secrets, Tokens, Scopes, Redirects, CSP, Links) stehen in [docs/SECURITY.md](docs/SECURITY.md).

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| `npm install` schlägt fehl | Node-Version prüfen (`node -v`, mindestens 20). `node_modules` löschen und neu installieren. |
| Port 5173 ist belegt | `npm run dev -- --port 5180` |
| Handy erreicht den Dev-Server nicht | `npm run dev -- --host`, Firewall freigeben, beide Geräte im selben WLAN |
| „App installieren“ erscheint nicht | Nur über HTTPS (oder `127.0.0.1`) und im Build (`npm run preview` bzw. gehostet). Auf iOS nur in Safari über „Teilen“. |
| Nach einem Update ist die alte Version zu sehen | Seite schließen und neu öffnen (der Service Worker aktualisiert sich beim nächsten Start) oder in den DevTools unter *Application → Service Workers* auf „Update“ klicken. |
| Audiodatei spielt nicht | Format prüfen (MP3/AAC funktionieren überall; FLAC/OGG nicht in jedem Safari). Nach dem Neuladen Dateien erneut auswählen. |
| Song-Link öffnet die falsche Version | In der Prüfansicht einen direkten Link zur Originalversion eintragen. |
| Jahre wirken falsch | Prüfansicht → Filter „Zu prüfen“. Album- und Remaster-Daten korrigieren. |
| Klick auf „In der Spotify-App öffnen“ bewirkt nichts | Spotify-Desktop-App installiert? Beim ersten Mal die Browser-Nachfrage „Spotify öffnen?“ bestätigen. Sonst den Link „Im Browser öffnen“ nutzen oder unter *Info & Datenschutz* auf „Browser-Tab“ umstellen. |
| Spotify kommt beim Abspielen in den Vordergrund und zeigt den Titel | Lässt sich aus einer Web-App nicht verhindern. Mit Alt+Tab (Mac: ⌘+Tab) zurück, oder die Musik per QR-Code auf einem Handy abspielen, das verdeckt liegt. |
| Online-Prüfung meldet nur Fehler | Internetverbindung prüfen; manche Werbeblocker oder Firmennetze sperren musicbrainz.org. Bei Überlastung später erneut versuchen. |
| Spotify verlangt beim Öffnen eines Links ein Login/Abo | Das entscheidet Spotify. Alternativ unter *Info & Datenschutz* die YouTube-Suche wählen oder eigene Audiodateien nutzen. |
| Daten sind weg | Privates Fenster oder gelöschte Browserdaten leeren `localStorage`. Song-Listen am besten auch als Text/CSV aufbewahren. |
| Seite bleibt auf GitHub Pages leer | Ist `VITE_BASE_PATH` auf `/<repo-name>/` gesetzt? Der mitgelieferte Workflow erledigt das automatisch. |

## Lizenz und Hinweise

Jahrgang ist ein unabhängiges Projekt ohne Verbindung zu Spotify, Hitster oder anderen Marken. Das Beispiel-Deck
enthält nur Fakten (Interpret, Titel, Jahr), keine Audiodaten und keine Cover.
