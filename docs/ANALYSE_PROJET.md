# Analyse Complète du Projet Podium App / Jirig

## 📋 Vue d'ensemble

**Podium App** (également appelé **Jirig**) est une application Flutter **mobile-first** qui permet de comparer les prix de produits entre différents pays. L'application se connecte au backend **SNAL-Project** via l'API `https://jirig.be/api`.

### Informations générales
- **Nom du projet**: Jirig / Podium App
- **Type**: Application Flutter (cross-platform)
- **Plateformes supportées**: Android, iOS, Web
- **Version**: 1.0.0+1
- **SDK Flutter**: ^3.9.2
- **Architecture**: Mobile-First avec support web via proxy

---

## 🏗️ Architecture Technique

### Stack Technologique

#### Frontend (Flutter)
- **Framework**: Flutter 3.9.2+
- **Navigation**: `go_router` (^14.2.7)
- **State Management**: `provider` (^6.1.2)
- **HTTP Client**: 
  - `dio` (^5.4.3+1) pour les requêtes HTTP
  - `http` (^1.2.2) comme alternative
- **Gestion des cookies**: 
  - `dio_cookie_manager` + `cookie_jar` (mobile)
  - Gestion native du navigateur (web)

#### Backend Proxy (Node.js)
- **Serveur**: Express.js
- **Port**: 3001
- **Rôle**: Proxy pour contourner les problèmes CORS sur web
- **Fichier**: `proxy-server.js`

#### Backend API
- **URL de production**: `https://jirig.be/api`
- **Type**: SNAL-Project (backend existant)

---

## 📁 Structure du Projet

```
podium_app/
├── lib/
│   ├── main.dart              # Point d'entrée de l'application
│   ├── app.dart               # Configuration de l'app et routing
│   ├── config/
│   │   └── api_config.dart    # Configuration API (mobile-first)
│   ├── models/
│   │   ├── country.dart       # Modèle de données pays
│   │   ├── user_settings.dart # Paramètres utilisateur
│   │   └── wishlist.dart      # Modèle wishlist
│   ├── screens/               # Écrans de l'application
│   │   ├── splash_screen.dart
│   │   ├── country_selection_screen.dart
│   │   ├── home_screen.dart
│   │   ├── product_search_screen.dart
│   │   ├── podium_screen.dart      # Écran principal de comparaison
│   │   ├── wishlist_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── profile_detail_screen.dart
│   │   └── login_screen.dart
│   ├── services/              # Services métier
│   │   ├── api_service.dart           # Service API principal
│   │   ├── auth_notifier.dart         # Gestion de l'authentification
│   │   ├── country_notifier.dart      # Gestion des pays
│   │   ├── translation_service.dart   # Service de traduction
│   │   ├── local_storage_service.dart  # Stockage local
│   │   ├── oauth_mobile_handler.dart   # Gestion OAuth mobile
│   │   └── ...
│   └── widgets/               # Composants réutilisables
│       ├── bottom_navigation_bar.dart
│       ├── custom_app_bar.dart
│       ├── qr_scanner_modal.dart
│       └── ...
├── android/                   # Configuration Android
├── ios/                       # Configuration iOS
├── web/                       # Configuration Web
├── assets/                    # Ressources (images, icônes, drapeaux)
├── docs/                      # Documentation (72 fichiers)
├── proxy-server.js           # Serveur proxy Node.js
└── pubspec.yaml              # Dépendances Flutter
```

---

## 🎯 Fonctionnalités Principales

### 1. **Sélection de Pays**
- Choix du pays pour la comparaison
- Support multi-langues (FR, EN, DE, ES, IT, PT, NL)
- Affichage des drapeaux

### 2. **Recherche de Produits**
- Recherche par nom de produit
- Recherche par code-barres (scanner QR)
- Affichage des résultats

### 3. **Podium de Comparaison** (Fonctionnalité principale)
- Affichage du produit sélectionné
- Comparaison des prix entre pays
- Podium visuel (1er, 2ème, 3ème prix)
- Affichage des autres pays disponibles
- Gestion des quantités
- Animations "Explosion & Reveal"

### 4. **Authentification**
- Connexion via Google Sign-In
- Connexion via Facebook
- Mode Guest (sans authentification)
- Gestion des profils utilisateur
- Deep links pour OAuth mobile

### 5. **Wishlist**
- Ajout de produits à la wishlist
- Gestion de plusieurs wishlists
- Synchronisation avec le backend

