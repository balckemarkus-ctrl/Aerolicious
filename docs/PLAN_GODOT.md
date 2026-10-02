# Aero Shards in Godot + Blender – Projektplan

Ziel: Die Browser-Version (Three.js, `src/`) dient als Prototyp und Vorlage. Daraus entsteht eine
native Version mit **Godot 4.7** (Spiel) und **Blender 5.2** (Modelle), zuerst für **Android**,
später auch für Desktop.

Warum der Wechsel: Auf dem Pixel 10 Pro (PowerVR-Grafik) stürzt der Grafiktreiber mit WebGL in der
Android-WebView ab. Godot nutzt auf Android **Vulkan** (Renderer „Mobile“) und läuft nativ, also
schneller, sparsamer und ohne die WebView dazwischen.

## Ordner

| Ordner | Inhalt |
| --- | --- |
| `src/`, `android/` | Web-Version und Capacitor-App (Prototyp, bleibt erhalten) |
| `godot/` | Godot-Projekt (öffnen mit Godot → *Import* → `godot/project.godot`) |
| `blender/` | Ein Python-Skript pro Modell, erzeugt `.blend` und `.glb` |
| `godot/assets/models/` | Exportierte Modelle (`.glb`), werden von Godot automatisch importiert |

## Werkzeuge (auf dem Mac installiert)

- Godot 4.7.2 (`brew install --cask godot`) mit Export-Vorlagen
- Blender 5.2.2 LTS
- Android SDK (aus Android Studio), Java 17 (`brew install openjdk@17`) für den Godot-Android-Export
- Claude Code steuert Blender im Hintergrund (`blender -b -P skript.py`) und Godot über die
  Kommandozeile (Import, Export, Installation aufs Handy per `adb`).

## Phasen

### Phase 0 – Grundlagen und Härtetest ✅
- Godot-Projekt mit Renderer **Mobile**, Querformat, Vollbild (immersive).
- Härtetest-Szene: ca. 3.700 glänzende Blöcke (MultiMesh), Schatten, Himmel. Läuft sie auf dem
  Pixel 10 Pro flüssig und stabil, geht es weiter.

### Phase 1 – Modelle in Blender ✅ (erste Fassung)
Stil: Frutiger Aero, also glänzend, weiche Rundungen, Glas, Wasser, frisches Grün und Himmelblau.
- Block (abgerundeter Würfel, eine Variante je Stufe über Material), Scherbe
- Blaster (Ego-Ansicht), Drohne
- Recycler und Shop-Station, Bäume, Hügel, Wolken, Seifenblasen
- Insel mit Weg und Ufer
Jedes Modell ist ein Skript in `blender/`, `blender/build_all.sh` exportiert alles nach `godot/assets/models/`
(einzelne Modelle: `./blender/build_all.sh shop blaster`). Die `.blend`-Dateien und Vorschaubilder landen in
`blender/out/` (nicht im Git, jederzeit neu erzeugbar). Die Szene `godot/gallery.tscn` zeigt alle Modelle in der Welt.

### Phase 2 – Spielkern in Godot ✅ (erste Fassung, Skripte in `godot/scripts/`)
- Brocken: Voxel-Gitter mit 3.757 Blöcken in 5 Stufen, Darstellung per MultiMesh je Stufe,
  nur sichtbare Blöcke, Voxel-Raycast (wie `src/chunk.js`)
- Spieler: Ego-Steuerung mit Voxel-Kollision, Springen, Rennen
- Steuerung: Desktop (Maus/Tastatur) und Touch (Stick links, Wischen rechts, Auto-Feuer,
  Knöpfe für Springen, Aktion, Pause), Android-Zurück-Taste

### Phase 3 – Spielablauf ✅ (erste Fassung)
- Munition: Blase, Fizz-Granate, Prisma-Strahl, Aero-Nova
- Scherben mit Magnet, Rucksack, Recycler, Shop mit allen Upgrades, Drohnen, Fern-Recycling
- Balancing aus `src/config.js` übernehmen, Speichern unter `user://`

### Phase 4 – Oberfläche, Effekte, Ton ✅ (erste Fassung; Sounds: `tools/sounds/make_sounds.py`)
- HUD und Menüs im Glas-Stil (Godot-Theme), Partikel, Explosionsringe, Strahl
- Sounds (aus der WebAudio-Synthese als Samples nachgebaut), Ambient-Musik

### Phase 5 – Android-Feinschliff
- Grafikstufen (Schatten, Auflösung), App-Icon, Startbild
- Test auf dem Pixel 10 Pro und im Emulator, später signierter Release-Build für den Play Store

### Später
- Desktop-Builds (macOS), neuer Trailer
