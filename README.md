# Aero Shards

Ein entspannter 3D-Block-Breaker im Frutiger-Aero-Stil für den Browser – eine eigene Umsetzung
des Spielprinzips „Brocken zerschießen → Scherben sammeln → recyceln → upgraden“.
Code, 3D-Modelle und Sounds sind komplett selbst erstellt (Three.js, prozedurale Geometrie, WebAudio-Synth).

## Starten

```bash
npm install
npm run dev      # Entwicklungsserver, dann http://localhost:5173 öffnen
npm run build    # Produktions-Build nach dist/
npm run preview  # Build lokal ansehen
```

## Spielprinzip

- Auf der Insel steht ein Brocken aus **3.757 Blöcken** in fünf Stufen (außen → innen):
  Glas, Aqua, Limette, Chrom, Prisma. Innere Stufen halten mehr aus und geben wertvollere Scherben.
- Zerbrochene Blöcke hinterlassen **Scherben**. Sie fliegen in deinen Rucksack, sobald du nah genug bist.
- Am **Recycler** (grün) tauschst du Scherben gegen Credits, am **Shop** kaufst du Upgrades:
  Schaden, Feuerrate, Magnet, Rucksack, Lauftempo, Recycling-Bonus, Drohnen, Fern-Recycling.
- Neue Munition: **Fizz-Granate** (Flächenschaden), **Prisma-Strahl** (durchdringender Dauerstrahl),
  **Aero-Nova** (riesige Explosion).
- Ziel: Den kompletten Brocken abtragen. Der Fortschritt wird automatisch im Browser gespeichert.

## Steuerung

| Taste | Aktion |
| --- | --- |
| W A S D / Pfeiltasten | Laufen |
| Shift | Rennen |
| Leertaste | Springen (man kann auf den Brocken klettern) |
| Maus / Linksklick | Zielen / Schießen (gedrückt halten) |
| 1–4 / Mausrad | Munition wechseln |
| E | Recyceln / Shop öffnen und schließen |
| M | Ton an/aus |
| Esc | Pause |

## Aufbau

| Datei | Inhalt |
| --- | --- |
| `src/config.js` | Block-Stufen, Munition, Upgrades und Balancing |
| `src/chunk.js` | Voxel-Brocken: Generierung, Voxel-Raycast, Schaden, nur sichtbare Blöcke werden gerendert |
| `src/shards.js` | Scherben-Physik und Magnet-Einsammeln |
| `src/world.js` | Himmel, Insel, Wasser, Bäume, Wolken, Seifenblasen, Recycler und Shop |
| `src/player.js` | Ego-Steuerung mit Voxel-Kollision |
| `src/effects.js` | Projektile, Strahl, Funken, Explosionsringe, Drohnen-Laser |
| `src/audio.js` | Synthetisierte Soundeffekte und Ambient-Akkorde |
| `src/main.js` | Spielschleife, Waffen, Drohnen, HUD, Shop, Speichern |

## Trailer

`media/trailer.mp4` (48 s, 1280×720) wird im Trailer-Modus (`index.html?trailer`) Bild für Bild gerendert.
Neu erzeugen: `tools/trailer/make.sh` (benötigt Node, Python 3, ffmpeg und Playwright mit Chromium).
