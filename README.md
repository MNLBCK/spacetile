# SpaceTile 🚀

Intelligenter On-Demand Fenster-Optimierer für macOS mit Kontext-Erkennung, KI-Space-Gedächtnis und nativer Einstellungs-GUI.

![SpaceTile App Icon](assets/AppIcon.png)

---

## Highlights

* ⚡ **Hyper-Key Steuerung:**
  * **`Hyper + Leertaste`** (`⌃⌥⇧⌘ + Space`): Optimiert den aktuellen Space sofort nach Kontext.
  * **`Hyper + S`** (`⌃⌥⇧⌘ + S`): Öffnet die native SwiftUI-Einstellungs-GUI.
* 🛡️ **Intelligente App-Gewichte & Limits (Smart Weights):**
  * **Terminal-Schutz auf 4K/Ultra-Wide:** Verhindert, dass ein Terminal auf 3840px unbrauchbare 2380px (62%) breit gezogen wird. Begrenzt Terminals automatisch auf z. B. max. 1150px (oder 34%), während Browser/IDE den Rest bekommen.
  * **Side-by-Side (50/50 Lese-Modus):** Öffnest du Browser + Notizen (Obsidian, Notes, Bear), schaltet SpaceTile automatisch auf eine 50/50-Teilung.
  * **Schnellwechsel (Cycle Ratios):** Zweimaliges schnelles Drücken wechselt zwischen 62% Fokus, 50/50 Split und 75% Fokus.
* 🧠 **Space-Gedächtnis & Beobachtungsmodus (KI/Heuristik):**
  * Beobachtet im Hintergrund dezent deine bevorzugten Fenstergrößen pro Space und merkt sich, wie du bestimmte App-Paare (z. B. Chrome + iTerm2) am liebsten anordnest.
  * Mit `spacetile learn` oder über die GUI kannst du ein aktuelles Fensterlayout für den Space auch sofort dauerhaft einprägen.
* 🖥️ **Native SwiftUI GUI:**
  * Bequeme Konfiguration von Tastenkürzeln, Rändern, Terminal-Breiten und Anzeige der gelernten Space-Profile.

---

## Befehle

| Befehl | Beschreibung |
|---|---|
| `spacetile` / `spacetile optimize` | Optimiert den aktuellen Space sofort |
| `spacetile gui` | Öffnet das Einstellungsfenster |
| `spacetile learn` | Prägt das aktuelle Fensterlayout für das App-Set im Space-Gedächtnis ein |
| `spacetile daemon` | Startet den Daemon im Vordergrund |
| `spacetile install` | Installiert/Aktualisiert den Hintergrunddienst (LaunchAgent) |
| `spacetile uninstall` | Entfernt den Hintergrunddienst |
| `spacetile status` | Prüft, ob der Hintergrunddienst aktiv ist |
| `spacetile config` | Gibt die aktuelle JSON-Konfiguration aus |

---

## Konfiguration

Liegt unter `~/.config/spacetile/config.json`. Kann direkt in der Datei oder über die GUI (**`Hyper + S`**) bearbeitet werden.
