# 📋 Guide de Persistance de la Wishlist - Jirig Flutter App

## 🎯 Vue d'ensemble

Ce document explique comment fonctionne la **persistance des articles** dans la wishlist de l'application Jirig Flutter, garantissant que les articles ajoutés restent disponibles même après la fermeture et la réouverture de l'application.

---

## 🔄 Flux de données complet

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUX DE PERSISTANCE                          │
└─────────────────────────────────────────────────────────────────┘

1. INITIALISATION (app.dart)
   ├─> LocalStorage vide ?
   ├─> Appel API: /api/auth/init
   ├─> Récupération: iProfile, iBasket, sPaysLangue, sPaysFav
   └─> Sauvegarde dans SharedPreferences

2. RECHERCHE PRODUIT (search_modal.dart)
   ├─> Utilisateur cherche un produit
   ├─> Appel API: /api/search-article
   └─> Navigation vers PodiumScreen

3. AJOUT À LA WISHLIST (podium_screen.dart)
   ├─> Utilisateur clique sur "Ajouter au panier"
   ├─> Appel API: /api/add-product-to-wishlist
   │   └─> Envoi: sCodeArticle, sPays, iPrice, iQuantity, 
   │       currentIBasket, iProfile, sPaysLangue, sPaysFav
   ├─> Réponse API contient: nouveau iBasket
   ├─> Sauvegarde du nouveau iBasket dans SharedPreferences
   └─> Redirection vers /wishlist

4. AFFICHAGE WISHLIST (wishlist_screen.dart)
   ├─> Récupération du profil depuis SharedPreferences
   ├─> Appel API: /api/get-basket-list-article
   │   └─> Envoi: iProfile, iBasket, sAction=INIT, sPaysFav
   ├─> Affichage des articles
   └─> Si iBasket retourné, mise à jour dans SharedPreferences

5. RECHARGEMENT AUTOMATIQUE
   ├─> WidgetsBindingObserver détecte AppLifecycleState.resumed
   ├─> Rechargement automatique de _loadWishlistData()
   └─> Les articles ajoutés apparaissent
```

---

## 🗄️ Structure de données LocalStorage

### **Clés stockées dans SharedPreferences**

```dart
{
  'iProfile': '12345',           // ID du profil utilisateur
  'iBasket': 'ABC123XYZ',        // ID crypté du panier actuel
  'sPaysLangue': 'FR/FR',        // Langue et pays (ex: FR/FR, BE/BE)
  'sPaysFav': 'FR,BE,NL,DE',     // Pays favoris (max 3-5 pays)
}
```

### **Services de stockage**

| Fichier | Méthode | Description |
|---------|---------|-------------|
| `local_storage_service.dart` | `saveProfile()` | Sauvegarde `iProfile`, `iBasket`, `sPaysLangue`, `sPaysFav` |
| `local_storage_service.dart` | `getProfile()` | Récupère les données du profil |
| `local_storage_service.dart` | `clearProfile()` | Efface toutes les données du profil |

---

## 🔧 Composants clés

### **1. WishlistScreen (wishlist_screen.dart)**

#### **Mixins utilisés**

```dart
class _WishlistScreenState extends State<WishlistScreen> 
    with RouteTracker, WidgetsBindingObserver {
  // ...
}
```

- **`RouteTracker`** : Suit les changements de route pour la persistance
- **`WidgetsBindingObserver`** : Observe le cycle de vie de l'application

#### **Cycle de vie**

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);  // ✅ Enregistrer l'observateur
  _loadWishlistData();                        // ✅ Charger les données initiales
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this); // ✅ Nettoyer l'observateur
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  // ✅ Recharger quand l'app revient au foreground
  if (state == AppLifecycleState.resumed && _hasLoaded) {
    print('🔄 App resumed - Rechargement de la wishlist...');
    _loadWishlistData();
  }
}
```

#### **Méthode de chargement**

```dart
Future<void> _loadWishlistData() async {
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // 1️⃣ Récupérer le profil depuis SharedPreferences
    final profileData = await LocalStorageService.getProfile();
    
    print('🔄 === RECHARGEMENT WISHLIST ===');
    print('📋 iProfile: ${profileData?['iProfile']}');
    print('📋 iBasket: ${profileData?['iBasket']}');
    print('📋 sPaysFav: ${profileData?['sPaysFav']}');
    
    // 2️⃣ Vérifier la validité du profil
    if (profileData == null || profileData['iProfile'] == null) {
      await _createGuestProfile();  // Profil vide si non initialisé
      return;
    }

    // 3️⃣ Charger les articles avec le profil existant
    final iProfile = profileData['iProfile'].toString();
    await _loadWishlistWithProfile(iProfile);
  } catch (e) {
    print('❌ Erreur _loadWishlistData: $e');
    setState(() {
      _isLoading = false;
      _errorMessage = 'Erreur lors du chargement de la wishlist: $e';
    });
  }
}
```

