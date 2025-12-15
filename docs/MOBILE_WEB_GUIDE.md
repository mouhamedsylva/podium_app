# 🚀 Guide Web + Mobile pour Jirig Flutter

## 📋 Prérequis

### Pour le Web (développement) :
- ✅ Flutter SDK installé
- ✅ Chrome/Edge pour tester
- ✅ Node.js pour le proxy server

### Pour le Mobile (production) :
- ✅ Flutter SDK avec support Android/iOS
- ✅ Android Studio (optionnel) ou VS Code
- ✅ Émulateur ou appareil physique

## 🔧 Configuration

### 1. Démarrer le Proxy Server (Web uniquement)
```bash
# Dans le dossier jirig/
node proxy-server.js
```

### 2. Lancer l'application

#### Pour le Web (développement) :
```bash
flutter run -d chrome --web-port 3000
```

#### Pour Android :
```bash
flutter run -d android
```

#### Pour iOS :
```bash
flutter run -d ios
```

## 🌐 Configuration API

L'application utilise automatiquement :
- **Web** : `http://localhost:3001/api` (via proxy)
- **Mobile** : `https://jirig.be/api` (direct)

## 🎯 Avantages de cette approche

### ✅ Web (Développement) :
- Proxy local évite les problèmes CORS
- Hot reload rapide
- Debugging facile
- Pas besoin d'émulateur

### ✅ Mobile (Production) :
- API directe (plus rapide)
- Pas de dépendance proxy
- Fonctionne offline partiellement
- Performance optimale

## 🔍 Tests de compatibilité

### Web :
1. Vérifier que le proxy fonctionne : http://localhost:3001/health
2. Tester les appels API dans la console
3. Vérifier les animations et transitions

### Mobile :
1. Tester sur différents écrans (responsive)
2. Vérifier les performances
3. Tester les gestes tactiles

## 🐛 Résolution de problèmes

### Proxy ne fonctionne pas :
```dart
// Dans api_config.dart, décommenter cette ligne :
static String get baseUrl => 'https://jirig.be/api';
```

### Erreurs CORS sur mobile :
- Vérifier que `kIsWeb` fonctionne correctement
- Utiliser l'API directe : `https://jirig.be/api`

### Images ne se chargent pas :
- Vérifier `imageBaseUrl` dans `api_config.dart`
- Tester les URLs d'images dans le navigateur

## 📱 Optimisations Mobile-First

L'application est conçue mobile-first avec :
- Design responsive (MediaQuery)
- Touch-friendly (gestures)
- Performance optimisée
- Offline capabilities (SharedPreferences)
