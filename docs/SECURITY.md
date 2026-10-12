# Sicherheitsprüfung

| Prüfpunkt | Ergebnis |
|---|---|
| **Offengelegte Secrets** | Es gibt keine. Die App braucht weder Client-ID noch Client-Secret oder API-Key. `.env*` steht in `.gitignore` (außer `.env.example`, die nur `VITE_BASE_PATH` enthält). Hinweis: Alles mit dem Präfix `VITE_` landet im öffentlichen JavaScript – dort dürfen nie Secrets stehen. |
| **Token-Speicherung** | Es gibt keine Tokens, Passwörter oder Konten. In `localStorage` liegen nur Song-Listen, Spielernamen, Einstellungen und der Spielstand; unter *Info & Datenschutz* lässt sich alles löschen. |
| **OAuth-Scopes** | Keine, weil es keinen OAuth-Flow gibt (siehe [SPOTIFY.md](SPOTIFY.md); dort steht auch, welche minimalen Scopes nötig wären, falls Spotify die Policy ändert). |
| **Redirect-URLs** | Keine. Es gibt also keine offenen Weiterleitungen und keine Callback-Route. |
| **Externe Links** | Nur `http(s)` wird akzeptiert (`javascript:` u. a. werden verworfen, siehe Tests). Links öffnen mit `noopener,noreferrer` in einem neuen Fenster. |
| **XSS** | React escaped alle Texte; es gibt kein `dangerouslySetInnerHTML`. Importierte Texte werden nie als HTML interpretiert. |
| **Content Security Policy** | `public/_headers` (Netlify/Cloudflare) und `vercel.json` setzen eine strikte CSP (`script-src 'self'`, kein Inline-JS, `frame-ancestors 'none'`, `form-action 'none'`). Ein Browser-Test mit dieser CSP lief ohne Verstöße. |
| **Dateien** | Text-Importe sind auf 5 MB begrenzt. Audiodateien werden nur als Object-URL im Tab verwendet, nie hochgeladen oder gespeichert. Der ID3-Parser liest höchstens 2 MB und prüft alle Längenangaben gegen die Puffergrenzen. |
| **Service Worker** | Er cacht nur Anfragen an die eigene Herkunft (GET); fremde Anfragen werden nie abgefangen. |
| **Abhängigkeiten** | Laufzeit: nur `react`, `react-dom` und `qrcode`. `npm audit` meldet 0 Schwachstellen (Stand der Erstellung). |
| **Tracking/Werbung** | Keines. |
