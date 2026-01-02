# Analyse Complète des Projets podium_app et SNAL-Project

## 📊 Vue d'ensemble

### Architecture Générale

```
┌─────────────────────────────────────────────────────────────┐
│                    podium_app (Flutter)                      │
│  Application Mobile/Web - Frontend Client                   │
│  - Android, iOS, Web                                        │
│  - État: Provider                                           │
│  - Navigation: GoRouter                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ HTTPS / API Calls
                       │ Cookies (GuestProfile)
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              SNAL-Project (Nuxt 3)                          │
│  Backend API - Server-Side                                  │
│  - Nuxt 3 + Nitro                                           │
│  - API Routes (102 endpoints)                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Stored Procedures
                       │ XML Parameters
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              MSSQL Database                                 │
│  - Tables: sh_profile, sh_article, Baskets, etc.           │
│  - Stored Procedures (logique métier)                       │
│  - Logs: sh_debug_xml, SH_LOG                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 podium_app - Application Flutter

### Structure du Projet

```
podium_app/
├── lib/
│   ├── main.dart                    # Point d'entrée
│   ├── app.dart                     # Configuration app + routing
│   ├── config/
│   │   └── api_config.dart          # Configuration API (mobile-first)
│   ├── models/                      # Modèles de données
│   ├── screens/                      # 12 écrans
│   │   ├── splash_screen.dart
│   │   ├── country_selection_screen.dart
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── podium_screen.dart        # Comparaison de prix
│   │   ├── product_search_screen.dart
│   │   ├── wishlist_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── support_screen.dart
│   │   └── ...
│   ├── services/                     # 15 services
│   │   ├── api_service.dart         # Singleton - Gestion HTTP
│   │   ├── auth_notifier.dart       # État authentification
│   │   ├── country_notifier.dart    # État pays sélectionné
│   │   ├── translation_service.dart # i18n dynamique
│   │   ├── local_storage_service.dart
│   │   ├── profile_service.dart
│   │   └── ...
│   ├── widgets/                     # 14 widgets réutilisables
│   │   ├── bottom_navigation_bar.dart
│   │   ├── custom_app_bar.dart
│   │   ├── search_modal.dart
│   │   └── ...
│   └── utils/
└── assets/
    ├── images/
    ├── flags/
    └── icons/
