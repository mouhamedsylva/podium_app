# Configuration API - Jirig Flutter

## 🔧 Configuration de l'API SNAL-Project

### 1. URL de Base de l'API

Modifiez le fichier `lib/config/api_config.dart` pour pointer vers votre serveur SNAL-Project :

```dart
class ApiConfig {
  // Pour le développement local (défaut)
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Pour la production
  // static const String baseUrl = 'https://votre-domaine.com/api';
  
  // Configuration des images
  static const String imageBaseUrl = 'http://localhost:3000';
}
```

### 2. Endpoints Utilisés

L'application Flutter utilise les endpoints suivants de votre API SNAL-Project :

#### 📍 **Pays et Drapeaux**
- `GET /api/get-all-country` - Récupérer tous les pays
- `GET /api/flags` - Récupérer les informations des drapeaux

#### 👤 **Authentification et Profil**
- `POST /api/auth/init` - Initialiser le profil utilisateur
- `POST /api/auth/login` - Connexion utilisateur

#### 🔍 **Recherche et Articles**
- `GET /api/search-article` - Rechercher des articles
- `POST /api/add-to-wishlist` - Ajouter à la wishlist
- `POST /api/change-seleceted-country` - Changer le pays sélectionné

#### 🛒 **Panier et Wishlist**
- `GET /api/get-basket-list-article` - Récupérer les articles du panier

#### 🏪 **Magasins**
- `GET /api/get-ikea-store-list` - Récupérer les magasins IKEA

### 3. Structure des Données

#### Pays (Country)
```json
{
  "sPays": "FR",
  "sDescr": "France", 
  "sExternalRef": "FR",
  "iPays": 13
}
```

#### Drapeaux (Flags)
```json
{
  "sPaysLangue": "fr/fr",
  "id": 13,
  "name": "France",
  "code": "FR",
  "image": "/img/flags/FR.PNG"
}
```

### 4. Test de Connexion

L'application teste automatiquement la connexion à l'API au démarrage :

```dart
// Dans CountryService
Future<bool> testConnection() async {
  return await _apiService.testConnection();
}
```

### 5. Gestion des Erreurs

L'application gère les cas d'erreur suivants :

- **Connexion API échouée** : Utilise des données de fallback
- **Images non disponibles** : Affiche un placeholder
- **Timeout** : Affiche un message d'erreur approprié

### 6. Mode Développement vs Production

#### Développement
```dart
static const String baseUrl = 'http://localhost:3000/api';
static const String imageBaseUrl = 'http://localhost:3000';
```

#### Production
```dart
static const String baseUrl = 'https://votre-domaine.com/api';
static const String imageBaseUrl = 'https://votre-domaine.com';
```

### 7. Démarrage du Serveur SNAL-Project

Avant de lancer l'application Flutter, assurez-vous que votre serveur SNAL-Project est démarré :

```bash
cd SNAL-Project
npm run dev
# ou
pnpm run dev
```

Le serveur doit être accessible sur `http://localhost:3000`

### 8. Vérification des Endpoints

Vous pouvez tester les endpoints directement dans votre navigateur :

- `http://localhost:3000/api/get-all-country`
- `http://localhost:3000/api/flags`

### 9. Logs de Debug

L'application affiche des logs détaillés dans la console :

```
✅ Connexion API réussie
CountryService initialisé avec 10 pays
Profil initialisé avec succès sur l'API
iProfile: 12345
iBasket: 67890
```

### 10. Configuration pour Différents Environnements

#### Environnement de Développement
```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
  static const String imageBaseUrl = 'http://localhost:3000';
}
```

#### Environnement de Test
```dart
class ApiConfig {
  static const String baseUrl = 'https://test-api.votre-domaine.com/api';
  static const String imageBaseUrl = 'https://test-api.votre-domaine.com';
}
```

#### Environnement de Production
```dart
class ApiConfig {
  static const String baseUrl = 'https://api.votre-domaine.com/api';
  static const String imageBaseUrl = 'https://api.votre-domaine.com';
}
```

### 11. Dépannage

#### Erreur de Connexion
- Vérifiez que le serveur SNAL-Project est démarré
- Vérifiez l'URL dans `api_config.dart`
- Vérifiez les logs du serveur SNAL-Project

#### Images ne s'affichent pas
- Vérifiez que les fichiers de drapeaux existent dans `public/img/flags/`
- Vérifiez l'URL de base des images dans `api_config.dart`

#### Données de Fallback
Si l'API n'est pas accessible, l'application utilise des données de fallback pour permettre un fonctionnement de base.

---

**Note** : Assurez-vous que votre serveur SNAL-Project est configuré pour accepter les requêtes CORS depuis l'application Flutter.
