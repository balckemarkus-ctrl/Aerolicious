# Aero Shards in Blender + Unreal Engine 5 – Projektplan

Ziel: Die Browser-Version (Three.js) dient als Prototyp und Storyboard. Daraus entsteht
eine hochwertige Version mit **Blender** (Modelle) und **Unreal Engine 5** (Spiel, Licht, Effekte,
Trailer). Gesteuert wird beides von Claude Code über MCP-Server.

---

## 0. Die wichtigste Voraussetzung

Blender und Unreal laufen auf **deinem PC**. Ihre MCP-Server sind nur lokal erreichbar
(Socket bzw. HTTP auf `localhost`). Eine Cloud-Session wie die, in der die Web-Version entstanden ist,
kommt da nicht heran.

**Deshalb muss Claude Code lokal auf demselben PC laufen**, auf dem Blender und UE5 installiert sind.
Das geht mit der Claude-Code-CLI im Terminal oder mit dem Code-Tab der Claude-Desktop-App.
Das Repository synchronisieren wir weiter über GitHub.

---

## Teil A – Was du machen musst

### A1. Hardware prüfen

| | Minimum | Empfohlen |
| --- | --- | --- |
| Betriebssystem | Windows 10/11, 64 Bit | Windows 11 |
| Grafikkarte | 8 GB VRAM, DirectX 12 (z. B. RTX 2070) | RTX 3070 / 4070 oder besser (Lumen, Nanite) |
| Arbeitsspeicher | 16 GB | 32 GB oder mehr |
| Speicher | 150 GB frei auf SSD | 250 GB frei auf NVMe-SSD |

### A2. Software installieren

1. **Git** und **Git LFS** (für große Binärdateien wie `.blend`, `.fbx`, `.uasset`), danach einmal `git lfs install`.
2. **Claude Code** lokal installieren und anmelden.
3. **Python 3.11+** und **uv** (Paketmanager von Astral). Damit läuft der Blender-MCP-Server.
4. **Blender** in der aktuellen LTS-Version.
5. **Epic Games Launcher**, darin **Unreal Engine 5.8**, falls verfügbar.
   Ab 5.8 bringt Unreal laut Berichten ein eigenes, experimentelles MCP-Plugin mit (siehe A4).
   Bei einer älteren Version greifen wir auf ein Community-Plugin zurück.
6. **Visual Studio 2022** (Community reicht) mit der Arbeitslast **„Spieleentwicklung mit C++“** und dem
   Windows SDK. Nötig, weil die Spiellogik in C++ entsteht. Die genaue VS-Version richtet sich nach der UE-Version
   und steht in den Release Notes.
7. Optional: **ffmpeg** (Videoschnitt) und **DaVinci Resolve** (Endschnitt des Trailers, kostenlos).

### A3. Repository lokal holen

```bash
git clone https://github.com/balckemarkus-ctrl/Aerolicious.git
cd Aerolicious
git checkout ccr-5dadc334-w4erwj   # oder main, falls bis dahin gemergt
```

Den Ordner bitte **nicht** in OneDrive oder Dropbox legen. Unreal-Projekte und Sync-Dienste vertragen sich schlecht.
Gut ist zum Beispiel `C:\Projekte\Aerolicious`.

### A4. Blender-MCP einrichten

1. Add-on installieren: `uvx mcp-for-blender install-addon`
   (das Paket hieß früher `blender-mcp`, siehe README unter github.com/ahujasid/blender-mcp).
2. In Blender unter *Bearbeiten → Einstellungen → Add-ons* das Add-on **„MCP for Blender“** aktivieren.
3. Im 3D-Viewport mit `N` die Seitenleiste öffnen, Tab **BlenderMCP**, Verbindung bzw. Server starten.
4. In Claude Code registrieren (den genauen Befehl im README gegenprüfen):
   `claude mcp add blender -- uvx mcp-for-blender`
5. Test: Claude Code starten und fragen „Was ist in meiner Blender-Szene?“

Hinweis: Der Server kann beliebigen Python-Code in Blender ausführen. Vor größeren Aktionen also speichern.

### A5. Unreal-Projekt und Unreal-MCP einrichten

1. Neues Projekt anlegen: *Games → Blank*, **C++**, Desktop, Qualität „Maximum“, ohne Starter Content.
   Name **`AeroShards`**, Speicherort **`<Repo>/unreal/`**.