```

### Technologies Clés

- **Framework** : Flutter 3.9.2+
- **State Management** : Provider
- **Navigation** : GoRouter 14.2.7
- **HTTP Client** : Dio 5.4.3 (mobile) / HTTP (web)
- **Cookies** : dio_cookie_manager + PersistCookieJar (mobile uniquement)
- **Local Storage** : SharedPreferences
- **Internationalisation** : 7 langues (fr, en, de, es, it, pt, nl)

### Architecture Mobile-First

#### Configuration API

```dart
// api_config.dart
- Mobile (Android/iOS): Appels directs à https://jirig.be/api
- Web: Proxy local http://localhost:3001/api (contourne CORS)
- Cookies: Gérés par CookieManager sur mobile, navigateur sur web
```

#### Gestion des Cookies

**Mobile** :
- `PersistCookieJar` sauvegarde les cookies sur disque
- `CookieManager` intercepte automatiquement les requêtes
- Cookies stockés dans `ApplicationDocumentsDirectory/.cookies/`

**Web** :
- Le navigateur gère les cookies automatiquement
- Pas de CookieManager nécessaire

#### GuestProfile System

Le système utilise un cookie/header `GuestProfile` pour identifier les utilisateurs non connectés :

```dart
{
  "iProfile": "123456",
  "iBasket": "789012",
  "sPaysLangue": "BE",
  "sPaysFav": "FR,DE,NL"
}
```

- Créé lors de l'initialisation (`/api/auth/init`)
- Envoyé dans chaque requête (header `X-Guest-Profile` + cookie)
- Permet de suivre les utilisateurs même sans connexion

### Flux d'Authentification

#### 1. Initialisation (Premier Lancement)

```
1. App démarre → SplashScreen
2. Vérifie localStorage pour profil existant
3. Si pas de profil → CountrySelectionScreen
4. Utilisateur sélectionne pays → POST /api/auth/init
5. Backend crée iProfile + iBasket via proc_create_ProfileAndBasket
6. Profil stocké dans localStorage + cookie GuestProfile
7. Redirection vers HomeScreen
```

#### 2. Connexion OAuth (Google/Facebook)

```
1. Utilisateur clique "Se connecter avec Google"
2. OAuthMobileHandler gère le deep link
3. Redirection vers SNAL → /api/auth/google
4. SNAL valide le token OAuth
5. Appelle proc_user_signup_4All_user_v2
6. Crée/met à jour le profil
7. Retourne iProfile, iBasket, etc.
8. podium_app met à jour localStorage + session
9. Redirection vers wishlist
```

#### 3. Connexion par Code Email

```
1. Utilisateur entre son email
2. POST /api/auth/login
3. Backend génère un code magique
4. Email envoyé avec lien de connexion
5. Utilisateur clique le lien → validation du code
6. Session créée
```

### Services Principaux

#### ApiService (Singleton)

```dart
- Instance unique pour toute l'application
- Gestion automatique des cookies (mobile)
- Intercepteurs pour logs et GuestProfile
- Gestion des erreurs centralisée
- Retry automatique sur erreurs réseau
```

**Fonctionnalités** :
- ✅ Gestion des cookies persistants (mobile)
- ✅ Ajout automatique du GuestProfile dans les headers
- ✅ Logs détaillés pour debug
- ✅ Gestion des timeouts
- ✅ Retry sur erreurs réseau

#### TranslationService

```dart
- Récupère les traductions depuis /api/translations/[lang]
- Cache les traductions en mémoire
- Support de 7 langues
- Fallback sur traductions par défaut
```

#### LocalStorageService

```dart
- Stocke le profil utilisateur
- Stocke les préférences (pays, langue)
- Stocke l'état de connexion
- Synchronisation avec les cookies backend
```

### Écrans Principaux

#### HomeScreen
- Point d'entrée après connexion
- Modules : Scanner QR, Upload PDF, Comparaison
- Animations échelonnées
- Vérification OAuth callbacks

#### PodiumScreen
- Affiche la comparaison de prix d'un produit
- Prix par pays sélectionnés
- Animations "Explosion & Reveal"
- Gestion des erreurs d'authentification

#### LoginScreen
- Connexion email/code
- OAuth Google/Facebook
- Gestion des callbacks
- Redirections après connexion

---

## 🖥️ SNAL-Project - Backend Nuxt 3

### Structure du Projet

```
SNAL-Project/
├── app/
│   ├── app.vue                    # Layout principal
│   ├── components/                # 27 composants Vue
│   ├── composables/               # 47 composables
│   │   ├── useAppCookies.ts      # Gestion cookies
│   │   ├── useInfoUser.ts        # Infos utilisateur
│   │   └── ...
│   ├── layouts/                   # 3 layouts
│   ├── middleware/                # Middleware auth
│   └── pages/                     # 43 pages
│       ├── index.vue              # Page d'accueil
│       ├── connexion.vue         # Page de connexion
│       ├── podium/[icode].vue    # Page podium
│       └── ...
├── server/
│   ├── api/                       # 102 endpoints API
│   │   ├── auth/                 # Authentification
│   │   │   ├── init.post.ts      # Initialisation profil
│   │   │   ├── login.post.ts    # Connexion email
│   │   │   ├── google.get.ts    # OAuth Google
│   │   │   ├── facebook.get.ts  # OAuth Facebook
│   │   │   └── ...
│   │   ├── search-article.get.ts
│   │   ├── comparaison-by-code.js
│   │   ├── contact.post.ts
│   │   ├── create-checkout-session.post.ts
│   │   ├── stripe-webhook.post.ts
│   │   └── ...
│   └── db/
│       └── index.ts               # Connexion MSSQL
├── public/
│   └── img/                       # Assets statiques
└── nuxt.config.ts                 # Configuration Nuxt
```

### Philosophie Architecture

#### Principe : Logique Métier dans la Base de Données

```
┌─────────────────────────────────────────┐
│  Frontend (Nuxt/podium_app)             │
│  - Validation basique                   │
│  - Formatage des données                │
└──────────────┬──────────────────────────┘
               │
               │ XML Parameters
               │
