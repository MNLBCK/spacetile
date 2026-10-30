# SpaceTile 🚀

Intelligenter On-Demand Fenster-Optimierer für macOS. 

Ersetzt starre Tiling-Manager wie Amethyst durch ein **intelligentes, manuell ausgelöstes Layout**: Du arbeitest ganz normal und drückst bei Bedarf **einen einzigen Shortcut** – alle Fenster deines aktuellen macOS-Spaces ordnen sich sofort optimal an.

---

## Highlights

* 🎯 **Fokus-basiertes Layout (Master-Stack):** Das aktive Fenster wird automatisch zum Hauptfenster (Master, z. B. 62% Breite links). Alle anderen Fenster teilen sich die rechte Seite gleichmäßig.
* ⚡ **1-Shortcut-Bedienung:** Kein Dutzend verschiedener Tastaturkombinationen. Ein einziger Shortcut erledigt alles.
* 🔄 **Schnellwechsel (Cycle Ratios):** Drückst du den Shortcut innerhalb von 2 Sekunden nochmals, wechselt das Verhältnis flüssig durch: **62% Master ➔ 50/50 Split ➔ 75% Fokus**.
* 🧼 **Saubere Filterung:** Ignoriert automatisch System-Popups, Paletten, Vorssaint-Overlays und konfigurierbare Apps (z. B. Einstellungen, Rechner).
* ⚙️ **Hintergrund-Daemon & CLI:** Läuft entweder dauerhaft als unscheinbarer LaunchAgent im Hintergrund oder kann direkt per CLI (`spacetile optimize`), Raycast oder Vorssaint-Aktion aufgerufen werden.

---

## Befehle

| Befehl | Beschreibung |
|---|---|
| `spacetile` / `spacetile optimize` | Optimiert den aktuellen Space sofort einmalig |
| `spacetile daemon` | Startet den Daemon im Vordergrund (zum Testen/Debuggen) |
| `spacetile install` | Richtet den dauerhaften Hintergrund-Dienst ein (LaunchAgent) |
| `spacetile uninstall` | Entfernt den Hintergrund-Dienst |
| `spacetile status` | Prüft, ob der Hintergrund-Dienst aktiv ist |
| `spacetile config` | Zeigt Pfad und Inhalt der JSON-Konfiguration |

---

## Standard-Shortcut

```text
⌃ + ⌥ + ⌘ + Leertaste  (Control + Option + Command + Space)
```

---

## Konfiguration

Die Einstellungen liegen unter:
`~/.config/spacetile/config.json`

Beispiel:
```json
{
  "shortcut": {
    "modifiers": ["command", "option", "control"],
    "key": "space"
  },
  "masterRatio": 0.62,
  "cycleRatios": [0.62, 0.50, 0.75],
  "gap": 10,
  "margin": 12,
  "singleWindowMode": "centered",
  "ignoredApps": [
    "Vorssaint",
    "System Settings",
    "Systemeinstellungen",
    "Calculator",
    "Rechner",
    "1Password"
  ]
}
```

Nach dem Bearbeiten der Konfigurationsdatei einfach kurz den Dienst neu laden:
```bash
spacetile install
```