2. Unter *Edit → Plugins* aktivieren:
   - **Unreal MCP** (experimentell, ab 5.8). Alternativ ein Community-Server wie `GenOrca/unreal-mcp`
     oder ein kommerzieller wie StraySpark. Welcher es wird, entscheiden wir gemeinsam in Phase 0.
   - **Python Editor Script Plugin** und **Editor Scripting Utilities**
   - **Movie Render Queue** (für den Trailer)
   - Niagara und Enhanced Input sind standardmäßig aktiv.
3. Editor neu starten. Im Output Log bzw. in den Plugin-Einstellungen steht die **Adresse des MCP-Servers**.
4. In Claude Code registrieren, zum Beispiel:
   `claude mcp add --transport http unreal http://localhost:<PORT>/mcp`
   (Pfad und Port aus der Doku des gewählten Plugins).
5. Test: „Liste alle Actors im aktuellen Level auf.“

### A6. Während des Projekts

- **Blender bzw. Unreal geöffnet lassen**, während ich daran arbeite. Die MCP-Server laufen im Editor.
- **Art Direction und Feedback:** Ich zeige Screenshots und Renderings, du entscheidest über Look und Gefühl.
- **Probespielen:** Spielgefühl (Steuerung, Treffer-Feedback, Balancing) kann nur ein Mensch beurteilen.
- **Freigaben** für Tool-Aufrufe in Claude Code erteilen. Häufige, harmlose Befehle kann man dauerhaft erlauben.
- **GitHub LFS:** Das kostenlose Kontingent ist klein (etwa 1 GB). Bei vielen großen Dateien eventuell
  ein Datenpaket buchen oder Rohdaten lokal bzw. auf einem Laufwerk sichern.

---

## Teil B – Mein Plan

Jede Phase endet mit einem **Abnahme-Punkt**: Ich zeige dir Screenshots oder ein Video, du gibst
Feedback, danach wird committet.

### Phase 0 – Einrichtung prüfen (1 Session)

- Prüfen, ob beide MCP-Verbindungen antworten und welche Tools es gibt. Versionen festhalten.
- Repo-Struktur anlegen:
  ```
  art/source/      .blend-Dateien (LFS)
  art/export/      FBX/glTF für Unreal (LFS)
  unreal/AeroShards/
  web/             bisherige Three.js-Version (Prototyp und Storyboard)
  docs/
  ```
- `.gitattributes` für LFS (`*.blend`, `*.fbx`, `*.uasset`, `*.umap`, `*.wav`, `*.png` …) und
  `.gitignore` für Unreal (`Binaries/`, `Intermediate/`, `Saved/`, `DerivedDataCache/`).
- `CLAUDE.md` mit Konventionen: Einheiten (1 Block = 100 UU = 1 m), Namensschema (`SM_`, `M_`, `MI_`, `NS_`,
  `BP_`, `WBP_`), Achsen und Exporteinstellungen.
- **Abnahme:** Beide MCP-Server funktionieren, die Struktur steht.

### Phase 1 – Art Bible und Style Frames in Blender (1–2 Sessions)

- Farbpalette und Materialsprache aus der Web-Version übernehmen und verfeinern: Glas, Aqua, Limette,
  Chrom, Prisma; glänzender Klarlack, irisierende Seifenblasen, sonniger Himmel.
- Drei **Style Frames** in Blender (Eevee/Cycles): der Brocken auf der Insel, Nahaufnahme der Blöcke mit
  Scherben, der Blaster in der Ich-Perspektive.
- **Abnahme:** Du wählst die Richtung, Änderungen fließen ein.

### Phase 2 – Assets in Blender (3–5 Sessions)

| Asset | Details |
| --- | --- |
| Block | Würfel mit Fase, 100 × 100 × 100 cm, saubere UVs, LOD0/LOD1. Farben später per Material-Instanz in Unreal |
| Scherben | 4 Low-Poly-Varianten |
| Bubble-Blaster | Ich-Perspektive, etwa 5–8 k Dreiecke, Tank und Düse als einzelne Teile für Animation |
| Recycler, Shop-Kiosk | Mit Trichter, Leuchtring, Bildschirm |
| Aero-Drohne | Rumpf und rotierender Ring als getrennte Teile |
| Vegetation | 3 Baumvarianten, Büsche, Blumen im Bubble-Stil |
| Umgebung | Inselrand, Steine, ferne Hügelinseln |

- Modellieren größtenteils prozedural per Python über den MCP (reproduzierbar, leicht änderbar).
  Kontrolle über Viewport-Screenshots.
- Ein Export-Skript erzeugt alle FBX-Dateien einheitlich (Maßstab, Achsen, Pivot am Boden).
- **Abnahme:** Turntable-Renderings aller Assets.

