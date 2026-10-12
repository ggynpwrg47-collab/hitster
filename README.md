# SparListe

Private iPhone-App für Einkaufslisten mit Preisvergleich und **Optimierung der günstigsten Einkaufsaufteilung über mehrere Supermärkte**.

Du legst eine Einkaufsliste an, wählst aus, welche Läden berücksichtigt werden und wie viele Läden du maximal besuchen willst (1, 2, 3 oder unbegrenzt). Die App berechnet daraus die günstigste praktikable Aufteilung – unter Beachtung von Markenvorgaben, Packungsgrößen, aktuell gültigen Angeboten und Verfügbarkeit.

> **Nur für die private Nutzung.** Die App ist nicht für den App Store gedacht und enthält bewusst keine Store-Metadaten, Screenshots oder Release-Prozesse.
>
> **Keine echten Preise.** Die mitgelieferten Preise und Angebote sind **erfundene Beispieldaten** (in der App deutlich gekennzeichnet). Echte Preise erfasst du selbst oder importierst sie als JSON – siehe [Datenquellen](#datenquellen-und-grenzen).

---

## Inhalt

- [Funktionen (Version 1)](#funktionen-version-1)
- [Tech-Stack und Begründung](#tech-stack-und-begründung)
- [Architektur und Projektstruktur](#architektur-und-projektstruktur)
- [Datenmodell](#datenmodell)
- [So rechnet die Optimierung](#so-rechnet-die-optimierung)
- [Installation auf dem iPhone](#installation-auf-dem-iphone)
- [Tests ausführen](#tests-ausführen)
- [Datenquellen und Grenzen](#datenquellen-und-grenzen)
- [Beispielrechnung (manuell geprüft)](#beispielrechnung-manuell-geprüft)
- [Roadmap](#roadmap)

---

## Funktionen (Version 1)

**Einkaufslisten**
- Listen anlegen, umbenennen, löschen, **duplizieren und wiederverwenden** (Kopie mit zurückgesetzten Häkchen).
- Produkte hinzufügen (mit **Autovervollständigung** aus dem Katalog), bearbeiten, löschen, abhaken.
- Allgemeine Einträge („Laktosefreie Milch“) oder markenspezifische („Laktosefreie Milch – MinusL“, „Spaghetti – Ja!“).
- Optional pro Eintrag: Menge, gewünschte Packungsgröße, Wunschmarke (optional mit erlaubter Alternative), Bio bevorzugt, Eigenmarke bevorzugt, ausgeschlossene Marken, ausgeschlossene Zutaten, Notiz.
- Abgehakte Produkte bleiben sichtbar („Erledigt“), werden aber **nicht optimiert**.

**Läden**
- Vordefinierte Ketten als Kategorien: REWE, EDEKA, Aldi, Lidl, Kaufland, Netto, Penny, Marktkauf, Globus (+ „Sonstiger Laden“).
- Pro Laden: Name, Adresse/PLZ, Entfernung, Öffnungszeiten, „aktuell geöffnet“ (berechnet), bevorzugt, **in Berechnung einbeziehen** (Toggle), optional Koordinaten.
- Maximale Ladenanzahl: **1, 2, 3 oder unbegrenzt**.

**Optimierung** – vier Modi:
1. Günstigster Gesamtpreis über alle aktivierten Läden
2. Günstigster Gesamtpreis bei maximal X Läden
3. Günstigste Lösung mit genau einem Laden
4. Bester Kompromiss aus Preis und Wegstrecke (einstellbare Wegkosten pro km)

**Ergebnisanzeige**
- Läden in empfohlener Reihenfolge (Route), pro Laden die zu kaufenden Produkte.
- Pro Produkt: Preis, Packungsanzahl und -größe, Einheitspreis, Aktionskennzeichnung (inkl. „statt“-Preis), Aktualität (aktuell / geschätzt / veraltet), Herkunft (Beispieldaten / manuell / Import).
- Zwischensumme pro Laden, Gesamtpreis, **Ersparnis gegenüber der besten Ein-Laden-Lösung**.
- Nicht verfügbare Produkte separat mit Grund und **Alternativvorschlägen**.
- Hinweise auf bald ablaufende Angebote, veraltete/geschätzte Preise, nicht erfüllbare Vorlieben.
- Alternativen: günstigste Variante mit 1, 2 und 3 Läden, günstigste insgesamt, kürzeste Wegstrecke, Kompromiss.
- Produkte direkt im Ergebnis abhaken (wird in der Liste gespeichert).

**Produkte & Preise**
- Katalog durchsuchen, Produkte und Marken anlegen, Preise und Angebote (mit Gültigkeitszeitraum, Verfügbarkeit, Quelle) erfassen.
- JSON-Import von Marken, Produkten und Preisen.
- „Beispieldaten wiederherstellen“ (unter „Läden“).

---

## Tech-Stack und Begründung

| Bereich | Wahl |
|---|---|
| Sprache | Swift 5.9+ (Swift-5-Sprachmodus) |
| UI | SwiftUI, iOS 17+, nur iPhone |
| Zustand | Observation (`@Observable`) View Models |
| Domänenlogik | Lokales Swift Package `SparListeKit` (nur Foundation) |
| Persistenz | JSON-Datei im Application-Support-Verzeichnis, hinter Repository-Protokollen |
| Tests | XCTest (laufen auf macOS, iOS-Simulator **und** Linux) |

**Warum nativ (Swift/SwiftUI) statt Flutter, React Native oder Kotlin Multiplatform?**

- **Priorität ist eine saubere, wartbare iOS-App.** SwiftUI ist auf dem iPhone die direkteste, am besten unterstützte Lösung – ohne zusätzliche Toolchains, Bridges oder Build-Systeme. Installation per Xcode auf das eigene iPhone ist damit trivial.
- **Spätere Android-Erweiterung bleibt offen**, weil die gesamte fachliche Logik (Modelle, Preis- und Optimierungslogik, Datenzugriff) in einem **plattformneutralen Swift Package ohne UIKit/SwiftUI** liegt. Dieses Package wird bereits heute unter Linux gebaut und getestet. Für Android gibt es zwei realistische Wege:
  1. das Package mit dem Swift SDK für Android weiterverwenden und nur eine Android-UI (z. B. Jetpack Compose) davorsetzen, oder
  2. die klar abgegrenzte und vollständig durch Tests spezifizierte Logik nach Kotlin portieren – die Tests dienen dabei als ausführbare Spezifikation.
  Das Datenformat (JSON) ist plattformunabhängig.
- Cross-Platform-Frameworks hätten für eine reine iPhone-Version 1 zusätzliche Komplexität bedeutet, ohne heute einen Nutzen zu bringen.

**Warum JSON-Datei statt SwiftData/Core Data?** Der Datenbestand ist klein (Listen, einige Läden, einige hundert Preise). Eine JSON-Datei ist transparent, leicht zu sichern/importieren, plattformneutral und in Tests ohne Apple-Frameworks nutzbar. Da alle Zugriffe über Repository-Protokolle laufen, lässt sich später eine Datenbank einsetzen, ohne UI oder Domänenlogik zu ändern.

---

## Architektur und Projektstruktur

```
SparListe.xcodeproj            Xcode-Projekt (App-Target, bindet das lokale Package ein)
project.yml                    Alternative Projektbeschreibung für XcodeGen (Fallback)
SparListe/                     ── UI-Schicht (SwiftUI) ──
  App/                         App-Einstieg, Tab-Navigation, Verdrahtung der Abhängigkeiten
  Views/Lists/                 Startbildschirm, Listeneditor, Produktdetails
  Views/Stores/                Ladenverwaltung, Berechnungseinstellungen
  Views/Optimization/          Ergebnis, Route, Alternativen
  Views/Catalog/               Produkte, Preise, Angebote, JSON-Import
  Views/Components/            Badges, Lade-/Fehlerzustände, Eingabehilfen
  Assets.xcassets              App-Icon, Akzentfarbe
SparListeKit/                  Lokales Swift Package
  Sources/SparListeFeatures/   ── View Models ── (Observation, ohne SwiftUI → testbar)
  Sources/SparListeCore/
    Models/                    ── Datenmodelle ── Money, Quantity, Product, Brand, Store, PriceEntry, ShoppingList, Settings
    Domain/                    ── Domänenlogik ── Einheitspreise, Angebotsgültigkeit, Preisauflösung,
                               Produktzuordnung, Item-Analyse, Wegplanung, Optimierer, Ergebnisse
    Data/                      ── Repositories & Persistenz ── Protokolle, LocalDataStore,
                               JSON-Persistenz, Import, Beispieldaten
    Services/                  Autovervollständigung
  Tests/SparListeCoreTests/    Unit- und End-to-End-Tests der Logik
  Tests/SparListeFeaturesTests/ Tests der View Models
```

**Schichten und Abhängigkeitsrichtung**

```
SwiftUI-Views ──► View Models (SparListeFeatures) ──► Repository-Protokolle + Domänenlogik (SparListeCore)
                                                         ▲
                                     LocalDataStore (JSON) implementiert die Protokolle
```

- Die UI kennt nur View Models. Die View Models kennen nur `AppDependencies` – eine Sammlung von Protokollen (`ShoppingListRepository`, `StoreRepository`, `CatalogRepository`, `PriceDataSource`/`PriceRepository`, `SettingsRepository`) plus den Optimierer.
- Die Optimierung (`ShoppingOptimizer`) ist eine reine, synchrone Funktion ohne Seiteneffekte: Liste + Läden + Katalog + Preise + Einstellungen + Zeitpunkt → Ergebnis. Dadurch ist sie vollständig deterministisch testbar.
- Neue Datenquellen (API, Import, Scraper eines erlaubten Anbieters …) implementieren `PriceDataSource`; mehrere Quellen lassen sich mit `CompositePriceDataSource` kombinieren.

---

## Datenmodell

| Typ | Inhalt |
|---|---|
| `Money` | Betrag in Cent (ganzzahlig, exakte Summen) |
| `Quantity` | Wert + Einheit (g, kg, ml, l, Stk.); vergleichbar nur innerhalb derselben Dimension |
| `Brand` | Name, optional Eigenmarke einer Kette (`privateLabelOf`) |
| `Product` | Konkreter Artikel: Name, **allgemeiner Name** (für die Zuordnung), Marke, Packungsgröße, Bio, Zutaten, Suchbegriffe, Kategorie |
| `Store` | Kette, Name, Adresse/PLZ, Entfernung, Koordinaten, Öffnungszeiten, bevorzugt, einbezogen |
| `PriceEntry` | Produkt, Laden, Preis, **regulär oder Angebot (gültig von/bis)**, Verfügbarkeit, Quelle, Erfassungszeitpunkt. Einheitspreis wird aus Preis + Packungsgröße berechnet. |
| `PriceFreshness` | aktuell / geschätzt / veraltet (abgeleitet aus Quelle und Alter) |
| `ShoppingList` / `ShoppingListItem` | Liste mit Einträgen inkl. aller Vorgaben und Häkchen |
| `OptimizationSettings` | Modus, max. Ladenanzahl, Wegkosten/km, nur geöffnete Läden, Warnschwelle für Angebote, Startpunkt |
| `OptimizationResult` | Empfehlung (`ShoppingPlan` mit `PlanStop`s und `PlanLine`s), Alternativen, nicht verfügbare Produkte, Ersparnis, Hinweise |

---

## So rechnet die Optimierung

**1. Analyse je Listeneintrag** (`ItemAnalyzer`)
1. **Zuordnung:** Produkte, deren allgemeiner Name exakt dem Suchbegriff entspricht; sonst Produkte, deren Name/Marke/Suchbegriffe alle Suchwörter enthalten (Groß-/Kleinschreibung und Umlaute egal).
2. **Harte Ausschlüsse:** ausgeschlossene Marken und Zutaten.
3. **Bedarf:** `Menge × gewünschte Packungsgröße`. Ohne Packungsgröße: `Menge × häufigste Packungsgröße` der passenden Produkte.
4. **Preis je Produkt und Laden:** Angebote zählen **nur innerhalb ihres Gültigkeitszeitraums** (erster Tag 0:00 bis letzter Tag 23:59). Der jüngste gültige Eintrag bestimmt die Verfügbarkeit; unter den verfügbaren gewinnt der niedrigste Preis.
5. **Packungsanzahl:** so viele Packungen, dass der Bedarf gedeckt ist (z. B. 1 kg Bedarf → 4 × 250 g oder 1 × 1 kg). Verglichen werden die **tatsächlichen Kosten**, der Einheitspreis dient als Gleichstandsregel und zur Anzeige.
6. **Markenvorgabe hat Vorrang:** Nur Produkte der Wunschmarke kommen in Frage. Ist sie in keinem berücksichtigten Laden verfügbar, wird der Eintrag als „nicht verfügbar“ mit bis zu drei Alternativen (günstigster Einheitspreis) angezeigt – oder, wenn erlaubt, automatisch durch die günstigste Alternative ersetzt (mit Hinweis).
7. **Vorlieben (Bio, Eigenmarke):** Gibt es in den berücksichtigten Läden mindestens eine passende Variante, werden nur diese verglichen; sonst Rückfall mit Hinweis.
8. Ergebnis: die günstigste Option **je Laden**.

**2. Ladenauswahl** (`ShoppingOptimizer`) – exakt, keine Heuristik:
- Für eine Ladenmenge S kostet jeder Eintrag das Minimum seiner Optionen in S.
- Es werden **alle Ladenmengen bis zur maximalen Anzahl** aufgezählt und lexikografisch verglichen:
  (a) möglichst viele abgedeckte Produkte → (b) Zielwert (Preis / Preis + Wegkosten / Weg) → (c) Gesamtpreis → (d) weniger Läden → (e) kürzerer Weg.
- Ohne Ladenlimit (Preisziel) wird jeder Eintrag direkt seinem günstigsten Laden zugeordnet – ebenfalls optimal.
- Rechenaufwand: bei z. B. 15 aktiven Läden und max. 3 Läden sind das 575 Kombinationen – vernachlässigbar.

**3. Route:** Mit Koordinaten aller Läden und Startpunkt: exakte kürzeste Rundtour (Luftlinie × 1,3 Umwegfaktor). Sonst Schätzung aus den Entfernungen (Läden nach Entfernung sortiert). Die Grundlage wird in der App angezeigt.

**4. Ersparnis:** Vergleich mit der besten Ein-Laden-Lösung auf den Produkten, die in beiden Varianten enthalten sind. Deckt der einzelne Laden nicht alles ab, wird das ausgewiesen.

---

## Installation auf dem iPhone

**Voraussetzungen**
- Mac mit **Xcode 16 oder neuer** (das Projekt nutzt synchronisierte Ordner, Projektformat 77)
- iPhone mit **iOS 17 oder neuer** und USB-/WLAN-Verbindung zum Mac
- Eine Apple-ID (ein kostenloser Account genügt)

**Schritte**
1. Repository klonen und `SparListe.xcodeproj` in Xcode öffnen. Xcode löst das lokale Package `SparListeKit` automatisch auf.
2. In Xcode links das Projekt **SparListe** → Target **SparListe** → Reiter **Signing & Capabilities**:
   - „Automatically manage signing“ aktiviert lassen,
   - unter **Team** deine Apple-ID wählen (ggf. über *Xcode → Settings → Accounts* hinzufügen),
   - **Bundle Identifier** auf etwas Eindeutiges ändern, z. B. `de.deinname.sparliste`.
3. iPhone anschließen, entsperren und dem Mac vertrauen. Auf dem iPhone **Entwicklermodus** aktivieren: *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* (Neustart nötig).
4. In Xcode oben dein iPhone als Ziel wählen und **Run** (⌘R) drücken.
5. Beim ersten Start ggf. auf dem iPhone dem Entwicklerzertifikat vertrauen: *Einstellungen → Allgemein → VPN & Geräteverwaltung → [deine Apple-ID] → Vertrauen*.

> Mit einem **kostenlosen** Apple-Account ist die installierte App **7 Tage** gültig; danach einfach erneut aus Xcode starten (die Daten bleiben erhalten). Mit einem kostenpflichtigen Developer-Account gilt sie 1 Jahr.

**Falls sich das Projekt nicht öffnen lässt** (z. B. ältere Xcode-Version): Mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` neu erzeugen:
```bash
brew install xcodegen
xcodegen generate
```

Die App speichert ihre Daten in `Application Support/sparliste.json` im App-Container. Beim allerersten Start werden die Beispieldaten angelegt.

---

## Tests ausführen

Die gesamte Domänen- und View-Model-Logik liegt im Package und ist ohne Simulator testbar.

**Kommandozeile (macOS oder Linux mit Swift ≥ 5.9):**
```bash
cd SparListeKit
swift test
```

**In Xcode:** `SparListe.xcodeproj` öffnen und **Product → Test** (⌘U). Das Scheme „SparListe“ führt die Package-Tests aus. Alternativ `SparListeKit/Package.swift` direkt in Xcode öffnen und ⌘U.

**Per xcodebuild im iOS-Simulator:**
```bash
xcodebuild test -project SparListe.xcodeproj -scheme SparListe \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Abgedeckt (76 Tests):**

| Bereich | Testdatei |
|---|---|
| Geld, Mengen, Formatierung | `MoneyAndQuantityTests` |
| Einheitspreise, Packungsanzahl, Vergleichbarkeit verschiedener Packungsgrößen | `UnitPricingTests` |
| Angebotsvalidität (Tagesgrenzen, abgelaufen, zukünftig), Preisauflösung, Verfügbarkeit, Aktualität | `OfferValidityTests` |
| Markenvorgaben, Alternativen, Ersatz, Ausschlüsse, Bio/Eigenmarke | `BrandRequirementTests` |
| Optimierung: 1 Laden, max. 2/3 Läden, unbegrenzt, Kompromiss, Route, Brute-Force-Gegenprobe, abgehakte/deaktivierte/geschlossene Läden | `OptimizerTests` |
| Nicht verfügbare Produkte, Ersparnisberechnung | `AvailabilityAndSavingsTests` |
| **End-to-End:** 5 Produkte, 3 aktive Läden, 1 aktuelles + 1 abgelaufenes Angebot, max. 2 Läden – über JSON-Datei → Repository → Optimierer | `EndToEndTests` |
| README-Beispielrechnung mit den Beispieldaten | `SampleScenarioTests` |
| Persistenz, Duplizieren, JSON-Import, Importbeispiel aus diesem README | `PersistenceTests` |
| Autovervollständigung, Textnormalisierung | `SuggestionAndMatchingTests` |
| View Models (Listen, Editor, Läden, Optimierung, Katalog, Fehlerzustände) | `ViewModelTests` |

---

## Datenquellen und Grenzen

**Aktueller Stand: ausschließlich lokale Daten.** Es gibt keine verlässliche, öffentlich zugängliche und frei nutzbare Schnittstelle für aktuelle Regalpreise der deutschen Supermarktketten. Die App verwendet deshalb **keine Live-APIs** und erfindet auch keine.

| Quelle | Kennzeichnung | Grenzen |
|---|---|---|
| Mitgelieferte Beispieldaten (4 Läden in „Musterstadt“, 12 Produktarten, 49 Artikel, 20 Marken, mehrere Angebote) | „Beispieldaten“ (lila) | **Erfunden.** Preise, Angebote, Packungsgrößen, Zutaten, Adressen und Öffnungszeiten sind fiktiv; Markennamen dienen nur als Beispiele. Angebote werden beim ersten Start relativ zum aktuellen Datum angelegt und laufen danach – wie echte Angebote – ab. |
| Manuelle Eingabe (Tab „Preise“) | „Manuell“ | So aktuell, wie du sie pflegst. Reguläre Preise gelten nach **14 Tagen** als „veraltet“. |
| JSON-Import | „Import“ | Nur so gut wie die Datei. Unbekannte Produkt-IDs werden abgelehnt. |
| Geschätzte Preise (Quelle „Schätzung“) | „Geschätzt“ (orange) | Ausdrücklich als Schätzung markiert. |

Weitere Grenzen von Version 1:
- Wegstrecken sind Näherungen (Luftlinie × 1,3 bzw. Schätzung aus Entfernungen), keine Navigation.
- Die Zuordnung von Listeneinträgen zu Produkten erfolgt über Text; ein Eintrag ohne passendes Katalogprodukt wird als „nicht verfügbar“ angezeigt.
- Pfand, Mindestbestellmengen, Kundenkarten-/App-Rabatte und Mengenrabatte („2 für 1“) werden nicht modelliert.

### Datenimport (JSON)

Unter *Preise → + → Preise importieren (JSON)*. Alle Felder entsprechen den Swift-Modellen; `brands` und `products` sind optional. Einträge mit gleicher `id` werden ersetzt.

```json
{
  "brands": [
    { "id": "brand-ja", "name": "Ja!", "privateLabelOf": "rewe" }
  ],
  "products": [
    {
      "id": "butter-ja", "name": "Ja! Deutsche Markenbutter", "genericName": "Butter",
      "brandID": "brand-ja", "packageSize": { "value": 250, "unit": "g" },
      "isOrganic": false, "ingredients": ["Sahne"], "keywords": [], "category": "Milchprodukte"
    }
  ],
  "prices": [
    {
      "id": "rewe-butter-2026-10", "productID": "butter-ja", "storeID": "store-rewe-mitte",
      "price": { "cents": 219 }, "kind": { "regular": {} },
      "availability": "available", "source": "imported", "observedAt": "2026-10-12T08:00:00Z"
    },
    {
      "id": "rewe-butter-aktion-kw42", "productID": "butter-ja", "storeID": "store-rewe-mitte",
      "price": { "cents": 179 },
      "kind": { "offer": { "validFrom": "2026-10-12T00:00:00Z", "validUntil": "2026-10-17T00:00:00Z" } },
      "availability": "available", "source": "imported", "observedAt": "2026-10-12T08:00:00Z"
    }
  ]
}
```

Werte: `unit` ∈ `g, kg, ml, l, Stk.` · `availability` ∈ `available, limited, unavailable` · `source` ∈ `manualEntry, imported, estimate` · `privateLabelOf` ∈ `rewe, edeka, aldi, lidl, kaufland, netto, penny, marktkauf, globus, other`.

---

## Beispielrechnung (manuell geprüft)

Liste **„Wocheneinkauf“** aus den Beispieldaten, alle vier Läden aktiv, **max. 2 Läden**, Stichtag = Tag des ersten Starts. Abgesichert durch `SampleScenarioTests`.

**Kosten je Position und Laden** (bereits mit Vorgaben, Mengen und gültigen Angeboten):

| Eintrag | Vorgabe | REWE | Aldi | Lidl | EDEKA |
|---|---|---:|---:|---:|---:|
| 2 × Laktosefreie Milch (1 l) | Marke MinusL | 3,38 | – | – | 2,58 ¹ |
| Butter | – | 2,19 ² | 2,09 | 2,09 | 2,15 |
| 2 × Spaghetti | Marke Barilla | 3,98 | – | 2,58 ³ | n. v. ⁴ |
| Kaffee | – | 4,49 | 4,29 | 4,29 | 4,39 |
| Bananen (1 kg) | Bio bevorzugt | 2,29 | 1,99 | – ⁵ | – ⁵ |
| Haferflocken | Eigenmarke bevorzugt | 0,79 | 0,99 | 0,75 | 0,79 |
| Eier | – | 2,79 | 2,49 | 2,49 | 2,69 |
| Hafermilch Barista | – | nicht im Katalog | | | |

¹ Angebot 1,29 € statt 1,65 € · ² Ja! 2,19 €; das abgelaufene Ja!-Angebot (1,79 €) wird ignoriert, das Kerrygold-Angebot (2,22 €) ist teurer · ³ Angebot 1,29 € statt 1,79 €, **läuft am Folgetag ab** · ⁴ als „nicht verfügbar“ markiert · ⁵ es gibt Bio-Bananen (REWE, Aldi), daher werden nur Bio-Varianten verglichen

**Ladenpaare** (müssen Milch MinusL, Barilla und Bio-Bananen abdecken):

| Kombination | Summe |
|---|---:|
| **REWE + Lidl** | **17,87 €** |
| REWE + EDEKA | 18,87 € |
| REWE + Aldi | 19,01 € |
| Aldi + Lidl / Aldi + EDEKA / Lidl + EDEKA | deckt nicht alle 7 Produkte ab |
| nur REWE (beste Ein-Laden-Lösung, einziger Laden mit allem) | 19,91 € |

**Erwartete Empfehlung:**

1. **REWE Musterstadt Mitte** (1,6 km) – MinusL Milch 2 × 1,69 € = 3,38 € · REWE Bio Bananen 2,29 € → **5,67 €**
2. **Lidl Musterstadt Süd** – Milbona Butter 2,09 € · Barilla Spaghetti 2 × 1,29 € (Aktion) = 2,58 € · Bellarom Kaffee 4,29 € · Crownfield Haferflocken 0,75 € · Freilandeier 2,49 € → **12,20 €**

**Gesamt 17,87 €, Ersparnis 2,04 €** gegenüber REWE allein (19,91 €). „Hafermilch Barista“ wird als nicht verfügbar gelistet; Hinweise auf das ablaufende Barilla-Angebot und die Beispieldaten erscheinen.

Weitere Modi mit derselben Liste: unbegrenzt bzw. max. 3 Läden → Aldi + Lidl + EDEKA = **16,77 €**; nur ein Laden → REWE **19,91 €**; Kompromiss (0,30 €/km) → REWE allein (kürzester Weg überwiegt die Preisdifferenz).

> Da die Beispielangebote relativ zum ersten Start datiert sind, ändert sich das Ergebnis nach einigen Tagen (z. B. wenn das Barilla-Angebot abläuft). *Läden → Beispieldaten wiederherstellen* datiert sie neu.

---

## Roadmap

- **Echte Datenquellen:** Import aus Prospekt-/Angebotsdaten, sofern rechtlich und technisch zulässig; CSV-Import; Kassenbon-Erfassung (Foto + Texterkennung) als `PriceDataSource`.
- **Bessere Zuordnung:** Barcode-Scan (EAN) für eindeutige Produkte; Synonyme („Nudeln“ ↔ „Pasta“).
- **Preis-Historie** je Produkt und Laden, Hinweis bei Preissteigerungen.
- **Echte Routen** über MapKit inkl. Fahrzeit, Startpunkt per Standort.
- **Erweiterte Preislogik:** Mengenrabatte, Pfand, Kundenkarten-Preise, Mindesthaltbarkeit.
- **iCloud-Sync / Export** der JSON-Daten zwischen Geräten; Teilen von Listen.
- **Widgets/Siri-Kurzbefehle** („Was fehlt noch bei REWE?“).
- **Android:** UI mit Jetpack Compose auf Basis des Swift Packages (Swift SDK für Android) oder einer Kotlin-Portierung der getesteten Domänenlogik.