┌──────────────▼──────────────────────────┐
│  API Endpoints (Nitro)                  │
│  - Validation des entrées               │
│  - Construction XML                     │
│  - Appel stored procedures               │
└──────────────┬──────────────────────────┘
               │
               │ EXECUTE stored_procedure
               │
┌──────────────▼──────────────────────────┐
│  Stored Procedures (MSSQL)              │
│  - TOUTE la logique métier              │
│  - Validation complète                  │
│  - Transactions                         │
│  - Logs automatiques                    │
└─────────────────────────────────────────┘
```

### Pattern des Stored Procedures

Toutes les stored procedures suivent le même template :

```sql
CREATE PROCEDURE [dbo].[proc_name] @xXml XML AS BEGIN
    SET NOCOUNT ON;
    DECLARE @sCurrProcName VARCHAR(MAX) = OBJECT_NAME(@@PROCID)
    DECLARE @sResult VARCHAR(MAX) = ''
    
    BEGIN TRY
        -- 1. Logs
        INSERT INTO sh_debug_xml (xXml) VALUES (@xXml)
        INSERT INTO SH_LOG (sLogName, sDescr, dDateLog, ...)
        
        -- 2. Extraction XML
        SET @iProfile = @xXml.value('(/root/iProfile)[1]', 'NUMERIC')
        
        -- 3. Logique métier
        ...
        
        -- 4. Retour résultat
        SELECT @sResult AS sResult, 'SUCCESS' AS sStatus
    END TRY
    BEGIN CATCH
        -- Gestion erreurs
        SET @sResult = 'ERROR: ' + ERROR_MESSAGE()
        INSERT INTO SH_LOG (...)
        THROW
    END CATCH
