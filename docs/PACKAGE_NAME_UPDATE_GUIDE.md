# 📦 Guide Package Name - Mises à Jour Application

## ⚠️ RÈGLE CRITIQUE

**Pour une mise à jour d'application sur le Play Store, le package name (applicationId) DOIT rester EXACTEMENT le même que celui utilisé lors du premier déploiement.**

Si le package name change, Google Play considère cela comme une **nouvelle application**, pas une mise à jour.

---

## 📋 Package Name Actuel dans le Code

### Fichier : `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.example.jirig"
    
    defaultConfig {
        applicationId = "com.example.jirig"  // ← C'EST LE PACKAGE NAME
        // ...
    }
}
```

### Fichier : `android/app/src/main/kotlin/com/example/jirig/MainActivity.kt`

```kotlin
package com.example.jirig  // ← DOIT CORRESPONDRE AU NAMESPACE
```

---

## ✅ Vérification du Package Name Déployé

### Comment vérifier le package name utilisé lors du déploiement :

1. **Dans la Google Play Console** :
   - Allez dans votre application
   - Section "Configuration de l'application" → "Détails de l'application"
   - Le package name est affiché en haut (ex: `com.example.jirig`)

2. **Dans l'APK/AAB déployé** :
   - Le package name est dans le fichier `AndroidManifest.xml` de l'APK
   - Vous pouvez l'extraire avec `aapt dump badging app.apk | grep package`

---

## 🔄 Scénarios et Actions

### ✅ Scénario 1 : Package Name Identique

**Situation :** Le package name dans votre code (`com.example.jirig`) est **identique** à celui utilisé lors du déploiement.

**Action :** ✅ **AUCUNE MODIFICATION NÉCESSAIRE**

Vous pouvez directement :
1. Modifier votre code
2. Augmenter le `versionCode` dans `pubspec.yaml`
3. Augmenter le `versionName` dans `pubspec.yaml`
4. Rebuild et déployer la mise à jour

**Exemple :**
```yaml
# pubspec.yaml
version: 1.0.1+2  # versionName+versionCode
```

---

### ❌ Scénario 2 : Package Name Différent

**Situation :** Le package name dans votre code est **différent** de celui utilisé lors du déploiement.

**Exemple :**
- Code actuel : `com.example.jirig`
- Déployé : `com.jirig.app` (ou autre)

**Action :** ⚠️ **VOUS DEVEZ CORRIGER LE CODE**

Vous devez modifier le code pour utiliser le **même package name que celui déployé** :

#### 1. Modifier `android/app/build.gradle.kts`

```kotlin
android {
    namespace = "com.jirig.app"  // ← Utiliser le package name déployé
    
    defaultConfig {
        applicationId = "com.jirig.app"  // ← Utiliser le package name déployé
        // ...
    }
}
```

#### 2. Déplacer le fichier MainActivity.kt

**Avant :**
```
android/app/src/main/kotlin/com/example/jirig/MainActivity.kt
```

**Après :**
```
android/app/src/main/kotlin/com/jirig/app/MainActivity.kt
```

#### 3. Modifier le package dans MainActivity.kt

```kotlin
package com.jirig.app  // ← Utiliser le package name déployé

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

#### 4. Vérifier les autres fichiers Kotlin/Java

Si vous avez d'autres fichiers Kotlin/Java dans le projet, ils doivent aussi utiliser le bon package.

---

## 📝 Checklist Avant Mise à Jour

Avant de rebuilder pour une mise à jour, vérifiez :

- [ ] ✅ Le `applicationId` dans `build.gradle.kts` correspond au package name déployé
- [ ] ✅ Le `namespace` dans `build.gradle.kts` correspond au package name déployé
- [ ] ✅ Le package dans `MainActivity.kt` correspond au namespace
- [ ] ✅ Le chemin du fichier `MainActivity.kt` correspond au package (ex: `kotlin/com/jirig/app/MainActivity.kt`)
- [ ] ✅ Le `versionCode` a été augmenté (obligatoire pour chaque mise à jour)
- [ ] ✅ Le `versionName` a été mis à jour (recommandé)

---

## 🔍 Comment Trouver le Package Name Déployé

### Méthode 1 : Google Play Console

1. Connectez-vous à la [Google Play Console](https://play.google.com/console)
2. Sélectionnez votre application
3. Allez dans **"Configuration de l'application"** → **"Détails de l'application"**
4. Le package name est affiché en haut de la page

### Méthode 2 : APK Analyzer

1. Téléchargez l'APK depuis le Play Store (si vous l'avez)
2. Utilisez Android Studio → Build → Analyze APK
3. Ouvrez le fichier `AndroidManifest.xml`
4. Cherchez `package="..."` ou `android:package="..."`

### Méthode 3 : Commande aapt

```bash
aapt dump badging app-release.apk | grep package
```

---

## ⚠️ Erreurs Courantes

### ❌ Erreur 1 : Changer le Package Name par Accident

**Symptôme :** Google Play rejette la mise à jour ou la considère comme une nouvelle app.

**Solution :** Vérifiez toujours que le package name correspond exactement.

### ❌ Erreur 2 : Oublier de Déplacer MainActivity.kt

**Symptôme :** Erreur de compilation : "package does not match expected directory structure"

**Solution :** Déplacez le fichier `MainActivity.kt` dans le bon répertoire correspondant au package.

### ❌ Erreur 3 : Oublier d'Augmenter versionCode

**Symptôme :** Google Play rejette la mise à jour : "versionCode must be higher"

**Solution :** Augmentez toujours le `versionCode` dans `pubspec.yaml`.

---

## 📚 Exemple Complet de Mise à Jour

### Étape 1 : Vérifier le Package Name Déployé

Supposons que le package name déployé est : `com.jirig.app`

### Étape 2 : Vérifier le Code Actuel

Si le code actuel utilise `com.example.jirig`, vous devez le changer.

### Étape 3 : Modifier build.gradle.kts

```kotlin
android {
    namespace = "com.jirig.app"  // ← Modifié
    
    defaultConfig {
        applicationId = "com.jirig.app"  // ← Modifié
        // ...
    }
}
```

### Étape 4 : Déplacer MainActivity.kt

```bash
# Créer le nouveau répertoire
mkdir -p android/app/src/main/kotlin/com/jirig/app

# Déplacer le fichier
mv android/app/src/main/kotlin/com/example/jirig/MainActivity.kt \
   android/app/src/main/kotlin/com/jirig/app/MainActivity.kt

# Supprimer l'ancien répertoire (s'il est vide)
rmdir android/app/src/main/kotlin/com/example/jirig
```

### Étape 5 : Modifier MainActivity.kt

```kotlin
package com.jirig.app  // ← Modifié

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

### Étape 6 : Augmenter la Version

```yaml
# pubspec.yaml
version: 1.0.1+2  # versionName+versionCode (augmenter versionCode)
```

### Étape 7 : Rebuild

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## ✅ Résumé

1. **Le package name DOIT rester identique** pour les mises à jour
2. **Vérifiez toujours** le package name déployé dans la Play Console
3. **Si différent**, modifiez le code pour correspondre au package name déployé
4. **N'oubliez jamais** d'augmenter le `versionCode` pour chaque mise à jour
5. **Déplacez MainActivity.kt** si le package change

---

**Date de création** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Guide complet pour gestion package name