---

### **2. PodiumScreen (podium_screen.dart)**

#### **Ajout au panier**

```dart
Future<void> _addToCart(Map<String, dynamic> country) async {
  try {
    // 1️⃣ Récupérer le profil actuel
    final profileData = await LocalStorageService.getProfile();
    final iProfile = profileData['iProfile'];
    final iBasket = profileData['iBasket'] ?? '';
    
    // 2️⃣ Préparer les données de l'article
    final sCodeArticle = _productData!['sCodeArticleCrypt'] ?? '';
    final sPays = country['sLangueIso'] ?? country['sPays'] ?? '';
    final iPrice = _extractPrice(country['sPrice'] ?? '');
    
    // 3️⃣ Appeler l'API pour ajouter l'article
    final result = await _apiService.addToWishlist(
      sCodeArticle: sCodeArticle,
      sPays: sPays,
      iPrice: iPrice,
      iQuantity: _currentQuantity,
      currentIBasket: iBasket,
      iProfile: iProfile.toString(),
      sPaysLangue: profileData['sPaysLangue'] ?? 'FR/FR',
      sPaysFav: profileData['sPaysFav'] ?? '',
    );

    // 4️⃣ Sauvegarder le NOUVEAU iBasket retourné par l'API
    if (result != null && result['success'] == true) {
      if (result['data'] != null && result['data'].isNotEmpty) {
        final newIBasket = result['data'][0]['iBasket']?.toString();
        if (newIBasket != null && newIBasket.isNotEmpty) {
          await LocalStorageService.saveProfile(
            iProfile: iProfile.toString(),
            iBasket: newIBasket,  // ✅ IMPORTANT : Sauvegarder le nouveau iBasket
            sPaysLangue: profileData['sPaysLangue'] ?? '',
            sPaysFav: profileData['sPaysFav'] ?? '',
          );
          print('💾 Nouveau iBasket sauvegardé: $newIBasket');
        }
      }
      
      // 5️⃣ Redirection immédiate vers la wishlist
      if (mounted) {
        replaceWithRouteTracking('/wishlist');
      }
    }
  } catch (e) {
    print('Erreur _addToCart: $e');
  }
}
```

---

### **3. APIService (api_service.dart)**

#### **Endpoint : addToWishlist**

```dart
Future<Map<String, dynamic>?> addToWishlist({
  required String sCodeArticle,
  required String sPays,
  required double iPrice,
  required int iQuantity,
  required String currentIBasket,
  required String iProfile,
  String? sPaysLangue,
  String? sPaysFav,
}) async {
  try {
    final response = await _dio.post(
      '/api/add-product-to-wishlist',
      data: {
        'sCodeArticleCrypt': sCodeArticle,
        'sPays': sPays,
        'iPrice': iPrice,
        'iQte': iQuantity,
        'iBasket': currentIBasket,
        'iProfile': iProfile,
        'sPaysLangue': sPaysLangue ?? 'FR/FR',
        'sPaysFav': sPaysFav ?? '',
      },
    );

    print('✅ Réponse add-product-to-wishlist: ${response.data}');
    return response.data;
  } catch (e) {
    print('❌ Erreur addToWishlist: $e');
    return null;
  }
}
```

#### **Endpoint : getBasketListArticle**

```dart
Future<Map<String, dynamic>?> getBasketListArticle({
  required String iProfile,
  required String iBasket,
  required String sAction,
  String? sPaysFav,
}) async {
  try {
    final response = await _dio.get(
      '/api/get-basket-list-article',
      queryParameters: {
        'iProfile': iProfile,
        'iBasket': iBasket,
        'sAction': sAction,  // 'INIT' pour le chargement initial
        'sPaysFav': sPaysFav ?? '',
      },
    );

    print('✅ Réponse get-basket-list-article: ${response.data}');
    return response.data;
  } catch (e) {
    print('❌ Erreur getBasketListArticle: $e');
    return null;
  }
}
```

---

## 🔐 Proxy Server (proxy-server.js)

### **Middleware pour /api/add-product-to-wishlist**

