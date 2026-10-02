# Android-App bauen und testen

## Einmalig einrichten

- Android Studio mit Android SDK (Standard-Ort `~/Library/Android/sdk`)
- Java 21, z. B. `brew install openjdk@21`. Das in Android Studio eingebaute Java 25 ist für Gradle 8.14 zu neu.
- In `~/.zshrc`:

  ```bash
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
  ```

- In Android Studio: *Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK* auf diese Java-21-Installation stellen.

## Nach jeder Änderung am Spiel

```bash
npm run android:sync     # baut dist/ und kopiert es in android/
```

Dann in Android Studio auf ▶ (Run) drücken. Oder ohne Android Studio:

```bash
cd android && ./gradlew installDebug   # installiert auf dem angeschlossenen Handy/Emulator
```

## Was die App anders macht als die Browser-Version

- `android/app/src/main/AndroidManifest.xml`: Querformat (`sensorLandscape`)
- `android/app/src/main/java/de/balcke/aeroshards/MainActivity.java`: Vollbild (Status- und Navigationsleiste ausgeblendet)
- `src/main.js`: Android-Zurück-Taste schließt den Shop bzw. pausiert; im Menü wird die App minimiert
- `src/touch.js`: Touch-Steuerung und Grafik-Sparmodus (wird auf Touch-Geräten automatisch aktiv)