### 6. **Profil Utilisateur**
- Affichage des informations utilisateur
- Gestion des paramètres
- Historique

### 7. **Scanner QR Code**
- Scanner de codes-barres
- Recherche automatique après scan
- Modal intégré

### 8. **Carte Interactive** (Implémentée)
- Affichage des magasins sur une carte
- Utilisation de `flutter_map`
- Clustering de marqueurs

---

## 🔧 Configuration API (Mobile-First)

### Stratégie Mobile-First
L'application utilise une approche **mobile-first** :

- **Mobile (Android/iOS)**:
  - Appel direct à `https://jirig.be/api` (production)
  - Gestion des cookies via `PersistCookieJar`
  - Pas de problème CORS

- **Web**:
  - Utilise le proxy local `http://localhost:3001/api`
  - Le proxy contourne les problèmes CORS
  - Les cookies sont gérés par le navigateur

### Configuration dans `api_config.dart`
```dart
static const bool useProductionApiOnMobile = true; // Production directe
static const String localProxyUrl = 'http://10.0.2.2:3001/api'; // Émulateur Android
```

---

## 🔐 Authentification

### Méthodes d'authentification
1. **Google Sign-In**: Via `google_sign_in` package
2. **Facebook**: Via `flutter_facebook_auth` package
3. **Mode Guest**: Profil anonyme avec `GuestProfile` cookie

### Gestion des profils
- **Profil connecté**: Stocké dans `LocalStorageService`
- **Profil Guest**: Géré via cookies `GuestProfile` avec `iProfile` et `iBasket`
- **Deep Links**: Gestion des callbacks OAuth via `OAuthMobileHandler`

---

## 📱 Écrans Principaux

### 1. **SplashScreen** (`/splash`)
- Écran de démarrage
- Initialisation de l'application

### 2. **CountrySelectionScreen** (`/country-selection`)
- Sélection du pays de comparaison
- Affichage des drapeaux

### 3. **HomeScreen** (`/home`)
- Écran d'accueil principal
- Modules d'accès rapide
- Bannière premium
- Scanner QR intégré

### 4. **ProductSearchScreen** (`/product-search`, `/product-code`)
- Recherche de produits
- Affichage des résultats
- Scanner QR modal

### 5. **PodiumScreen** (`/podium/:code`)
- **Écran principal de comparaison**
- Affichage du produit
- Podium des prix (top 3)
- Liste des autres pays
- Animations complexes

### 6. **WishlistScreen** (`/wishlist`)
- Liste des produits favoris
- Gestion des wishlists

### 7. **ProfileScreen** (`/profile`)
- Profil utilisateur
- Paramètres

### 8. **LoginScreen** (`/login`)
- Connexion Google/Facebook
- Mode Guest

---

## 🎨 Animations

L'application utilise des animations sophistiquées :

### HomeScreen
- Animation du titre (fade + scale)
- Animations échelonnées des modules
- Bannière premium animée

### PodiumScreen
- Style "Explosion & Reveal"
- Rotation 3D du produit
- Construction du podium depuis le bas
- Animations des autres pays

### Packages utilisés
- `animations` (^2.0.11) - Animations officielles Flutter
- `page_transition` (^2.2.1) - Transitions de pages
- `loading_animation_widget` (^1.3.0) - Animations de chargement

---

## 🌍 Internationalisation

### Langues supportées
- Français (FR)
- Anglais (EN)
- Allemand (DE)
- Espagnol (ES)
- Italien (IT)
- Portugais (PT)
- Néerlandais (NL)

### Service de traduction
- `TranslationService` : Gère les traductions dynamiques depuis l'API
- `flutter_localizations` : Support natif Flutter
- `intl` : Formatage des dates/nombres

---

## 💾 Stockage Local

### Services de stockage
- **SharedPreferences**: Paramètres utilisateur
- **LocalStorageService**: Profil utilisateur, authentification
- **PersistCookieJar**: Cookies API (mobile uniquement)
- **RoutePersistenceService**: Persistance des routes

### Données stockées
- Profil utilisateur (`iProfile`, `iBasket`, etc.)
- Pays sélectionné
- Paramètres de l'application
- État d'authentification

---

## 🔄 Gestion d'État

### Provider Pattern
L'application utilise `provider` pour la gestion d'état :

