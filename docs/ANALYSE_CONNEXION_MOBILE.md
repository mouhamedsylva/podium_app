# 🔍 Analyse du Problème de Connexion Mobile (Email + Code)

## ❌ Problème Identifié

**Symptôme** : Après une connexion email + code réussie sur mobile, l'utilisateur redevient toujours "Guest".

## 🔬 Analyse du Flux

### Flux Web (SNAL) - ✅ FONCTIONNE
```
1. Connexion email + code → API retourne OK
2. setUserSession() sauvegarde TROUS les champs utilisateur dans la session
   - sEmail ✅
   - sNom ✅
   - sPrenom ✅
   - etc.
3. Les cookies sont automatiquement mis à jour
4. isLoggedIn() = true
```

### Flux Mobile (Flutter) - ❌ NE FONCTIONNE PAS
```
1. Connexion email + code → API retourne OK
2. Mise à jour DES IDENTIFIANTS SEULEMENT (iProfile, iBasket)
   ❌ PAS DE SAUVEGARDE DE L'EMAIL (sEmail)
3. Cookies mis à jour
4. Mais isLoggedIn() vérifie user_email qui est NULL
5. ❌ isLoggedIn() = false → Utilisateur reste Guest
```

## 🐛 Causes Racines

### 1️⃣ Email Non Sauvegardé Après Login
**Fichier**: `jirig/lib/services/api_service.dart` (lignes 1285-1299)

```dart
// ❌ PROBLÈME: Seuls iProfile et iBasket sont sauvegardés
if (newIProfile != null && newIBasket != null) {
  final currentProfile = await LocalStorageService.getProfile();
  final updatedProfile = {
    ...?currentProfile,
    'iProfile': newIProfile,  // ✅ OK
    'iBasket': newIBasket,   // ✅ OK
    // ❌ MANQUE: 'sEmail'
    // ❌ MANQUE: 'sNom'
    // ❌ MANQUE: 'sPrenom'
  };
  await LocalStorageService.saveProfile(updatedProfile);
}
```

### 2️⃣ Vérification isLoggedIn() Dépend de l'Email
**Fichier**: `jirig/lib/services/local_storage_service.dart` (lignes 136-140)

```dart
static Future<bool> isLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('user_email'); // ❌ Toujours NULL
  return email != null && email.isNotEmpty;
}
```

### 3️⃣ AuthNotifier.onLogin() Appelle getProfile()
**Fichier**: `jirig/lib/services/auth_notifier.dart` (lignes 74-78)

```dart
Future<void> onLogin() async {
  await _syncWithApi(); // ✅ Appelle getProfile() qui récupère les données
  notifyListeners();
}
```

**PROBLÈME**: `authNotifier.onLogin()` est appelé dans `login_screen.dart` LIGNES 329-331, MAIS à ce moment-là, les nouveaux identifiants NE SONT PAS ENCORE DANS LES COOKIES, donc `getProfile()` retourne vide.

### 4️⃣ La Bonne Solution : Récupérer les Infos de la Réponse API

Le serveur SNAL retourne les informations utilisateur dans la réponse de `/auth/login-with-code`, mais Flutter ne les récupère pas et ne les sauvegarde pas.

## ✅ Solution Proposée

### Option 1 : Récupérer depuis la Réponse Directement (RECOMMANDÉ)

Modifier `api_service.dart` pour récupérer `sEmail`, `sNom`, `sPrenom` depuis la réponse de l'API :

```dart
// Dans api_service.dart, ligne 1156+
if (isCodeValidation && data['status'] == 'OK') {
  // ✅ Récupérer LES INFORMATIONS UTILISATEUR depuis la réponse
  String? newIProfile = data['iProfile']?.toString();
  String? newIBasket = data['iBasket']?.toString();
  String? sEmail = data['sEmail']?.toString();      // ✅ NOUVEAU
  String? sNom = data['sNom']?.toString();         // ✅ NOUVEAU
  String? sPrenom = data['sPrenom']?.toString();   // ✅ NOUVEAU
  String? sPhoto = data['sPhoto']?.toString();      // ✅ NOUVEAU
  
  // Sauvegarder COMPLET avec email
  if (newIProfile != null && newIBasket != null && sEmail != null) {
    await LocalStorageService.saveProfile({
      'iProfile': newIProfile,
      'iBasket': newIBasket,
      'sEmail': sEmail,        // ✅ CRITIQUE
      'sNom': sNom ?? '',      // ✅ CRITIQUE
      'sPrenom': sPrenom ?? '', // ✅ CRITIQUE
      'sPhoto': sPhoto ?? '',   // ✅ CRITIQUE
    });
    
    _isLoggedIn = true; // ✅ Marquer comme connecté
  }
}
```

### Option 2 : Délai + getProfile() (CONTEXTUEL)

Si la réponse de l'API ne contient pas les infos utilisateur, ajouter un délai avant d'appeler `getProfile()` dans `AuthNotifier.onLogin()` :

```dart
Future<void> onLogin() async {
  print('🔐 AuthNotifier: onLogin appelé');
  
  // Attendre que les cookies soient mis à jour côté serveur
  await Future.delayed(Duration(seconds: 1));
  
  await _syncWithApi();
  notifyListeners();
}
```

## 🔄 Comparaison Web vs Mobile

| Aspect | Web (SNAL) | Mobile (Flutter) | Différence |
|--------|------------|------------------|------------|
| **Email sauvegardé** | ✅ Dans setUserSession() | ❌ Jamais sauvegardé | ❌ PROBLÈME |
| **Vérification connexion** | ✅ Cookies valides | ❌ user_email NULL | ❌ PROBLÈME |
| **isLoggedIn()** | ✅ Basé sur session | ❌ Basé sur user_email (NULL) | ❌ PROBLÈME |
| **Données utilisateur** | ✅ Toutes sauvegardées | ❌ Seul iProfile/iBasket | ❌ PROBLÈME |

## 🎯 Conclusion

**Le problème principal** : Flutter sauvegarde seulement `iProfile` et `iBasket` après connexion, mais PAS l'email. La vérification `isLoggedIn()` dépend de l'email, donc elle retourne toujours `false`.

**Solution immédiate** : Ajouter la sauvegarde de `sEmail`, `sNom`, `sPrenom` dans la méthode `login()` de `api_service.dart` ligne 1285-1299.
