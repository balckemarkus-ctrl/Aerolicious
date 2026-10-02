# Wonder Wreckers (Godot + Blender) – Projektplan

Ziel: Die Browser-Version (Three.js, `src/`) dient als Prototyp und Vorlage. Daraus entsteht eine
native Version mit **Godot 4.7** (Spiel) und **Blender 5.2** (Modelle), zuerst für **Android**,
später auch für Desktop.

Warum der Wechsel: Auf dem Pixel 10 Pro (PowerVR-Grafik) stürzt der Grafiktreiber mit WebGL in der
Android-WebView ab. Godot nutzt auf Android **Vulkan** (Renderer „Mobile“) und läuft nativ, also
schneller, sparsamer und ohne die WebView dazwischen.

## Eigenständigkeit

Wonder Wreckers (früher Arbeitstitel „Aero Shards“) ist ein eigenes Spiel. Allgemeine Spielidee (Blöcke zerschießen, sammeln, aufrüsten) und ein
sonniger Wiesen-Look sind frei; alles Kennzeichnende ist eigenständig:

- **Sci-Fi-Industriehalle** mit Neon statt Wiese.
- **17 Bauwerke** nacheinander: Grundformen und Wahrzeichen (Stonehenge, Brandenburger Tor, Schiefer Turm,
  Kolosseum, Big Ben, Chichén Itzá, Atomium, Pagode, Taj Mahal, Chinesische Mauer, Kölner Dom, Eiffelturm;
  zusammen 56.955 Blöcke),
  jedes mit eigener Blockzahl und exponentiell steigender Härte (`Config.LEVELS`, Form in `Chunk.shape_cells`).
- **Splitter-Konverter** statt Recycling: Splitter werden gegen **Perlen** getauscht.
- Blockarten: **Panzerblöcke** (gestreift), **Goldblöcke** (Perlen-Regen), **Explosivblöcke** (Kettenreaktion),
  **Kristallblöcke** (dreifache Splitter).
- **Incremental:** 23 Upgrades mit bis zu 200 Stufen in drei Bereichen, Meilensteine (×2 alle 25 Stufen),
  Kauf ×1/×10/Max, **Kerne** (dauerhaft +10 % je Kern) aus geschafften Bauwerken und **Reaktor-Neustart**.
- Feuern auf dem Handy: solange der rechte Daumen zielt; **Auto-Zielsystem** als frühes Upgrade.
- Eigene Modelle (Blender-Skripte), eigene Klänge (`tools/sounds`), eigener Blasen-Blaster und Glas-Oberfläche.
- Kein fremder Name, keine fremden Grafiken, Texte oder Logos.

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
`blender/out/` (nicht im Git, jederzeit neu erzeugbar).

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

### Phase 6 – Ausbau (Wünsche)
- Erfolge ✅ (30 Stück, je +1 % Schaden und Perlen; `godot/scripts/achievements.gd`)
- Mehrere Spielstände
- Mehr Waffen
- Skins (Blaster, Blöcke, Halle)

### Später
- Desktop-Builds (macOS), neuer Trailer
