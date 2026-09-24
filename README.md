# Werkzeugverwaltung – kostenlose Variante

## Architektur
- Frontend: statische Web-App
- Datenbank/Benutzer: Supabase Free
- QR-Codes: QR-Code enthält die Web-App-Adresse plus `?tool=W-0001`
- Android und PC: Browser / installierbare PWA
- Keine Kreditkarte im Projekt erforderlich

## 1. Supabase einrichten
1. Kostenloses Konto bei Supabase erstellen.
2. Neues Projekt erstellen.
3. SQL Editor öffnen.
4. Inhalt von `schema.sql` komplett ausführen.
5. Unter Project Settings → API die **Project URL** und den **anon/public key** kopieren.
6. In `index.html` diese beiden Werte bei `CONFIG` eintragen:
   - `YOUR_SUPABASE_URL`
   - `YOUR_SUPABASE_ANON_KEY`

## 2. Mitarbeiter
In Supabase unter Authentication → Users können die 35 Mitarbeiter als Benutzer angelegt werden.
Jeder bekommt seine eigene E-Mail-Adresse und ein Passwort.
Für die erste Version wird die Anmeldung über E-Mail + Passwort verwendet.

## 3. Kostenlos online stellen
Die Dateien `index.html`, `manifest.webmanifest` und `sw.js` können auf einem kostenlosen statischen Hosting veröffentlicht werden, z.B. GitHub Pages.
Wichtig: Die fertige URL muss eine feste HTTPS-Adresse sein.

Beispiel:
https://DEINNAME.github.io/werkzeugverwaltung/

Dann erzeugt die App QR-Codes mit genau dieser Adresse.

## 4. QR-Ablauf
Werkzeug registrieren → QR-Code erzeugen → QR-Code drucken → Mitarbeiter scannt QR-Code → Browser öffnet die App mit `?tool=W-0001` → Werkzeugnummer wird automatisch übernommen.

## Sicherheit
Der Supabase anon key darf im Browser verwendet werden, sofern RLS korrekt eingerichtet ist. Niemals einen Service-Role-Key in `index.html` eintragen.

## Hinweis zum Free-Tier
Kostenlose Cloud-Dienste können ihre Limits und Bedingungen ändern. Für 35 Mitarbeiter ist die technische Nutzung klein, aber die jeweiligen aktuellen Anbieterbedingungen sollten vor dem produktiven Einsatz geprüft werden.