END
```

### Stored Procedures Principales

#### Authentification
- `proc_create_ProfileAndBasket` : Crée un profil invité + panier
- `proc_user_signup_4All_user_v2` : Crée/met à jour un utilisateur (OAuth)

#### Produits
- `proc_article_searchlist` : Recherche d'articles
- `proc_return_comparaison` : Comparaison de prix par pays

#### Paniers (Baskets)
- `Proc_PickingList_Actions` : Actions sur les paniers (CRUD)
- `proc_basket_list_by_user` : Liste des paniers d'un utilisateur
- `proc_baskets_dtl_deleteArticle` : Suppression d'article

#### Paiements
- `proc_create_checkout_session` : Crée une session Stripe
- `proc_payment_process` : Traite les paiements/abonnements

#### Autres
- `proc_translations_getByLanguage_V2` : Traductions
- `proc_faq_list_AnswerResponse` : FAQ
- `proc_ikea_storeMap_getList` : Magasins IKEA
- `proc_send_contact_message` : Messages de support

### Tables Principales

#### sh_profile
```sql
- iProfile (PK) : Identifiant utilisateur
- sEmail : Email
- sNom, sPrenom : Nom et prénom
- sTypeAccount : Type de compte (EMAIL, ABONNE, etc.)
- sProvider : Provider OAuth (google, facebook, apple)
- sProviderId : ID du provider
- iBasket : Panier principal
- sPaysLangue : Pays de langue
- sPaysFav : Pays favoris (JSON)
```

#### Baskets
```sql
- iBasket (PK) : Identifiant panier
- iProfile (FK) : Propriétaire
- sBasketName : Nom du panier
- dCreate : Date création
```

#### Baskets_Dtl
```sql
- iBasket (FK) : Panier
- iSuite : Numéro de ligne
- sCodeArticle : Code article IKEA
- iQteOriginal, iQte : Quantités
- iPrixOriginal : Prix original
- iPaysSelected : Pays sélectionné
```

#### sh_article
```sql
- sCodeArticle : Code article IKEA
- iPays : Pays
- sName : Nom produit
- iPrix : Prix
- sDescr : Description
```

#### sh_params
```sql
- sKey : Clé de configuration
- sValue : Valeur (JSON souvent)
- Exemples: PAYMENT_GATEWAY_TYPE, SUBSCRIPTION_PLAN_MONTHLY
```

#### sh_status
```sql
- iStatus : Code statut
- sType : Type (PAYS, PAYMENT_STATUS, etc.)
- sDescr : Description
```

#### Tables de Logs
- `sh_debug_xml` : Stocke tous les XML envoyés aux procedures
- `SH_LOG` : Logs d'exécution des procedures

### Endpoints API Principaux

#### Authentification
- `POST /api/auth/init` : Initialise un profil invité
- `POST /api/auth/login` : Connexion email/code
- `GET /api/auth/google` : OAuth Google
- `GET /api/auth/facebook` : OAuth Facebook
- `POST /api/auth/disconnect` : Déconnexion

#### Produits
- `GET /api/search-article` : Recherche d'articles
- `GET /api/comparaison-by-code` : Comparaison de prix

#### Paniers
- `GET /api/get-basket-user` : Liste des paniers
- `GET /api/get-basket-list-article` : Articles d'un panier
- `POST /api/add-article-basket` : Ajouter un article
- `POST /api/update-quantity-articleBasket` : Modifier quantité
- `DELETE /api/delete-article-basket-dtl` : Supprimer article

#### Wishlists
- `GET /api/get-wishlist-by-profil` : Liste des wishlists
- `POST /api/add-product-to-wishlist` : Ajouter à wishlist

#### Profil
- `GET /api/get-info-profil` : Infos profil
- `PUT /api/update-info-profil/[iprofile]` : Mettre à jour profil

#### Paiements
- `POST /api/create-checkout-session` : Créer session Stripe
- `POST /api/stripe-webhook` : Webhook Stripe
- `GET /api/subscription/get-user-subscription` : Abonnement utilisateur

#### Autres
- `GET /api/translations/[lang]` : Traductions
- `GET /api/get-faq-list-question` : FAQ
- `GET /api/get-ikea-store-list` : Magasins IKEA
- `POST /api/contact` : Message de support

### Gestion des Cookies

#### GuestProfile Cookie

```typescript
// Format
{
  iProfile: "123456",
  iBasket: "789012",
  sPaysLangue: "BE",
  sPaysFav: "FR,DE,NL"
}

// Utilisation
- Créé lors de /api/auth/init
- Mis à jour lors de connexion
- Envoyé dans chaque requête
- Permet de suivre les utilisateurs non connectés
```

#### Session Cookie

```typescript
// Créé lors de la connexion
- Stocke les infos utilisateur
- Géré par nuxt-auth-utils
- HttpOnly, Secure, SameSite=Lax
```

### Intégrations Externes

#### Stripe
- Paiements uniques
- Abonnements récurrents
- Webhooks pour événements

#### Mailjet
- Envoi d'emails (newsletter, codes magiques)
- Gestion des listes de contacts

#### AWS S3
- Stockage des PDF uploadés
- Génération de PDF pour paniers

#### Google OAuth
- Connexion avec compte Google
- Handler natif dans nuxt-auth-utils

#### Facebook OAuth
- Connexion avec compte Facebook
- Handler natif dans nuxt-auth-utils

---

## 🔄 Flux de Données

### 1. Recherche et Comparaison de Prix

```
1. podium_app : Utilisateur recherche un code article
2. POST /api/search-article
   - Headers: GuestProfile cookie
   - Body: { code: "123.456.78" }