### Phase 3 – Unreal-Grundgerüst und Spiellogik in C++ (4–6 Sessions)

Code schreibe ich direkt als Dateien und baue ihn über Visual Studio bzw. Live Coding. Das ist deutlich
robuster, als Blueprint-Graphen per MCP zu „klicken“. Den MCP nutze ich für alles im Editor:
Assets importieren, Materialien, Level, Niagara, UMG, Sequencer.

| Klasse | Aufgabe (portiert aus der Web-Version) |
| --- | --- |
| `AAeroCharacter` | Ich-Perspektive, Enhanced Input, Springen, Sprinten |
| `UAeroWeaponComponent` | 4 Munitionsarten, datengetrieben über DataAssets |
| `AAeroChunk` | Erzeugt deterministisch 3.757 Blöcke in 5 Stufen. Rendering mit einer `InstancedStaticMeshComponent` pro Stufe, nur freiliegende Blöcke (wie im Web). Voxel-Raycast |
| `AAeroShardManager` | Scherben-Pool, Physik, Magnet, Einsammeln |
| `AAeroRecycler`, `AAeroShop` | Interaktion mit `E`, Credits, Upgrades |
| `AAeroDrone` | Kreisen und automatisches Schießen |
| `UAeroSaveGame` | Speicherstand |
| DataTables | Stufen, Upgrades, Balancing aus `config.js` übernommen |

- **Abnahme:** Spielbarer Graybox-Durchlauf vom ersten Schuss bis zum letzten Block.

### Phase 4 – Level, Licht und Look (2–3 Sessions)

- Insel (Landscape oder Mesh), Wasser, Sky Atmosphere, Volumetric Clouds, Directional Light und Sky Light, Lumen.
- Master-Material `M_AeroGloss` (Clear Coat, Fresnel, Irisieren) mit Instanzen pro Stufe.
- Niagara: Bruch-Funken, Seifenblasen, Explosionsringe, Strahl, Drohnen-Laser.
- Post Process: weiches Bloom, leichte Sättigung, sonniger Aero-Look.
- **Abnahme:** Screenshots aus Spielerperspektive und Kameraflug.

### Phase 5 – UI, Sound und Feinschliff (2–3 Sessions)

- UMG im Glas-Stil: Fortschrittsbalken, Rucksack, Credits, Munitionsleiste, Shop, Pause, Siegbildschirm.
- **MetaSounds**: Die synthetisierten Klänge der Web-Version (Pop, Glocken, Recycling-Arpeggio,
  Ambient-Akkorde) nachbauen, ganz ohne fremde Audiodateien.
- Spielgefühl: Treffer-Feedback, leichte Kamera-Erschütterung, Magnet-Kurve, Balancing.
- **Abnahme:** Du spielst einmal komplett durch (etwa eine Stunde) und gibst Feedback.

### Phase 6 – Trailer in Unreal (2–3 Sessions)

- Storyboard aus dem Web-Trailer übernehmen: Intro-Flug, „3.757 Blöcke“, Zerschießen, Sammeln,
  Recyceln, Upgraden, Munition, Finale, Endkarte.
- **Level Sequences** mit Cine-Kameras und Kamerafahrten. Spielszenen über einen deterministischen
  Trailer-Modus, wie im Web, oder per Take Recorder aufgenommen.
- **Movie Render Queue**: 1080p oder 4K, 60 fps, Anti-Aliasing mit mehreren Samples, Ausgabe als
  Bildsequenz oder ProRes.
- Titel-Einblendungen per UMG im Sequencer. Endschnitt und Ton mit ffmpeg oder DaVinci Resolve.
- **Abnahme:** Trailer in 1080p/4K.

### Phase 7 – Fertiger Build (1 Session)

- Windows-Shipping-Build packen, testen, als ZIP bereitstellen.

**Grobe Gesamtschätzung:** etwa 16–25 Arbeits-Sessions, abhängig von Feedback-Runden und Detailgrad.

---

## Risiken und Grenzen

- **Die MCP-Server sind jung bzw. experimentell.** Einzelne Tools können fehlen oder sich zwischen Versionen ändern.
  Notfalls weiche ich auf Python-Skripte im Editor oder auf C++ aus.
- **Ich sehe nur, was die Tools zeigen.** Screenshots von dir helfen, besonders beim Spielgefühl.
- **Wartezeiten:** Shader-Kompilierung, C++-Builds und Renderings dauern auf deinem PC teils viele Minuten.
- **Rechtliches:** Eigener Name, eigene Modelle, eigene Sounds. Keine Inhalte aus dem Original-Spiel übernehmen.
