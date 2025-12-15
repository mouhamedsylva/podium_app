# 🔐 Configuration Google Sign-In Android

## 📋 Vue d'ensemble

Ce document explique comment configurer Google Sign-In pour Android dans l'application Flutter selon la documentation fournie.

## 🎯 Prérequis

1. Un compte Google Cloud Console
2. Un projet Google Cloud avec OAuth 2.0 activé
3. Un client OAuth 2.0 Web configuré

## 🔧 Configuration Google Cloud Console

### 1. Créer un client OAuth 2.0 Web

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Sélectionnez votre projet
3. Naviguez vers **APIs & Services** > **Credentials**
4. Cliquez sur **Create Credentials** > **OAuth client ID**
5. Sélectionnez **Web application**
6. Notez le **Client ID** (format: `XXXXX.apps.googleusercontent.com`) - c'est votre **Web Client ID**

### 2. Créer un client OAuth 2.0 Android

1. Toujours dans **Credentials**, cliquez sur **Create Credentials** > **OAuth client ID**
2. Sélectionnez **Android**
3. Remplissez les informations :
   - **Name** : Jirig Android (ou votre nom)
   - **Package name** : `com.example.jirig` (selon votre `android/app/build.gradle.kts`)
   - **SHA-1 certificate fingerprint** : Votre clé de signature debug ou release
   
   **Comment obtenir le SHA-1 :**
   ```bash
   # Pour la clé debug
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   
   # Pour la clé release (si vous avez une keystore personnalisée)
   keytool -list -v -keystore path/to/your/keystore.jks -alias your-alias
   ```
4. Notez le **Client ID** (format: `XXXXX.apps.googleusercontent.com`) - c'est votre **Android Client ID**

### 3. Configurer les Redirect URIs

Dans la configuration du **Web Client ID**, ajoutez l'URI de redirection suivante :
- `https://jirig.be/api/auth/google-mobile`

⚠️ **Important** : Ne pas utiliser `jirig://auth/callback` ou d'URL sans TLD.

## 📱 Configuration Flutter

### 1. Mettre à jour `login_screen.dart`

Dans `podium_app/lib/screens/login_screen.dart`, ligne 465, remplacez :
```dart
const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
```

Par votre **Web Client ID** réel :
```dart
const webClientId = 'VOTRE_WEB_CLIENT_ID.apps.googleusercontent.com';
```

### 2. Configuration Android (`android/app/build.gradle.kts`)

Assurez-vous que le `applicationId` correspond au package name configuré dans Google Cloud Console :
```kotlin
applicationId = "com.example.jirig"
```

### 3. Vérifier la configuration SHA-1

Le SHA-1 utilisé pour signer l'APK doit correspondre à celui configuré dans Google Cloud Console.

## 🔧 Configuration Backend SNAL

Dans votre fichier `.env` de SNAL, configurez :
```env
NUXT_OAUTH_ANDROID_CLIENT_ID=VOTRE_ANDROID_CLIENT_ID.apps.googleusercontent.com
```

⚠️ **Important** : Le `NUXT_OAUTH_ANDROID_CLIENT_ID` doit être le même que le **Client ID Android** configuré dans Google Cloud Console.

## 📝 Résumé des IDs

| Type | Où l'utiliser | Format |
|------|---------------|--------|
| **Web Client ID** | Flutter `serverClientId` | `XXXXX.apps.googleusercontent.com` |
| **Android Client ID** | SNAL `NUXT_OAUTH_ANDROID_CLIENT_ID` | `XXXXX.apps.googleusercontent.com` |

⚠️ **Note** : Ces deux IDs sont différents ! Le Web Client ID est utilisé par Flutter pour obtenir l'idToken, et l'Android Client ID est utilisé par SNAL pour vérifier le token.

## 🧪 Test

1. Exécutez l'application Flutter sur Android :
   ```bash
   flutter run -d android
   ```

2. Cliquez sur "Continuer avec Google" dans l'écran de connexion

3. Sélectionnez votre compte Google

4. Vérifiez que la connexion fonctionne et que vous êtes redirigé vers la wishlist

## 🐛 Dépannage

### Erreur : "idToken non disponible"
- Vérifiez que le `serverClientId` dans Flutter correspond au **Web Client ID**
- Vérifiez que l'application Android est bien signée avec le SHA-1 configuré dans Google Cloud Console

### Erreur : "Invalid Google ID Token" (côté backend)
- Vérifiez que `NUXT_OAUTH_ANDROID_CLIENT_ID` correspond au **Android Client ID** dans Google Cloud Console
- Vérifiez que le package name (`com.example.jirig`) correspond à celui configuré dans Google Cloud Console

### Erreur : "Missing or invalid Google id_token"
- Vérifiez que l'idToken est bien envoyé à l'endpoint `/api/auth/google-mobile`
- Vérifiez les logs du proxy pour voir la requête reçue

## 📚 Documentation

- [Google Sign-In Flutter](https://pub.dev/packages/google_sign_in)
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0 pour Mobile & Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)