```javascript
app.post('/api/add-product-to-wishlist', async (req, res) => {
  try {
    const { iProfile, iBasket, sPaysLangue, sPaysFav } = req.body;
    
    // ✅ Construire le cookie GuestProfile
    const guestProfile = `iProfile=${iProfile}&iBasket=${iBasket}&sPaysLangue=${sPaysLangue}&sPaysFav=${sPaysFav}`;
    
    // ✅ Appeler SNAL-Project avec le cookie
    const response = await fetch('https://jirig.be/api/add-product-to-wishlist', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': `GuestProfile=${guestProfile}`,
      },
      body: JSON.stringify(req.body),
    });
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('❌ Erreur add-product-to-wishlist:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
```

### **Middleware pour /api/get-basket-list-article**

```javascript
app.get('/api/get-basket-list-article', async (req, res) => {
  try {
    const { iProfile, iBasket, sAction, sPaysFav } = req.query;
    
    // ✅ Construire le cookie GuestProfile
    const guestProfile = `iProfile=${iProfile}&iBasket=${iBasket}&sPaysFav=${sPaysFav}`;
    
    // ✅ Appeler SNAL-Project avec le cookie ET les paramètres URL
    const url = `https://jirig.be/api/get-basket-list-article?iProfile=${iProfile}&iBasket=${iBasket}&sAction=${sAction}`;
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Cookie': `GuestProfile=${guestProfile}`,
      },
    });
    
    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('❌ Erreur get-basket-list-article:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
```

---

## 🧪 Debugging et Logs

### **Logs clés à surveiller**

#### **Initialisation**
```
✅ Profil initialisé: { iProfile: 12345, iBasket: ABC123, ... }
💾 Profil sauvegardé dans LocalStorage
```

#### **Ajout d'article**
```
🛒 Ajout au panier - sPays: BE, iPrice: 9.99
✅ Résultat addToWishlist: { success: true, data: [{ iBasket: 'XYZ456' }] }
💾 Nouveau iBasket sauvegardé: XYZ456
```

#### **Chargement wishlist**
```
🔄 === RECHARGEMENT WISHLIST ===
📋 iProfile: 12345
📋 iBasket: XYZ456
📋 sPaysFav: FR,BE,NL
📦 Chargement des articles - iProfile: 12345, iBasket: XYZ456
✅ Articles chargés: 3
```

#### **Cycle de vie**
```
🔄 App resumed - Rechargement de la wishlist...
```

---

## 🎨 Interface Utilisateur

### **Bouton de rafraîchissement manuel**

Un bouton bleu avec l'icône `refresh` a été ajouté dans la barre d'actions de la wishlist :

```dart
_buildCircleButton(Icons.refresh, const Color(0xFF0D6EFD), onTap: () {
  print('🔄 Rafraîchissement manuel de la wishlist...');
  _loadWishlistData();
}),
```

**Utilisation** :
- Appuyez sur ce bouton pour forcer le rechargement de la wishlist
- Utile si les articles ne s'affichent pas immédiatement

---

## ⚠️ Points d'attention

### **1. iBasket est crypté**
Le `iBasket` retourné par l'API est une **chaîne cryptée** qui doit être sauvegardée et réutilisée telle quelle :
```dart
// ❌ INCORRECT - Ne pas modifier iBasket
final iBasket = result['data'][0]['iBasket'].toString().toUpperCase();

// ✅ CORRECT - Utiliser tel quel
final iBasket = result['data'][0]['iBasket']?.toString();
```

### **2. Mise à jour du iBasket après chaque ajout**
Chaque fois qu'un article est ajouté, l'API retourne un **nouveau iBasket** qui **DOIT** être sauvegardé :
```dart
// ✅ IMPORTANT : Toujours sauvegarder le nouveau iBasket
await LocalStorageService.saveProfile(
  iProfile: iProfile.toString(),
  iBasket: newIBasket,  // ← Nouveau iBasket de la réponse API
  sPaysLangue: profileData['sPaysLangue'] ?? '',
  sPaysFav: profileData['sPaysFav'] ?? '',
);
```

### **3. sPaysFav ne doit PAS commencer par une virgule**
Le format correct est : `FR,BE,NL` (sans virgule au début)
```dart
// ❌ INCORRECT
final sPaysFav = ',FR,BE,NL';

// ✅ CORRECT
final sPaysFav = 'FR,BE,NL';
```

### **4. Rechargement automatique**
Le `WidgetsBindingObserver` détecte uniquement le retour au foreground. Pour les navigations internes, le `RefreshIndicator` (pull-to-refresh) est disponible.

---

## 📱 Scénarios d'utilisation

### **Scénario 1 : Premier lancement**
```
1. Utilisateur ouvre l'app pour la première fois
2. app.dart appelle /api/auth/init
3. iProfile et iBasket initiaux sont sauvegardés
4. Wishlist est vide (0 articles)
```

### **Scénario 2 : Ajout d'un article**
```
1. Utilisateur recherche un produit
2. Utilisateur clique sur "Ajouter au panier" depuis le podium
3. API retourne nouveau iBasket
4. Nouveau iBasket est sauvegardé
5. Redirection vers /wishlist
6. Article apparaît dans la wishlist
```

### **Scénario 3 : Fermeture et réouverture**
```
1. Utilisateur ferme l'app
2. iProfile et iBasket restent dans SharedPreferences
3. Utilisateur rouvre l'app
4. WidgetsBindingObserver détecte AppLifecycleState.resumed
5. _loadWishlistData() est appelé automatiquement
6. Articles sont rechargés depuis l'API avec le iBasket sauvegardé
7. Articles précédemment ajoutés apparaissent
```

### **Scénario 4 : Rafraîchissement manuel**
```
1. Utilisateur est sur la page wishlist
2. Utilisateur appuie sur le bouton refresh (bleu)
3. _loadWishlistData() est appelé manuellement
4. Articles sont rechargés
```

---

## 🛠️ Dépannage

### **Problème : Les articles n'apparaissent pas après ajout**

**Solutions :**
1. Vérifier que le `iBasket` est bien sauvegardé après l'ajout
2. Vérifier les logs dans la console :
   ```
   💾 Nouveau iBasket sauvegardé: [valeur]
   ```
3. Utiliser le bouton refresh manuel
4. Vérifier que `WidgetsBindingObserver` est bien enregistré

### **Problème : Les articles disparaissent après fermeture**

**Solutions :**
1. Vérifier que `SharedPreferences` fonctionne correctement
2. Tester manuellement :
   ```dart
   final profile = await LocalStorageService.getProfile();
   print('Profile sauvegardé: $profile');
   ```
3. Vérifier que `iBasket` n'est pas vide ou null

### **Problème : Erreur "Field 'Pivot' not found"**

**Solutions :**
1. Vérifier que `sPaysFav` est bien passé à l'API
2. Vérifier le format de `sPaysFav` : `FR,BE,NL` (pas de virgule au début)
3. Vérifier les logs du proxy-server.js

---

## 📊 Architecture finale

```
┌─────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE GLOBALE                      │
└─────────────────────────────────────────────────────────────┘

Flutter App                  Proxy Server              SNAL API
┌──────────┐                ┌──────────┐              ┌────────┐
│          │                │          │              │        │
│  App.dart│───init────────>│  Proxy   │────────────> │  Init  │
│          │<──iBasket──────│          │<────────────│        │
│          │                │          │              │        │
│  Podium  │───add─────────>│  Proxy   │────────────> │  Add   │
│  Screen  │<──newBasket────│          │<────────────│        │
│          │                │          │              │        │
│ Wishlist │───get─────────>│  Proxy   │────────────> │  Get   │
│  Screen  │<──articles─────│          │<────────────│        │
│          │                │          │              │        │
└────┬─────┘                └──────────┘              └────────┘
     │
     ▼
┌──────────────────┐
│ SharedPreferences│
│                  │
│  • iProfile      │
│  • iBasket       │
│  • sPaysLangue   │
│  • sPaysFav      │
└──────────────────┘
```

---

## 🎓 Concepts clés

### **1. SharedPreferences**
Stockage local persistant pour les données de profil utilisateur.

### **2. WidgetsBindingObserver**
Observer du cycle de vie de l'application Flutter, permettant de détecter quand l'app revient au foreground.

### **3. AppLifecycleState**
États du cycle de vie :
- `resumed` : App au foreground (visible)
- `inactive` : App en transition
- `paused` : App en arrière-plan
- `detached` : App fermée

### **4. iBasket crypté**
Identifiant unique du panier, généré et géré côté serveur SNAL-Project.

---

## 📝 Conclusion

La persistance des articles dans la wishlist repose sur **trois piliers** :

1. **Sauvegarde du iBasket** dans SharedPreferences après chaque ajout
2. **Rechargement automatique** via WidgetsBindingObserver
3. **Transmission correcte des paramètres** (iProfile, iBasket, sPaysFav) à l'API

Cette architecture garantit une **expérience utilisateur fluide** où les articles ajoutés restent disponibles même après la fermeture de l'application.

---

**Date de création** : 2025-10-09  
**Version** : 1.0  
**Auteur** : Équipe Jirig Flutter

