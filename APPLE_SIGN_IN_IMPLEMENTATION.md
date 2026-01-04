# Implémentation Apple Sign-In dans podium_app

## ✅ Modifications effectuées

### 1. **Dépendances** (`pubspec.yaml`)
- ✅ Ajout du package `sign_in_with_apple: ^6.1.3`

### 2. **Service API** (`lib/services/api_service.dart`)
- ✅ Ajout de la méthode `loginWithAppleMobile(String identityToken)`
  - Appelle l'endpoint `/api/auth/apple-mobile?identity_token=...`
  - Gère la réponse et met à jour le profil local
  - Synchronise les cookies avec les nouveaux identifiants

### 3. **Écran de connexion** (`lib/screens/login_screen.dart`)
- ✅ Ajout de la méthode `_loginWithApple()`
  - Utilise `SignInWithApple.getAppleIDCredential()` pour obtenir le token
  - Appelle `apiService.loginWithAppleMobile()` avec l'identity token
  - Gère les erreurs spécifiques à Apple (annulation utilisateur, etc.)
  - Redirige vers la page souhaitée après connexion réussie
- ✅ Ajout du bouton Apple dans l'UI (visible uniquement sur iOS)
- ✅ Import du package `sign_in_with_apple`

## 📋 Configuration iOS requise

### 1. **Configuration dans Xcode**

#### a. Activer Sign In with Apple Capability
1. Ouvrir le projet dans Xcode : `ios/Runner.xcworkspace`
2. Sélectionner le target `Runner`
3. Aller dans l'onglet **Signing & Capabilities**
4. Cliquer sur **+ Capability**
5. Ajouter **Sign In with Apple**

#### b. Configuration du Bundle Identifier
- S'assurer que le Bundle Identifier est configuré dans Apple Developer Portal
- Le Bundle ID doit correspondre à celui configuré dans Xcode

### 2. **Configuration Apple Developer Portal**

#### a. Créer un Service ID (si nécessaire)
1. Aller sur [Apple Developer Portal](https://developer.apple.com/account/)
2. Naviguer vers **Certificates, Identifiers & Profiles**
3. Créer un **Service ID** pour Sign In with Apple
4. Configurer les domaines et redirect URLs si nécessaire

#### b. Configurer l'App ID
1. Dans **Identifiers**, sélectionner votre App ID
2. Activer **Sign In with Apple** dans les capabilities
3. Configurer les domaines associés si nécessaire

### 3. **Configuration backend (SNAL-Project)**

L'endpoint `/api/auth/apple-mobile` est déjà configuré et attend :
- **Paramètre** : `identity_token` (query parameter)
- **Réponse** : JSON avec `status`, `iProfile`, `iBasket`, `email`

Assurez-vous que la variable d'environnement `NUXT_APPLE_CLIENT_ID` est configurée dans le backend.

## 🧪 Test de l'implémentation

### Sur iOS Simulator
⚠️ **Note** : Apple Sign-In ne fonctionne pas sur le simulateur iOS. Il faut tester sur un **appareil physique iOS**.

### Sur appareil iOS
1. Installer l'application sur un appareil iOS
2. Aller sur l'écran de connexion
3. Cliquer sur le bouton "Continuer avec Apple"
4. S'authentifier avec Face ID / Touch ID / Code Apple
5. Vérifier que la connexion fonctionne et que l'utilisateur est redirigé

## 🔍 Points importants

### Disponibilité
- ✅ **iOS uniquement** : Le bouton Apple n'apparaît que sur iOS (`Platform.isIOS`)
- ❌ **Android/Web** : Apple Sign-In n'est pas disponible sur ces plateformes

### Gestion des erreurs
- ✅ Annulation utilisateur : Pas d'erreur affichée (comportement normal)
- ✅ Erreurs réseau : Message d'erreur affiché à l'utilisateur
- ✅ Erreurs serveur : Message d'erreur extrait de la réponse API

### Flux de connexion
1. Utilisateur clique sur "Continuer avec Apple"
2. Système iOS affiche le dialogue Apple Sign-In
3. Utilisateur s'authentifie (Face ID / Touch ID / Code)
4. Récupération de l'`identityToken`
5. Appel API `/api/auth/apple-mobile?identity_token=...`
6. Backend vérifie le token et crée/met à jour le profil
7. Sauvegarde des identifiants (`iProfile`, `iBasket`) dans le localStorage
8. Synchronisation des cookies
9. Redirection vers la page souhaitée

## 📝 Traductions

Ajouter la traduction `LOGIN_APPLE` dans les fichiers de traduction si nécessaire :
- Par défaut : "Continuer avec Apple"
- Peut être personnalisé via `translationService.translate('LOGIN_APPLE')`

## 🐛 Dépannage

### Le bouton Apple n'apparaît pas
- ✅ Vérifier que vous êtes sur iOS (`Platform.isIOS`)
- ✅ Vérifier que le package est bien installé : `flutter pub get`

### Erreur "Sign In with Apple capability not enabled"
- ✅ Activer la capability dans Xcode (voir section Configuration iOS)

### Erreur "Invalid client"
- ✅ Vérifier que `NUXT_APPLE_CLIENT_ID` est correctement configuré dans le backend
- ✅ Vérifier que le Bundle ID correspond à celui configuré dans Apple Developer Portal

### Erreur "Identity token not available"
- ✅ Vérifier que l'utilisateur a bien complété l'authentification Apple
- ✅ Vérifier que les permissions sont correctement configurées

## 📚 Documentation

- [Package sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)
- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Backend endpoint documentation](SNAL-Project/server/api/auth/apple-mobile.ts)