3. SNAL : Valide, construit XML
4. EXECUTE proc_article_searchlist @xXml
5. Retourne liste d'articles avec prix par pays
6. podium_app : Affiche les résultats
7. Utilisateur clique sur un article
8. GET /api/comparaison-by-code?code=123.456.78
9. EXECUTE proc_return_comparaison @xXml
10. Retourne comparaison détaillée
11. podium_app : Affiche PodiumScreen avec comparaison
```

### 2. Ajout au Panier

```
1. podium_app : Utilisateur ajoute un article au panier
2. POST /api/add-article-basket
   - Headers: GuestProfile cookie
   - Body: { codeArticle, quantity, paysSelected }
3. SNAL : Extrait iProfile depuis cookie
4. Construit XML avec iProfile, iBasket, article
5. EXECUTE Proc_PickingList_Actions @xXml
6. Stored procedure :
   - Vérifie si article existe déjà
   - Ajoute ou met à jour la quantité
   - Calcule les prix
   - Retourne le panier mis à jour
7. SNAL : Retourne JSON avec panier
8. podium_app : Met à jour l'affichage
```

### 3. Connexion OAuth

```
1. podium_app : Utilisateur clique "Se connecter avec Google"
2. OAuthMobileHandler ouvre WebView/Deep Link
3. Redirection vers SNAL : /api/auth/google
4. SNAL : nuxt-auth-utils gère le flux OAuth
5. Google retourne le token
6. SNAL : Récupère les infos utilisateur depuis Google
7. Construit XML :
   <root>
     <email>user@gmail.com</email>
     <sProvider>google</sProvider>
     <sProviderId>google_user_id</sProviderId>
     <nom>Doe</nom>
     <prenom>John</prenom>
   </root>
8. EXECUTE proc_user_signup_4All_user_v2 @xXml
9. Stored procedure :
   - Cherche si utilisateur existe (par email ou sProviderId)
   - Crée ou met à jour le profil
   - Crée le panier si nécessaire
   - Retourne iProfile, iBasket, etc.
10. SNAL : Crée la session
11. SNAL : Met à jour le cookie GuestProfile
12. SNAL : Redirige vers /wishlist/[iBasket]
13. podium_app : Reçoit la redirection
14. podium_app : Met à jour localStorage
15. podium_app : Affiche la wishlist
```

### 4. Paiement Stripe

```
1. podium_app : Utilisateur clique "S'abonner"
2. POST /api/create-checkout-session
   - Body: { paymentType: "subscription", planKey: "MONTHLY" }
3. SNAL : Récupère les infos du plan depuis sh_params
4. EXECUTE proc_create_checkout_session @xXml
5. Stored procedure : Valide et prépare la session
6. SNAL : Crée la session Stripe
7. Retourne { id: "cs_..." }
8. podium_app : Redirige vers Stripe Checkout
9. Utilisateur paie
10. Stripe : Envoie webhook à /api/stripe-webhook
11. SNAL : Valide le webhook
12. EXECUTE proc_payment_process @xXml
13. Stored procedure :
    - Enregistre le paiement dans sh_payments
    - Crée l'abonnement dans sh_subscriptions
    - Met à jour sTypeAccount dans sh_profile
14. SNAL : Retourne 200 OK à Stripe
```

---

## 🔐 Sécurité

### Authentification

- **Sessions** : Gérées par nuxt-auth-utils
- **Cookies** : HttpOnly, Secure, SameSite=Lax
- **OAuth** : Validation des tokens côté serveur
- **Codes magiques** : Générés aléatoirement, expiration

### Validation

- **Côté client** : Validation basique (format email, champs requis)
- **Côté serveur** : Validation complète dans les stored procedures
- **XML** : Échappement des caractères dangereux

### Données Sensibles

- **Clés API** : Variables d'environnement
- **Secrets** : Jamais dans le code source
- **Cookies** : Chiffrés pour les sessions

---

## 📱 Support Multi-Plateforme

### podium_app

- ✅ **Android** : App native
- ✅ **iOS** : App native
- ✅ **Web** : Via proxy local (développement)

### SNAL-Project

- ✅ **Web** : Application Nuxt 3 (SSR)
- ✅ **API** : Endpoints REST pour mobile

---

## 🌍 Internationalisation

### Langues Supportées

- Français (fr) - Par défaut
- Anglais (en)
- Allemand (de)
- Espagnol (es)
- Italien (it)
- Portugais (pt)
- Néerlandais (nl)

### Système de Traduction

- **Backend** : `proc_translations_getByLanguage_V2`
- **Frontend** : Cache des traductions
- **Format** : JSON avec clés `MSG_ID`

---

## 💾 Stockage

### podium_app

- **LocalStorage** : SharedPreferences
  - Profil utilisateur
  - Préférences (pays, langue)
  - État de connexion
- **Cookies** : PersistCookieJar (mobile uniquement)

### SNAL-Project

- **Base de données** : MSSQL Server
- **Fichiers** : AWS S3 (PDF)
- **Sessions** : Cookies (nuxt-auth-utils)

---

## 🚀 Déploiement

### podium_app

- **Android** : APK/AAB via Flutter build
- **iOS** : IPA via Xcode
- **Web** : Build Flutter web (via proxy)

### SNAL-Project

- **Production** : `https://jirig.be` et `https://jirig.com`
- **Docker** : `docker-compose.yml` disponible
- **Base de données** : MSSQL Server (container ou serveur dédié)

