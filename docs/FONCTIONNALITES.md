# 📱 Documentation des Fonctionnalités - Application Flutter Jirig

## 📋 Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Écrans principaux](#écrans-principaux)
4. [Services](#services)
5. [Widgets réutilisables](#widgets-réutilisables)
6. [Fonctionnalités détaillées](#fonctionnalités-détaillées)
7. [Technologies utilisées](#technologies-utilisées)
8. [Plateformes supportées](#plateformes-supportées)

---

## 🎯 Vue d'ensemble

**Jirig** est une application multiplateforme (Mobile & Web) permettant de comparer les prix des produits IKEA à travers différents pays européens. L'application offre une expérience mobile-first avec support web complet.

### Concept principal
- Comparaison internationale des prix IKEA
- Scanner QR code des produits en magasin
- Gestion de wishlist personnalisée
- Système de connexion via OAuth et Magic Links

---

## 🏗️ Architecture

### Structure du projet
```
jirig/
├── lib/
│   ├── app.dart                    # Configuration principale de l'app
│   ├── main.dart                   # Point d'entrée
│   ├── config/                     # Configuration (API, constantes)
│   ├── models/                     # Modèles de données
│   ├── screens/                    # Écrans de l'application
│   ├── services/                   # Services métier
│   ├── widgets/                    # Composants réutilisables
│   └── utils/                      # Utilitaires
├── assets/                         # Images, drapeaux, icônes
├── android/                        # Configuration Android
├── ios/                           # Configuration iOS
└── web/                           # Configuration Web
```

### Approche Mobile-First
- **Mobile (Android/iOS)** : Utilisation native des cookies, permissions caméra, deep links
- **Web** : Proxy Node.js pour contourner CORS, pas de cookies côté client
- Détection automatique de la plateforme via `kIsWeb`
- Adaptation de l'UI selon la taille d'écran (responsive design)

---

## 📱 Écrans principaux

### 1. **SplashScreen** (`splash_screen.dart`)
**Écran de chargement animé**

**Fonctionnalités :**
- ✅ Animation personnalisée avec logo Jirig
- ✅ Anneaux bleu et jaune en rotation (inspiré IKEA)
- ✅ Barre de progression en bas
- ✅ Transition automatique vers l'écran de sélection de pays (8 secondes)
- ✅ Animations fluides avec `AnimationController`

**Caractéristiques techniques :**
- CustomPainter pour les anneaux animés
- Gestion du cycle de vie des animations
- Protection contre les fuites mémoire

---

### 2. **CountrySelectionScreen** (`country_selection_screen.dart`)
**Sélection du pays d'origine de l'utilisateur**

**Fonctionnalités :**
- ✅ Liste complète des pays européens avec drapeaux
- ✅ Recherche en temps réel avec filtrage
- ✅ Sélection unique avec validation visuelle
- ✅ Acceptation des conditions d'utilisation
- ✅ Chargement dynamique des drapeaux (API + fallback local)
- ✅ Support multi-langues basé sur le pays sélectionné
- ✅ Design responsive (mobile/tablette/desktop)

**Caractéristiques techniques :**
- Gestion des drapeaux via proxy pour CORS (web) ou assets locaux
- Fallback emoji si image indisponible
- Validation des formulaires
- Sauvegarde des préférences dans SharedPreferences

---

### 3. **HomeScreen** (`home_screen.dart`)
**Page d'accueil avec modules d'accès**

**Fonctionnalités :**
- ✅ Titre dynamique avec mise en valeur "IKEA" et "pays"
- ✅ Deux modules principaux :
  - 🔍 **Recherche de produits** (navigation vers `/product-code`)
  - 📷 **Scanner QR code** (modal scanner)
- ✅ Bannière premium (promotion abonnement)
- ✅ Vérification automatique de connexion OAuth
- ✅ Gestion du retour depuis OAuth avec callback URL
- ✅ Popup de succès après connexion

**Caractéristiques techniques :**
- Provider pour gestion d'état (TranslationService, SettingsService, AuthNotifier)
- Navigation avec GoRouter
- Animations d'apparition échelonnées (désactivées sur web)
- Détection automatique du pays sélectionné

---

### 4. **ProductSearchScreen** (`product_search_screen.dart`)
**Recherche de produits IKEA**

**Fonctionnalités :**
- ✅ Recherche par code article (format XXX.XXX.XX)
- ✅ Formatage automatique du code pendant la saisie
- ✅ Bouton scanner QR code intégré
- ✅ Affichage des résultats avec :
  - Image du produit
  - Code article (formaté)
  - Nom et description
  - Prix et devise
  - Badge "Indisponible" si produit non disponible
- ✅ Surlignage des termes de recherche dans les résultats
- ✅ Sélection de pays multiples pour la comparaison
- ✅ États de chargement avec animations
- ✅ Gestion des erreurs et messages appropriés

**Caractéristiques techniques :**
- API searchArticle avec limitation (10 résultats max)
- Proxy d'images pour CORS
- Validation du profil utilisateur (iProfile requis)
- Gestion des états : initial, loading, results, error, no-results

---

### 5. **PodiumScreen** (`podium_screen.dart`)
**Comparaison des prix par pays (écran podium)**

**Fonctionnalités principales :**
- ✅ Affichage du produit avec :
  - Galerie d'images (navigation gauche/droite)
  - Zoom d'image en plein écran avec InteractiveViewer
  - Nom et description du produit
  - Code article
  - Sélecteur de quantité
- ✅ **Podium des 3 meilleurs prix** :
  - 🥇 Or : meilleur prix
  - 🥈 Argent : 2ème prix
  - 🥉 Bronze : 3ème prix
  - Disposition visuelle (2-1-3) comme un vrai podium
  - Couleurs et gradients personnalisés par rang
  - Badge d'économie affichant la différence de prix
- ✅ **Pays de l'utilisateur** marqué avec icône 🏠
- ✅ **Liste des autres pays** avec :
  - Drapeau
  - Nom du pays
  - Prix
  - Bouton Wishlist
  - Indicateur pays utilisateur
- ✅ Ajout au panier/wishlist avec redirection automatique
- ✅ Gestion de la quantité sur chaque carte pays
- ✅ Bouton "Nouvelle recherche"

**Caractéristiques techniques :**
- Tri automatique des prix (du moins cher au plus cher)
- Calcul dynamique des écarts de prix
- Détection si tous les prix sont identiques
- Animation de transition désactivée sur web
- Gestion des paramètres URL (quantité, code crypté)
- Mise à jour du iBasket après ajout wishlist
- Logs détaillés pour debugging

**Responsive Design :**
- Support des écrans très petits (Galaxy Fold < 360px)
- Support des petits mobiles (360-430px)
- Support des mobiles standards (431-767px)
- Adaptation des tailles de police, padding, hauteurs

---

### 6. **WishlistScreen** (`wishlist_screen.dart`)
**Gestion de la liste de souhaits**

**Fonctionnalités principales :**
- ✅ Affichage de tous les articles en wishlist
- ✅ Groupement par pays
- ✅ Affichage des informations :
  - Image du produit
  - Nom et description
  - Code article
  - Prix et quantité
  - Total par article
- ✅ Actions disponibles :
  - Modifier la quantité (+/-)
  - Supprimer un article
  - Voir les détails (navigation vers podium)
  - Partager
  - Voir sur la carte
- ✅ Résumé avec total général
- ✅ Gestion du panier vide avec message
- ✅ Rechargement intelligent avec debouncing
- ✅ Persistance des données

**Caractéristiques techniques :**
- Chargement depuis API (`/api/basket/get`)
- Mise à jour optimiste de l'UI
- Gestion du iBasket crypté
- Suppression avec confirmation
- Support de la pagination si nécessaire
- Optimisation du rechargement (évite boucles infinies)

---

### 7. **ProfileScreen** (`profile_screen.dart`)
**Gestion du profil utilisateur**

**Fonctionnalités :**
- ✅ Affichage des informations utilisateur :
  - Avatar avec initiales
  - Nom et prénom
  - Email
  - Téléphone
  - Adresse complète (rue, code postal, ville)
- ✅ Mode édition/lecture des informations
- ✅ Sélection du **pays principal** (sPaysLangue)
- ✅ Gestion des **pays favoris** (sPaysFav) :
  - Sélection multiple
  - Affichage avec drapeaux
  - Ajout/retrait facile
- ✅ Validation du formulaire
- ✅ Sauvegarde via API
- ✅ Bouton retour vers wishlist

**Caractéristiques techniques :**
- Chargement depuis API (`getUserInfo`)
- Fallback vers LocalStorage
- Validation des champs (email requis)
- Mise à jour du profil local après sauvegarde
- Dialogue de sélection pays avec drapeaux

---

### 8. **LoginScreen** (`login_screen.dart`)
**Authentification utilisateur**

**Fonctionnalités :**
- ✅ Connexion via **OAuth Google/Facebook**
- ✅ Connexion par **Magic Link** (lien email)
- ✅ Formulaire email avec validation
- ✅ Boutons sociaux avec icônes
- ✅ Gestion du callback URL (redirection après connexion)
- ✅ Messages d'erreur clairs
- ✅ Support mobile + web

**Caractéristiques OAuth :**
- Configuration spécifique mobile/web
- Callback URL dynamique
- Sauvegarde du callBackUrl dans localStorage
- Redirection automatique après succès

---

### 9. **MagicLoginScreen** (`magic_login_screen.dart`)
**Validation du lien magique depuis email**

**Fonctionnalités :**
- ✅ Réception des paramètres deep link (email, token, callBackUrl)
- ✅ Validation automatique du token via API
- ✅ Affichage du statut :
  - En cours de validation
  - Succès avec check vert
  - Erreur avec message
- ✅ Sauvegarde du profil utilisateur
- ✅ Redirection automatique vers callBackUrl ou home
- ✅ Messages de succès/erreur

**Caractéristiques techniques :**
- Appel API `login` avec token comme mot de passe
- Extraction des données profil (iProfile, iBasket, etc.)
- Sauvegarde dans LocalStorage
- Navigation avec GoRouter

---

### 10. **OAuthCallbackScreen** (`oauth_callback_screen.dart`)
**Gestion du retour OAuth**

**Fonctionnalités :**
- ✅ Récupération du profil depuis l'URL
- ✅ Parsing des paramètres OAuth
- ✅ Sauvegarde du profil
- ✅ Redirection vers callBackUrl

---

### 11. **ArticleNotFoundScreen** (`article_not_found_screen.dart`)
**Écran d'erreur produit non trouvé**

**Fonctionnalités :**
- ✅ Message d'erreur clair
- ✅ Suggestions d'actions
- ✅ Bouton retour/nouvelle recherche

---

### 12. **ProfileDetailScreen** (`profile_detail_screen.dart`)
**Vue détaillée du profil**

**Fonctionnalités :**
- ✅ Informations complètes du profil
- ✅ Statistiques utilisateur
- ✅ Historique des actions

---

## 🔧 Services

### 1. **ApiService** (`api_service.dart`)
**Service de communication avec le backend SNAL**

**Fonctionnalités principales :**
- ✅ Gestion automatique des cookies (mobile uniquement)
- ✅ Proxy automatique pour le web (CORS)
- ✅ Singleton pattern (instance unique)
- ✅ Intercepteurs Dio pour :
  - Logs détaillés
  - Gestion du profil (GuestProfile en header/cookie)
  - Gestion des erreurs
- ✅ Timeout configurables

**Endpoints API :**
- `login(email, token)` - Connexion utilisateur
- `searchArticle(query, token, limit)` - Recherche d'articles
- `getComparaisonByCode(...)` - Comparaison de prix
- `addToWishlist(...)` - Ajout à la wishlist
- `getBasket(iBasket, iProfile)` - Récupération du panier
- `removeFromBasket(...)` - Suppression d'un article
- `updateBasketQuantity(...)` - Modification quantité
- `getUserInfo()` - Infos utilisateur
- `updateProfile(data)` - Mise à jour profil

---

### 2. **DeepLinkService** (`deep_link_service.dart`)
**Gestion des deep links (Magic Links)**

**Fonctionnalités :**
- ✅ Écoute des liens entrants via `uni_links`
- ✅ Détection du lien initial (app fermée)
- ✅ Stream pour les liens pendant l'exécution
- ✅ Parsing des URLs `https://jirig.be/connexion`
- ✅ Dialogue de confirmation avant ouverture
- ✅ Navigation vers `/magic-login` avec paramètres

**Caractéristiques :**
- Fonctionne **uniquement sur mobile** (Android/iOS)
- Le web gère les URLs nativement via GoRouter

---

### 3. **LocalStorageService** (`local_storage_service.dart`)
**Gestion du stockage local**

**Fonctionnalités :**
- ✅ Sauvegarde/récupération du profil utilisateur
- ✅ Gestion du callBackUrl
- ✅ Persistance des préférences
- ✅ Initialisation automatique du profil

**Données stockées :**
- `iProfile` - ID profil utilisateur
- `iBasket` - ID panier (crypté)
- `sPaysLangue` - Langue du pays (ex: FR/fr)
- `sPaysFav` - Pays favoris (liste séparée par virgules)
- `sEmail`, `sNom`, `sPrenom` - Infos utilisateur

---

### 4. **TranslationService** (`translation_service.dart`)
**Gestion de l'internationalisation**

**Fonctionnalités :**
- ✅ Chargement dynamique des traductions depuis l'API
- ✅ Support de 7 langues : FR, EN, DE, ES, IT, PT, NL
- ✅ Cache des traductions chargées
- ✅ Fallback sur la clé si traduction manquante
- ✅ Méthode `translate(key)` avec ChangeNotifier
- ✅ Changement de langue dynamique

---

### 5. **SettingsService** (`settings_service.dart`)
**Gestion des paramètres**

**Fonctionnalités :**
- ✅ Sauvegarde du pays sélectionné
- ✅ Acceptation des conditions
- ✅ Récupération des préférences
- ✅ Initialisation du pays au démarrage

---

### 6. **CountryService** (`country_service.dart`)
**Gestion des pays**

**Fonctionnalités :**
- ✅ Récupération de la liste des pays depuis l'API
- ✅ Cache des pays en mémoire
- ✅ Filtrage et recherche
- ✅ Mapping avec drapeaux

---

### 7. **AuthNotifier** (`auth_notifier.dart`)
**Gestion de l'état d'authentification**

**Fonctionnalités :**
- ✅ Vérification si l'utilisateur est connecté
- ✅ Notification des changements d'état
- ✅ Rafraîchissement du profil
- ✅ Provider pour l'app entière

---

### 8. **ProfileService** (`profile_service.dart`)
**Gestion du profil utilisateur**

**Fonctionnalités :**
- ✅ Génération automatique d'un GuestProfile
- ✅ Validation du profil existant
- ✅ Sauvegarde/récupération

---

### 9. **RoutePersistenceService** (`route_persistence_service.dart`)
**Persistance de la route au démarrage**

**Fonctionnalités :**
- ✅ Sauvegarde de la dernière route visitée
- ✅ Restauration au démarrage
- ✅ Route par défaut intelligente

---

### 10. **IconService** (`icon_service.dart`)
**Mapping des icônes**

**Fonctionnalités :**
- ✅ Correspondance nom d'icône → IconData Flutter
- ✅ Icônes par défaut si non trouvée

---

### 11. **SearchService** (`search_service.dart`)
**Service de recherche**

**Fonctionnalités :**
- ✅ Recherche d'articles
- ✅ Filtrage local
- ✅ Cache des résultats

---

### 12. **CountryNotifier** (`country_notifier.dart`)
**Notification des changements de pays**

**Fonctionnalités :**
- ✅ Provider pour le pays sélectionné
- ✅ Notification des widgets

---

## 🧩 Widgets réutilisables

### 1. **CustomAppBar** (`custom_app_bar.dart`)
**Barre d'app personnalisée**

**Fonctionnalités :**
- ✅ Logo Jirig avec dégradé
- ✅ Sélecteur de pays avec drapeau
- ✅ Changement de langue
- ✅ Design responsive

---

### 2. **CustomBottomNavigationBar** (`bottom_navigation_bar.dart`)
**Barre de navigation inférieure**

**Fonctionnalités :**
- ✅ 5 onglets : Home, Search, Scanner, Wishlist, Profile
- ✅ Indicateur d'onglet actif
- ✅ Navigation avec GoRouter
- ✅ Icônes personnalisées

---

### 3. **QrScannerModal** (`qr_scanner_modal.dart`)
**Scanner QR code en modal**

**Fonctionnalités :**
- ✅ Scanner caméra avec `mobile_scanner`
- ✅ Zone de scan animée avec coins
- ✅ Détection multi-frame pour fiabilité
- ✅ Validation du QR code (8 chiffres)
- ✅ Formatage du code (XXX.XXX.XX)
- ✅ Feedback haptique et sonore
- ✅ Indicateur de confiance (barre de progression)
- ✅ Tips d'aide si scan difficile
- ✅ États visuels : scanning, detecting, capturing, success
- ✅ Fermeture automatique après succès
- ✅ Navigation vers `/podium/:code`

**Logique de détection :**
- Buffer de détections (max 10)
- Fenêtre de validation (1.5 secondes)
- Minimum 2 détections identiques
- Seuil de confiance : 60%
- Nettoyage automatique de l'historique

---

### 4. **SearchModal** (`search_modal.dart`)
**Modal de recherche**

**Fonctionnalités :**
- ✅ Modal bottom sheet
- ✅ Recherche rapide
- ✅ Résultats en temps réel

---

### 5. **SimpleMapModal** (`simple_map_modal.dart`)
**Carte interactive simple**

**Fonctionnalités :**
- ✅ Affichage d'un magasin IKEA sur la carte
- ✅ Marqueur personnalisé
- ✅ Zoom et déplacement

---

### 6. **PremiumBanner** (`premium_banner.dart`)
**Bannière promotionnelle**

**Fonctionnalités :**
- ✅ Promotion de l'abonnement premium
- ✅ Design accrocheur
- ✅ Call-to-action

---

### 7. **PageLoader** (`page_loader.dart`)
**Indicateur de chargement**

**Fonctionnalités :**
- ✅ Animation personnalisée
- ✅ Message de chargement
- ✅ Styles cohérents

---

### 8. **TermsCheckbox** (`terms_checkbox.dart`)
**Checkbox des conditions**

**Fonctionnalités :**
- ✅ Checkbox stylisée
- ✅ Lien vers les conditions
- ✅ Validation

---

### 9. **CountrySearchField** (`country_search_field.dart`)
**Champ de recherche de pays**

**Fonctionnalités :**
- ✅ Autocomplete
- ✅ Filtrage en temps réel

---

### 10. **CountryListTile** (`country_list_tile.dart`)
**Item de liste de pays**

**Fonctionnalités :**
- ✅ Drapeau
- ✅ Nom du pays
- ✅ Sélection visuelle

---

### 11. **OAuthHandler** (`oauth_handler.dart`)
**Gestion OAuth**

**Fonctionnalités :**
- ✅ WebView pour OAuth (mobile)
- ✅ Détection du callback
- ✅ Extraction des paramètres

---

## 🎨 Fonctionnalités détaillées

### 🔐 Authentification
1. **OAuth Social** (Google, Facebook)
   - Détection automatique mobile/web
   - Callback URL personnalisé
   - Redirection après connexion

2. **Magic Links (Email)**
   - Envoi de lien depuis l'écran login
   - Deep link `https://jirig.be/connexion?email=...&token=...`
   - Validation automatique du token
   - Android : Intent filter configuré
   - iOS : Universal Links configuré
   - Web : Routing GoRouter natif

3. **Profil invité**
   - Génération automatique d'un GuestProfile
   - Conversion en profil authentifié après login

---

### 🛒 Gestion du panier/wishlist
1. **Ajout de produits**
   - Depuis le podium (bouton cœur)
   - Sélection du pays
   - Quantité personnalisable

2. **Modification**
   - Augmenter/diminuer quantité
   - Suppression d'article

3. **Persistance**
   - Sauvegarde via API
   - iBasket crypté
   - Synchronisation automatique

4. **Calculs**
   - Total par article
   - Total général
   - Regroupement par pays

---

### 🌍 Multi-langue & Multi-pays
1. **Traductions dynamiques**
   - Chargement depuis API SNAL
   - 7 langues supportées
   - Changement à la volée

2. **Pays favoris**
   - Sélection multiple
   - Affichage avec drapeaux
   - Sauvegarde dans profil

3. **Pays principal**
   - Détermine la langue par défaut
   - Influence les résultats de recherche
   - Marqueur visuel 🏠 dans les résultats

---

### 📷 Scanner QR Code
1. **Technologie**
   - `mobile_scanner` package
   - Accès caméra avec permissions
   - Support Android/iOS uniquement (pas web)

2. **Algorithme de détection**
   - Multi-frame detection
   - Buffer de 10 dernières détections
   - Fenêtre de validation 1.5s
   - Seuil de confiance 60%
   - Minimum 2 détections identiques

3. **UX**
   - Zone de scan animée
   - Feedback visuel (couleurs selon état)
   - Feedback haptique
   - Feedback sonore
   - Tips d'aide contextuelle
   - Indicateur de qualité

---

### 🗺️ Carte (Future feature)
1. **Affichage des magasins IKEA**
2. **Localisation utilisateur**
3. **Itinéraire vers magasin**

---

### 📱 Responsive Design
1. **Breakpoints**
   - Très petit mobile : < 361px (Galaxy Fold)
   - Petit mobile : 361-430px (iPhone, Pixel)
   - Mobile standard : 431-767px
   - Tablette : 768-1023px
   - Desktop : 1024px+

2. **Adaptations**
   - Tailles de police
   - Padding et marges
   - Hauteurs de composants
   - Disposition des éléments
   - Navigation (bottom bar mobile, side bar desktop potentiel)

---

### 🔄 Navigation
1. **GoRouter**
   - Routes déclaratives
   - Deep linking natif
   - Paramètres d'URL
   - Query parameters
   - Transitions personnalisées

2. **Routes principales**
   - `/` → Splash
   - `/splash` → Splash
   - `/country-selection` → Sélection pays
   - `/home` → Accueil
   - `/product-search` ou `/product-code` → Recherche
   - `/podium/:code` → Comparaison prix
   - `/login` → Connexion
   - `/magic-login` → Validation magic link
   - `/oauth/callback` → Retour OAuth
   - `/wishlist` → Wishlist
   - `/profile` → Profil
   - `/profil` → Détails profil
   - `/subscription` → Abonnement

3. **Persistance**
   - Sauvegarde de la dernière route
   - Restauration au démarrage

---

### ⚡ Performance
1. **Optimisations**
   - Images en cache (`cached_network_image`)
   - Lazy loading des listes
   - Debouncing des recherches
   - Provider pour state management efficace

2. **Proxy web**
   - Serveur Node.js pour CORS
   - Cache des images
   - Compression

---

### 🐛 Debugging
1. **Logs structurés**
   - Émojis pour identification rapide
   - Séparation par service
   - Niveau de détail ajustable

2. **DevTools**
   - Inspection de l'état Provider
   - Logs réseau Dio
   - Analyse des performances

---

## 🛠️ Technologies utilisées

### Framework & Langage
- **Flutter** 3.9.2+
- **Dart** SDK ^3.9.2

### Packages principaux
- `go_router` ^14.2.7 - Navigation
- `provider` ^6.1.2 - State management
- `dio` ^5.4.3+1 - HTTP client
- `dio_cookie_manager` ^3.1.1 - Cookies (mobile)
- `cookie_jar` ^4.0.8 - Persistence cookies
- `shared_preferences` ^2.2.3 - Stockage local
- `uni_links` ^0.5.1 - Deep links (mobile)
- `mobile_scanner` ^5.0.0 - Scanner QR
- `permission_handler` ^11.3.1 - Permissions
- `webview_flutter` ^4.4.2 - OAuth WebView
- `cached_network_image` ^3.3.1 - Cache images
- `flutter_map` ^7.0.2 - Cartes
- `latlong2` ^0.9.1 - Coordonnées GPS
- `geolocator` ^13.0.2 - Localisation
- `loading_animation_widget` ^1.3.0 - Animations
- `page_transition` ^2.2.1 - Transitions
- `flutter_svg` ^2.0.10+1 - SVG
- `google_fonts` ^6.1.0 - Polices
- `intl` ^0.20.2 - Internationalisation
- `url_launcher` ^6.2.5 - Ouverture URLs
- `share_plus` ^10.0.2 - Partage
- `html` ^0.15.4 - Parsing HTML
- `uuid` ^4.4.0 - Génération UUID
- `path_provider` ^2.1.2 - Chemins système

### Backend
- **SNAL-Project** (Nuxt 3) - API REST
- **Node.js Proxy** - Contournement CORS pour web

---

## 📱 Plateformes supportées

### ✅ Mobile (Complet)
- **Android** 
  - Deep links configurés (AndroidManifest.xml)
  - Cookies natifs
  - Scanner QR fonctionnel
  - Permissions gérées
  
- **iOS**
  - Universal Links configurés
  - Cookies natifs
  - Scanner QR fonctionnel
  - Permissions gérées

### ✅ Web (Complet avec limitations)
- **Navigateurs modernes** (Chrome, Firefox, Safari, Edge)
  - Proxy pour CORS
  - Pas de scanner QR (limitation navigateur)
  - Deep links via routing GoRouter natif
  - Cookies gérés par le navigateur

### ⏳ Futures plateformes
- **macOS** - Structure déjà présente
- **Windows** - Structure déjà présente
- **Linux** - Structure déjà présente

---

## 🚀 Points forts du projet

1. **Architecture mobile-first robuste**
   - Détection automatique de plateforme
   - Adaptation intelligente (cookies, proxy, permissions)

2. **Expérience utilisateur soignée**
   - Animations fluides
   - Feedbacks visuels/haptiques/sonores
   - Messages d'erreur clairs
   - Design responsive

3. **Gestion d'état efficace**
   - Provider pour performance
   - Services singleton
   - Cache intelligent

4. **Internationalisation complète**
   - 7 langues
   - Traductions dynamiques
   - Fallback sûr

5. **Sécurité**
   - Tokens gérés proprement
   - iBasket crypté
   - Validation des entrées

6. **Code maintenable**
   - Séparation des responsabilités
   - Services réutilisables
   - Logs structurés
   - Documentation inline

---

## 📝 Notes importantes

1. **Deep Links**
   - Fonctionnent uniquement sur **mobile** (Android/iOS)
   - Sur **web**, GoRouter gère les URLs nativement
   - Configuration : `DEEP_LINKS_SETUP.md`

2. **Scanner QR**
   - Disponible **uniquement sur mobile**
   - Nécessite permissions caméra
   - Gestion des erreurs de permission

3. **Cookies**
   - Sur **mobile** : `PersistCookieJar` (Dio)
   - Sur **web** : gestion navigateur (automatique)
   - GuestProfile ajouté en header ET cookie

4. **Proxy Node.js**
   - Requis pour **web uniquement**
   - Contourne CORS pour images et API
   - Configuration : `proxy-server.js`

5. **État de développement**
   - Fonctionnel et stable
   - Prêt pour déploiement
   - Tests en cours

---

## 📚 Documentation associée

- `DEEP_LINKS_SETUP.md` - Configuration deep links
- `OAUTH_MOBILE_SOLUTION.md` - OAuth sur mobile
- `MAP_IMPLEMENTATION_COMPLETE.md` - Carte interactive
- `QR_SCANNER_FINAL_STATUS.md` - Scanner QR
- `WISHLIST_PERSISTENCE_GUIDE.md` - Wishlist
- `MOBILE_FIRST_SETUP.md` - Architecture mobile-first
- `API_SETUP.md` - Configuration API
- `ENDPOINTS.md` - Liste des endpoints
- `PERMISSIONS_GUIDE.md` - Permissions Android/iOS

---

**Date de dernière mise à jour** : 18 octobre 2025  
**Version Flutter** : 3.9.2  
**Plateforme cible principale** : Mobile (Android/iOS)  
**Support web** : Complet avec proxy Node.js

