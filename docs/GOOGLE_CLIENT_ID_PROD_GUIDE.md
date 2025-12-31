# 🔐 Guide Configuration Google Client ID - Production

## ❓ Question

**"Dans la console Google, on a créé deux ID Client, dev et en prod. Dois-je changer celui qui existe pour mettre l'ID client en prod ?"**

---

## ✅ Réponse

**OUI, vous devez utiliser l'ID client de PRODUCTION** pour les builds de production déployés sur le Play Store.

---

## 📋 Situation Actuelle

### ID Client Actuel dans le Code

**Fichier :** `lib/screens/login_screen.dart` (ligne ~480)

```dart
const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com';
```

### ID Clients dans Google Cloud Console

- **ID Client DEV** : Pour les tests en développement
- **ID Client PROD** : Pour la production (Play Store)

---

## 🎯 Solution Recommandée

### Option 1 : Utiliser l'ID Client PROD (Recommandé pour Production)

**Pour les builds de production déployés sur le Play Store**, utilisez l'ID client de PRODUCTION.

#### Modification à faire :

**Fichier :** `lib/screens/login_screen.dart`

**Avant :**
```dart
const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com'; // ID DEV
```

**Après :**
```dart
const webClientId = 'VOTRE_ID_CLIENT_PROD.apps.googleusercontent.com'; // ID PROD
```

**Remplacez `VOTRE_ID_CLIENT_PROD`** par l'ID client de production depuis Google Cloud Console.

---

### Option 2 : Gestion Multi-Environnement (Avancé)

Si vous voulez gérer automatiquement dev/prod selon l'environnement, vous pouvez utiliser une configuration conditionnelle.

#### 1. Créer un fichier de configuration

**Fichier :** `lib/config/oauth_config.dart`

```dart
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class OAuthConfig {
  // ID Client Google OAuth
  // Dev : ID client pour développement
  // Prod : ID client pour production (Play Store)
  
  static String get googleWebClientId {
    // Si on utilise l'API de production, utiliser l'ID client de production
    if (ApiConfig.useProductionApiOnMobile && !kIsWeb) {
      // Production mobile
      return 'VOTRE_ID_CLIENT_PROD.apps.googleusercontent.com';
    } else if (kDebugMode) {
      // Mode debug (développement)
      return 'VOTRE_ID_CLIENT_DEV.apps.googleusercontent.com';
    } else {
      // Production (web ou release)
      return 'VOTRE_ID_CLIENT_PROD.apps.googleusercontent.com';
    }
  }
}
```

#### 2. Modifier `login_screen.dart`

**Fichier :** `lib/screens/login_screen.dart`

**Avant :**
```dart
const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com';
```

**Après :**
```dart
import '../config/oauth_config.dart';

// Dans la fonction _loginWithGoogle()
final webClientId = OAuthConfig.googleWebClientId;
```

---

## 🔍 Comment Trouver vos ID Clients

### Dans Google Cloud Console

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet
3. Naviguez vers **APIs & Services** → **Credentials**
4. Vous verrez vos clients OAuth 2.0 :
   - **Web client (auto created by Google Service)** - C'est votre Web Client ID
   - **Android client (auto created by Google Service)** - C'est votre Android Client ID

### Identifier Dev vs Prod

Généralement, les ID clients sont nommés ou organisés ainsi :
- **DEV** : ID client créé pour les tests (SHA-1 debug)
- **PROD** : ID client créé pour la production (SHA-1 release)

**Vérifiez les SHA-1 configurés** pour chaque client :
- **DEV** : SHA-1 de votre keystore debug (`~/.android/debug.keystore`)
- **PROD** : SHA-1 de votre keystore release (celui utilisé pour signer l'APK du Play Store)

---

## ✅ Checklist Avant Déploiement Production

Avant de déployer sur le Play Store, vérifiez :

- [ ] ✅ L'ID client PROD est configuré dans `login_screen.dart`
- [ ] ✅ Le SHA-1 de votre keystore release est configuré dans Google Cloud Console pour l'ID client PROD
- [ ] ✅ Le package name (`applicationId`) correspond à celui configuré dans Google Cloud Console
- [ ] ✅ L'ID client PROD est bien le **Web Client ID** (pas l'Android Client ID)
- [ ] ✅ Le backend SNAL utilise aussi l'**Android Client ID** de production

---

## 📝 Configuration Backend SNAL

N'oubliez pas de configurer aussi le backend SNAL avec l'**Android Client ID de production** :

**Fichier :** `.env` de SNAL

```env
# Production
NUXT_OAUTH_ANDROID_CLIENT_ID=VOTRE_ANDROID_CLIENT_ID_PROD.apps.googleusercontent.com
```

⚠️ **Important :** 
- **Flutter** utilise le **Web Client ID** (dans `login_screen.dart`)
- **SNAL Backend** utilise l'**Android Client ID** (dans `.env`)

Ces deux IDs sont différents mais doivent être de la même "famille" (même projet Google Cloud).

---

## 🎯 Résumé des Actions

### Pour Production (Play Store)

1. **Récupérez l'ID client PROD** depuis Google Cloud Console
2. **Modifiez `login_screen.dart`** ligne ~480 :
   ```dart
   const webClientId = 'VOTRE_ID_CLIENT_PROD.apps.googleusercontent.com';
   ```
3. **Vérifiez le SHA-1** de votre keystore release dans Google Cloud Console
4. **Configurez le backend SNAL** avec l'Android Client ID de production
5. **Rebuild et déployez**

### Pour Développement

- Gardez l'ID client DEV pour les tests locaux
- Ou utilisez la configuration conditionnelle (Option 2) pour basculer automatiquement

---

## ⚠️ Points Importants

1. **Ne mélangez pas les ID clients** : Utilisez PROD pour production, DEV pour développement
2. **SHA-1 doit correspondre** : Le SHA-1 de votre keystore doit être configuré dans Google Cloud Console
3. **Package name doit correspondre** : Le `applicationId` doit correspondre à celui configuré dans Google Cloud Console
4. **Web Client ID vs Android Client ID** : 
   - Flutter utilise le **Web Client ID**
   - Backend SNAL utilise l'**Android Client ID**

---

## 🔧 Exemple Complet

### Étape 1 : Récupérer les ID Clients

Dans Google Cloud Console :
- **Web Client ID PROD** : `123456789-abcdefghijklmnop.apps.googleusercontent.com`
- **Android Client ID PROD** : `987654321-zyxwvutsrqponml.apps.googleusercontent.com`

### Étape 2 : Modifier Flutter

**Fichier :** `lib/screens/login_screen.dart`

```dart
// Ligne ~480
const webClientId = '123456789-abcdefghijklmnop.apps.googleusercontent.com'; // ID PROD
```

### Étape 3 : Configurer Backend SNAL

**Fichier :** `.env` de SNAL

```env
NUXT_OAUTH_ANDROID_CLIENT_ID=987654321-zyxwvutsrqponml.apps.googleusercontent.com
```

### Étape 4 : Vérifier SHA-1

```bash
# Obtenir le SHA-1 de votre keystore release
keytool -list -v -keystore path/to/your/release.keystore -alias your-alias
```

Assurez-vous que ce SHA-1 est configuré dans Google Cloud Console pour l'Android Client ID PROD.

---

**Date de création** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Guide complet pour configuration ID client production

