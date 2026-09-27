# Werkzeugverwaltung – finale Version

## Enthalten
- `index.html` – komplette Web-App
- `schema.sql` – Supabase-Datenbank + RLS + sichere Funktionen
- `manifest.webmanifest` – PWA
- `sw.js` – Service Worker

## Rollen
### Hosts
- Florian@marcoreiss.de
- Brian@marcoreiss.de
- Büro@marcoreiss.de
- bauerhin.b@gmail.com

Optional zusätzlich kompatibel: `buero@marcoreiss.de`.

Hosts sehen und verwalten alles.

### Mitarbeiter
Gemeinsames Login-Konto: `mitarbeiter@marcoreiss.de`

Jeder Mitarbeiter hat eine eigene 4-stellige Kennnummer. Die Kennnummern anderer Mitarbeiter werden in der Mitarbeiteransicht nicht angezeigt. In „Offene Ausgaben“ wird bei Mitarbeitern keine Kennnummer ausgegeben.

## Host-Funktionen
- Werkzeuge registrieren, löschen und in Reparatur setzen
- Mitarbeiter anlegen, deaktivieren, aktivieren und löschen
- Kennnummern einsehen
- Offene Ausgaben vollständig sehen
- Verlauf der letzten 3 Monate anzeigen
- 3-Monats-Verlauf als PDF herunterladen
- QR-Codes drucken (3 × 3 cm)

## Mitarbeiter-Funktionen
- verfügbare Werkzeuge sehen
- Werkzeug auswählen und mit eigener Kennnummer ausgeben
- eigenes Werkzeug mit Kennnummer zurückgeben und Bemerkung hinterlassen
- offene Ausgaben sehen, aber ohne Kennnummern

## Supabase
Das `index.html` ist bereits mit der bisher verwendeten Supabase-URL und dem Publishable Key konfiguriert.

Wichtig: `schema.sql` einmal vollständig im Supabase SQL Editor ausführen. Danach müssen die vier Host-Konten und das gemeinsame Mitarbeiter-Konto in Supabase Authentication als Benutzer existieren.

Service-Role-Keys gehören niemals in `index.html`.

## GitHub Pages
Alle Dateien aus diesem Ordner in dein Repository kopieren und GitHub Pages auf diesen Ordner veröffentlichen.
