# Résolution de l'erreur de build : FileSystemException

## 🔴 Problème

Lors du build de l'application avec `flutter build apk --release`, vous rencontrez l'erreur :

```
ERROR: R8: java.nio.file.FileSystemException: 
C:\Users\simplon\Documents\Developement Web\thico\podium_app\build\app\intermediates\dex\release\minifyReleaseWithR8\classes.dex: 
Le processus ne peut pas accéder au fichier car ce fichier est utilisé par un autre processus
```

## 🔍 Cause

Cette erreur se produit lorsque :
1. Un processus Java/Gradle est encore en cours d'exécution
2. Un antivirus scanne les fichiers pendant le build
3. Un IDE ou un autre outil a verrouillé les fichiers
4. Un build précédent n'a pas été terminé proprement

## ✅ Solutions

### Solution 1 : Nettoyer et relancer (Recommandé)

```powershell
# 1. Arrêter tous les processus Java
taskkill /F /IM java.exe

# 2. Nettoyer le build Flutter
flutter clean

# 3. Récupérer les dépendances
flutter pub get

# 4. Relancer le build
flutter build apk --release
```

### Solution 2 : Supprimer manuellement le dossier build

Si la solution 1 ne fonctionne pas :

```powershell
# 1. Arrêter tous les processus Java/Gradle
taskkill /F /IM java.exe
taskkill /F /IM gradle.exe

# 2. Supprimer le dossier build manuellement
Remove-Item -Recurse -Force "build"

# 3. Nettoyer Flutter
flutter clean

# 4. Relancer le build
flutter pub get
flutter build apk --release
```

### Solution 3 : Vérifier les processus en cours

```powershell
# Lister tous les processus Java/Gradle
tasklist | findstr /i "java gradle"

# Si des processus sont trouvés, les arrêter
taskkill /F /IM java.exe
taskkill /F /IM gradle.exe
```

### Solution 4 : Exclure le dossier build de l'antivirus

Si vous utilisez Windows Defender ou un autre antivirus :

1. Ouvrez les paramètres de Windows Defender
2. Ajoutez une exclusion pour le dossier :
   ```
   C:\Users\simplon\Documents\Developement Web\thico\podium_app\build
   ```

### Solution 5 : Fermer les IDE et outils

1. Fermez complètement :
   - Android Studio
   - VS Code / Cursor
   - Tous les terminaux avec des processus Flutter/Gradle
2. Attendez quelques secondes
3. Relancez le build

### Solution 6 : Redémarrer Gradle Daemon

```powershell
# Arrêter le daemon Gradle
cd android
.\gradlew --stop

# Revenir au dossier racine
cd ..

# Relancer le build
flutter build apk --release
```

### Solution 7 : Build sans minification (temporaire)

Si le problème persiste, vous pouvez désactiver temporairement la minification R8 :

1. Ouvrez `android/app/build.gradle.kts`
2. Trouvez la section `buildTypes` pour `release`
3. Ajoutez ou modifiez :

```kotlin
buildTypes {
    release {
        // ... autres configurations
        isMinifyEnabled = false  // Désactiver temporairement
        isShrinkResources = false
    }
}
```

**Note** : Cela augmentera la taille de l'APK, mais peut aider à identifier le problème.

## 🔧 Script PowerShell automatique

Créez un fichier `fix-build.ps1` dans le dossier racine :

```powershell
Write-Host "🔧 Résolution du problème de build..." -ForegroundColor Cyan

# Arrêter les processus Java/Gradle
Write-Host "⏹️  Arrêt des processus Java/Gradle..." -ForegroundColor Yellow
taskkill /F /IM java.exe 2>$null
taskkill /F /IM gradle.exe 2>$null
Start-Sleep -Seconds 2

# Nettoyer
Write-Host "🧹 Nettoyage du build..." -ForegroundColor Yellow
flutter clean

# Récupérer les dépendances
Write-Host "📦 Récupération des dépendances..." -ForegroundColor Yellow
flutter pub get

Write-Host "✅ Prêt pour le build !" -ForegroundColor Green
Write-Host "💡 Lancez maintenant: flutter build apk --release" -ForegroundColor Cyan
```

Utilisation :
```powershell
.\fix-build.ps1
```

## 📝 Vérifications supplémentaires

### Vérifier l'espace disque
```powershell
Get-PSDrive C | Select-Object Used,Free
```

### Vérifier les permissions
Assurez-vous d'avoir les droits d'écriture sur le dossier du projet.

### Vérifier la version de Java
```powershell
java -version
```

## 🚀 Build optimisé

Une fois le problème résolu, vous pouvez utiliser ces commandes pour optimiser le build :

```powershell
# Build avec split APKs (plus petit)
flutter build apk --split-per-abi

# Build avec obfuscation (production)
flutter build apk --release --obfuscate --split-debug-info=./debug-info
```

## 📞 Si le problème persiste

1. Vérifiez les logs détaillés :
   ```powershell
   flutter build apk --release --verbose
   ```

2. Vérifiez les logs Gradle :
   ```powershell
   cd android
   .\gradlew assembleRelease --stacktrace
   ```

3. Vérifiez l'espace disque disponible

4. Redémarrez votre ordinateur (solution de dernier recours)

## ✅ Checklist de résolution

- [ ] Processus Java/Gradle arrêtés
- [ ] Dossier build supprimé/nettoyé
- [ ] `flutter clean` exécuté
- [ ] `flutter pub get` exécuté
- [ ] Dossier build exclu de l'antivirus
- [ ] IDE et terminaux fermés
- [ ] Build relancé

---

**Dernière mise à jour** : Après résolution du problème actuel