- **ApiService**: Service API singleton
- **SettingsService**: Paramètres de l'application
- **TranslationService**: Traductions (ChangeNotifier)
- **CountryNotifier**: Pays sélectionné (ChangeNotifier)
- **AuthNotifier**: État d'authentification (ChangeNotifier)

---

## 🛠️ Développement

### Commandes utiles

#### Démarrer le proxy (Web)
```bash
npm start
# ou
npm run dev  # avec nodemon
```

#### Lancer Flutter Web
```bash
flutter run -d chrome --web-port=8080
# ou utiliser start-web-dev.bat
```

#### Build Android
```bash
flutter build apk --release
```

#### Build iOS
```bash
flutter build ios --release
```

### Configuration Android
- **Package name**: Configuré dans `android/app/build.gradle.kts`
- **Signing**: Fichier `monapp-release.jks` présent
- **SHA-1**: Documentation dans `docs/GOOGLE_PLAY_SHA1_CONFIGURATION.md`

### Configuration iOS
- Configuration standard Flutter
- Support des deep links

---

## 📚 Documentation

Le projet contient **72 fichiers de documentation** dans le dossier `docs/` couvrant :

- Configuration OAuth (Google, Facebook)
- Setup Android/iOS
- Guide de déploiement Play Store
- Documentation des endpoints API
- Guides de résolution de problèmes
- Documentation des animations
- Guides de configuration

---

## 🔍 Points Clés de l'Architecture

### 1. **Mobile-First Design**
- Priorité à l'expérience mobile native
- Web comme plateforme secondaire via proxy

### 2. **Gestion des Cookies**
- Mobile: `PersistCookieJar` pour persistance
- Web: Gestion native du navigateur

### 3. **Deep Links**
- Support des magic links depuis email
- Callbacks OAuth pour mobile
- Package `app_links` (^6.4.1)

### 4. **Proxy Server**
- Contourne CORS pour web
- Gère les cookies GuestProfile
- Proxy des images si nécessaire

### 5. **Gestion d'Erreurs**
- `SearchArticleException` pour les erreurs de recherche
- Gestion des erreurs d'authentification
- Redirections automatiques

---

## 🚀 Déploiement

### Android
- APK signé avec `monapp-release.jks`
- Configuration Play Store documentée
- SHA-1 configuré pour Google Sign-In

### Web
- Nécessite le proxy server en cours d'exécution
- Configuration CORS gérée par le proxy

### iOS
- Configuration standard
- Support des deep links

---

## 📊 Endpoints API Principaux

D'après le code et la documentation :

- `/api/comparaison-by-code-30041025` - Détails du produit
- `/api/search-article` - Recherche de produits
- `/api/countries` - Liste des pays
- `/api/wishlist` - Gestion de la wishlist
- `/api/profile` - Profil utilisateur
- `/api/auth/*` - Endpoints d'authentification

---

## 🎯 Cas d'Usage Principaux

1. **Utilisateur Guest**:
   - Sélectionne un pays
   - Recherche un produit
   - Consulte le podium de comparaison
   - Peut ajouter à la wishlist (profil guest)

2. **Utilisateur Connecté**:
   - Toutes les fonctionnalités Guest
   - Wishlist persistante
   - Profil personnalisé
   - Historique

3. **Scanner QR**:
   - Scan d'un code-barres
   - Recherche automatique
   - Affichage du podium

---

## 🔐 Sécurité

- Gestion sécurisée des cookies
- Authentification OAuth
- HTTPS pour les appels API
- Validation des données côté client

---

## 📝 Notes Importantes

1. **Conflit de nom**: Le projet s'appelle à la fois "Jirig" et "Podium App" (visible dans README.md)

2. **Backend SNAL-Project**: L'application se connecte à un backend existant, pas de backend dans ce repo

3. **Proxy obligatoire pour Web**: Le développement web nécessite le proxy Node.js

4. **Mobile-First**: L'application est optimisée pour mobile, web est secondaire

5. **Documentation extensive**: 72 fichiers de documentation dans `docs/`

---

## 🐛 Points d'Attention

- Configuration du proxy pour le développement web
- Gestion des cookies différente entre mobile et web
- Deep links nécessitent une configuration spécifique
- SHA-1 doit être configuré pour Google Sign-In sur Android

---

## 📞 Support

Pour plus d'informations, consulter les fichiers dans `docs/` qui contiennent des guides détaillés pour chaque aspect du projet.

