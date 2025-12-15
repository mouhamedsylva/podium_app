# Configuration Mobile-First

## 📱 Architecture

Cette application est développée avec une approche **Mobile-First** :
- **Priorité à l'expérience mobile native** (Android/iOS)
- **Support Web** avec adaptations nécessaires

## 🔧 Gestion des Cookies

### Sur Mobile (Android/iOS)
✅ **Gestion automatique et persistante**

- **Dio** : Client HTTP puissant
- **dio_cookie_manager** : Intercepte et renvoie automatiquement les cookies
- **PersistCookieJar** : Sauvegarde les cookies sur le disque de l'appareil
- **Persistance** : Les cookies restent même après la fermeture de l'app

**Flux mobile** :
```
1. L'API renvoie un cookie (ex: GuestProfile)
2. dio_cookie_manager le capture automatiquement
3. PersistCookieJar le sauvegarde dans /data/app/.cookies/
4. Toutes les requêtes suivantes incluent ce cookie
5. L'utilisateur reste connecté même après fermeture
```

### Sur Web (Navigateur)
⚠️ **Gestion par le navigateur + proxy pour CORS**

- **Dio** utilise le moteur HTTP du navigateur
- Les **cookies sont gérés nativement** par le navigateur
- **PersistCookieJar ne fonctionne pas** sur web
- **Proxy local** pour contourner les restrictions CORS

**Flux web** :
```
1. Flutter Web appelle http://localhost:3001/api
2. Le proxy Node.js reçoit la requête
3. Le proxy appelle https://jirig.be/api avec les cookies
4. L'API renvoie la réponse + cookies
5. Le proxy transmet tout à Flutter Web
```

## 🌐 Configuration API

### Mobile (Android/iOS)
```dart
baseUrl: 'https://jirig.be/api'  // Appel direct à l'API
useCookieManager: true            // Gestion des cookies activée
```

### Web
```dart
baseUrl: 'http://localhost:3001/api'  // Via le proxy local
useCookieManager: false                // Le navigateur gère les cookies
```

## 🖼️ Gestion des Images

### Mobile (Android/iOS)
- Les images IKEA sont chargées **directement** depuis leur CDN
- **Pas de problème CORS** sur mobile natif
- Performance optimale

### Web
- Les images passent par le **proxy** : `http://localhost:3001/proxy-image?url=...`
- Contourne les restrictions CORS du navigateur
- Mise en cache 24h côté proxy

## 🚀 Démarrage

### 1. Développement Web
```powershell
# Terminal 1 - Démarrer le proxy
cd jirig
node proxy-server.js

# Terminal 2 - Démarrer Flutter Web
cd jirig
flutter run -d chrome
```

### 2. Développement Mobile
```powershell
cd jirig

# Android
flutter run -d <android-device-id>

# iOS
flutter run -d <ios-device-id>
```

**Note** : Sur mobile, le proxy n'est PAS nécessaire. L'app appelle directement https://jirig.be/api

## 📦 Packages Utilisés

| Package | Mobile | Web | Usage |
|---------|--------|-----|-------|
| dio | ✅ | ✅ | Client HTTP |
| dio_cookie_manager | ✅ | ❌ | Gestion des cookies |
| cookie_jar | ✅ | ❌ | Stockage des cookies |
| path_provider | ✅ | ❌ | Chemin de stockage |

## 🔍 Debug

Pour voir la configuration actuelle :
```dart
ApiConfig.printConfig();
```

Sortie mobile :
```
🔧 Configuration API (Mobile-First):
   Plateforme: Mobile
   Base URL: https://jirig.be/api
   Cookie Manager: Activé
   Connect Timeout: 30s
```

Sortie web :
```
🔧 Configuration API (Mobile-First):
   Plateforme: Web
   Base URL: http://localhost:3001/api
   Cookie Manager: Désactivé (navigateur)
   Connect Timeout: 30s
```

## 🔐 Cookies sur Mobile

Les cookies sont sauvegardés dans :
- **Android** : `/data/data/com.example.jirig/app_flutter/.cookies/`
- **iOS** : `/var/mobile/Containers/Data/Application/<ID>/Documents/.cookies/`

Pour nettoyer les cookies (déconnexion) :
```dart
final apiService = ApiService();
await apiService.clearCookies();
```

## 🌍 Production

### Mobile
- Compile en `.apk` (Android) ou `.ipa` (iOS)
- Appelle directement `https://jirig.be/api`
- Pas de dépendance au proxy

### Web
- Déploie le proxy Node.js sur un serveur
- Configure l'URL du proxy dans `ApiConfig`
- Ou configure CORS sur l'API backend (si possible)

## ✅ Avantages de cette Approche

1. **Mobile-First** : Expérience native optimale
2. **Cookies persistants** : L'utilisateur reste connecté
3. **Performance** : Pas de proxy sur mobile
4. **Flexibilité** : Support Web avec adaptations
5. **Sécurité** : Cookies HTTPOnly sur mobile
6. **Maintenance** : Configuration centralisée dans `ApiConfig`

## 🔄 Alternative Future

Si SNAL-Project ajoute le support CORS :
1. Supprimer le proxy Node.js
2. Modifier `ApiConfig.baseUrl` pour pointer vers `https://jirig.be/api` sur toutes les plateformes
3. Laisser le navigateur gérer les cookies sur web
4. Garder dio_cookie_manager sur mobile pour la persistance

---

**Développé avec ❤️ en Mobile-First**

