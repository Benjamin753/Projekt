# Baustein 5 – Upgrade-Shop

Freigegebener Umfang: eigener Shop zwischen Kugeln, Pins einzeln auswählen und verbessern, mehrstufige Kugel- und Flipper-Upgrades. Aktuelle Balance: drei Pin-Level; normale Pins geben 50/75/100 Punkte, Golden Pins 100/150/200. Pin-Upgrades kosten 300/500 bzw. 400/600; Ausrüstung kostet 250/450/700 und hat drei Ausbaustufen. Bis zu drei zufällige Ausrüstungsangebote pro Besuch. Kein automatischer Abschuss.

Umsetzung: editierbare Godot-Control-Szene mit den Kategorien Pins/Kugel/Flipper, einer Pin-Auswahl nach Tischposition, Vorschau der aktuellen und nächsten Wirkung, Kaufknopf, Guthaben und Rückkehr zur Feder. Nicht verfügbare Angebote und fehlendes Guthaben werden erklärt. Nach der letzten Kugel zeigt dieselbe Oberfläche das Run-Ergebnis. Upgrades gelten weiterhin nur innerhalb des Runs.

Prüfung: echte UI-Klicks für Auswahl/Kauf/Kategorien, einzelne Pin-Level, Preisgrenzen, unveränderter Score, Angebotsbindung, neue Kugel, Run-Ende und Zurücksetzen; bestehende Physik- und Punktetests; visuelle Kontrolle der drei Kategorien und des Endbildschirms.

Status: abgeschlossen.

Verifiziert mit Godot 4.7.2, 120 Physikschritten/s: `tests/shop_test.gd`, `tests/run_test.gd`, `tests/ball_physics_test.gd`, `tests/bounce_test.gd`, `tests/scoring_test.gd` erfolgreich. Neue Shop-Auswahl zunächst ohne Umsetzung fehlgeschlagen, anschließend grün. Maus-Klicks und über Godots Input-System eingespeiste Touch-Eingaben geprüft; kein Test auf einem physischen Handy. Drei Kategorien und Run-Ende gerendert und visuell geprüft. Code-Review ohne kritische oder wichtige Befunde; Ballrettungs-Ziele im Shop konkret benannt.

Umgebung: Die grafische Vorschau funktioniert, Godot kann in dieser Umgebung jedoch seinen Shader-Cache im Benutzerverzeichnis nicht anlegen. Das beeinflusst den Shop-Test nicht.


## Pin-Skins und Balance (14.11.2026)

Die Nutzervorlage wird unverändert als Texturatlas verwendet. Blau/Golden: oben links und unten Mitte; Gelb: oben rechts; Grün: oben Mitte. Die untere Mitte wurde von y=590 auf y=550 verschoben. Drei Level je Pin, dargestellt als Kreis/Raute/Stern. Punkte stehen in der Vorlage, Level zusätzlich unter dem Pin. Kein früherer Level-4-Jackpot mehr; Turbo und ×2 wirken weiterhin auf die neuen Basiswerte. Normale Pins behalten ihren bisherigen stärkeren Rückstoß nach Upgrades.

Zusätzlicher Test: `tests/pin_balance_test.gd` prüft alle vier Pins auf allen drei Leveln, Preise, Levelgrenze, Skin-Auswahl, Position und Zurücksetzen. Originalbild und Assetkopie haben identische SHA-256-Prüfsummen.
