# Fix: Mitarbeiter hinzufügen + Rückgabe per Kennnummer

Diese Version behebt zwei Probleme:
- Host kann Mitarbeiter zuverlässig hinzufügen.
- Rückgabe prüft die 4-stellige Kennnummer des Vorgangs und funktioniert auch bei älteren Ausgaben, bei denen employee_id noch leer ist.

WICHTIG:
1. In Supabase SQL Editor den kompletten Inhalt der mitgelieferten schema.sql ausführen.
2. Danach die neue index.html auf der Webseite einsetzen.
3. Seite hart neu laden (Strg+F5).