---

## 📊 Statistiques

### podium_app
- **12 écrans**
- **15 services**
- **14 widgets**
- **7 langues**

### SNAL-Project
- **102 endpoints API**
- **27 composants Vue**
- **47 composables**
- **43 pages**
- **~30+ stored procedures**

---

## 🔗 Points d'Intégration Clés

1. **GuestProfile** : Système de cookies partagé
2. **Stored Procedures** : Logique métier centralisée
3. **XML** : Format de communication standardisé
4. **Logs** : Traçabilité complète (sh_debug_xml, SH_LOG)
5. **OAuth** : Flux unifié pour Google/Facebook/Apple

---

## 🎯 Points Forts de l'Architecture

1. ✅ **Séparation des responsabilités** : Logique métier dans la DB
2. ✅ **Réutilisabilité** : Stored procedures multi-usages
3. ✅ **Traçabilité** : Logs automatiques
4. ✅ **Mobile-First** : Optimisé pour mobile
5. ✅ **Scalabilité** : Architecture modulaire
6. ✅ **Maintenabilité** : Code structuré et documenté

---

## ⚠️ Points d'Attention

1. **Dépendance à la DB** : Toute la logique dans les stored procedures
2. **XML** : Format verbeux mais standardisé
3. **Cookies** : Gestion complexe multi-plateforme
4. **OAuth** : Différents flux selon le provider
5. **Proxy Web** : Nécessaire pour développement web

---

## 📚 Documentation Disponible

- `SUPPORT_BACKEND_IMPLEMENTATION.md` : Guide support
- `APPLE_SIGNIN_BACKEND_IMPLEMENTATION.md` : Guide Apple Sign In
- `PAYMENT_INTEGRATION_README.md` : Guide paiements
- `.github/instructions/snal.instructions.md` : Règles architecture

---

## 🔄 Workflow de Développement

### Ajouter une Nouvelle Fonctionnalité

1. **Backend (SNAL-Project)** :
   - Créer/modifier stored procedure selon template
   - Créer endpoint API dans `server/api/`
   - Tester avec curl/Postman

2. **Frontend (podium_app)** :
   - Ajouter méthode dans `ApiService`
   - Créer/modifier écran si nécessaire
   - Tester sur mobile et web

3. **Tests** :
   - Vérifier les logs dans `sh_debug_xml`
   - Vérifier les logs dans `SH_LOG`
   - Tester les cas d'erreur

---

## 🎓 Conclusion

L'architecture est bien structurée avec une séparation claire entre :
- **Frontend** (podium_app) : Interface utilisateur, gestion d'état
- **Backend** (SNAL-Project) : API, validation, formatage
- **Database** : Logique métier, transactions, logs

Le système est **mobile-first**, **scalable** et **maintenable** grâce à :
- Stored procedures réutilisables
- Système de logs complet
- Gestion unifiée des utilisateurs (connectés et invités)
- Support multi-plateforme

