# 📡 Documentation du Proxy Server pour Jirig Flutter

## 🎯 Vue d'ensemble

Ce document décrit le serveur proxy local implémenté pour résoudre les problèmes CORS lors du développement de l'application Flutter Jirig. Le proxy permet de faire des requêtes API vers `https://jirig.be/api` depuis l'application Flutter web qui tourne sur `localhost`.

## 🚨 Problème résolu

### **CORS (Cross-Origin Resource Sharing)**
- **Problème** : Les navigateurs bloquent les requêtes depuis `localhost:port` vers `https://jirig.be/api`
- **Erreur** : `XMLHttpRequest blocked by CORS policy`
- **Solution** : Proxy local qui redirige les requêtes vers l'API réelle

## 🏗️ Architecture du Proxy

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Flutter App    │    │  Proxy Server   │    │  API jirig.be   │
│  (localhost:*)  │───▶│ (localhost:3001)│───▶│ (https://jirig.be)│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Fichiers du Proxy

### **1. `proxy-server.js`**
Serveur Express principal qui gère la redirection des requêtes.

```javascript
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 3001;
const API_TARGET = 'https://jirig.be'; // L'API réelle
```

### **2. `package.json`**
Configuration des dépendances Node.js pour le proxy.

```json
{
  "name": "jirig-proxy",
  "version": "1.0.0",
  "description": "Local proxy server for Jirig Flutter app to bypass CORS",
  "dependencies": {
    "express": "^4.19.2",
    "http-proxy-middleware": "^3.0.0",
    "cors": "^2.8.5"
  }
}
```

## ⚙️ Configuration

### **Port du Proxy**
- **Port local** : `3001`
- **URL complète** : `http://localhost:3001`

### **Redirection des requêtes**
- **Depuis** : `http://localhost:3001/api/*`
- **Vers** : `https://jirig.be/api/*`

### **Configuration CORS**
```javascript
app.use(cors({
  origin: '*',           // Autorise toutes les origines
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

## 🔧 Installation et Utilisation

### **1. Installation des dépendances**
```bash
cd jirig
npm install
```

### **2. Démarrage du proxy**
```bash
npm start
# ou
node proxy-server.js
```

### **3. Vérification**
```
🚀 Proxy server listening on port 3001
Proxying requests from http://localhost:3001/api to https://jirig.be/api
```

### **4. Configuration Flutter**
Dans `lib/config/api_config.dart` :
```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:3001/api';
  static const String imageBaseUrl = 'http://localhost:3001/api';
}
```

## 📡 Endpoints Proxyés

### **Endpoints principaux**
- `GET /api/get-infos-status` → `https://jirig.be/api/get-infos-status`
- `GET /api/get-all-country` → `https://jirig.be/api/get-all-country`
- `GET /api/flags` → `https://jirig.be/api/flags`
- `GET /api/translations/{lang}` → `https://jirig.be/api/translations/{lang}`
- `POST /api/auth/init` → `https://jirig.be/api/auth/init`

### **Exemple de requête**
```dart
// Flutter fait cette requête
final response = await _dio.get('/get-infos-status');

// URL finale : http://localhost:3001/api/get-infos-status
// Proxy redirige vers : https://jirig.be/api/get-infos-status
```

## 🔍 Logs et Debugging

### **Logs du Proxy**
```javascript
onProxyReq: (proxyReq, req, res) => {
  console.log(`Proxying request: ${req.method} ${req.url} -> ${proxyReq.protocol}//${proxyReq.host}${proxyReq.path}`);
},
onProxyRes: (proxyRes, req, res) => {
  console.log(`Received response for: ${req.method} ${req.url} with status: ${proxyRes.statusCode}`);
},
```

### **Exemple de logs**
```
Proxying request: GET /api/get-infos-status -> https://jirig.be/api/get-infos-status
Received response for: GET /api/get-infos-status with status: 200
```

## 🛡️ Sécurité

### **Headers préservés**
- `Content-Type`
- `Authorization`
- `Accept`
- `User-Agent`

### **HTTPS maintenu**
- Le proxy utilise HTTPS pour communiquer avec `jirig.be`
- Les certificats SSL sont vérifiés
- Pas de dégradation de sécurité

## 🚀 Workflow de Développement

### **1. Démarrage du développement**
```bash
# Terminal 1 : Proxy
cd jirig
npm start

# Terminal 2 : Flutter
flutter run --debug
```

### **2. Test des requêtes**
```bash
# Test direct du proxy
curl http://localhost:3001/api/get-infos-status

# Test depuis Flutter
# Les requêtes passent automatiquement par le proxy
```

### **3. Debugging**
- **Logs proxy** : Vérifier la redirection des requêtes
- **Logs Flutter** : Vérifier les appels API dans la console
- **Network tab** : Vérifier les requêtes dans les DevTools

## 🔄 Alternatives au Proxy

### **1. Configuration CORS côté serveur**
```javascript
// Sur le serveur jirig.be
app.use(cors({
  origin: ['http://localhost:*', 'http://127.0.0.1:*'],
  credentials: true
}));
```

### **2. Extension Chrome (développement)**
- `CORS Unblock` ou `Disable CORS`
- **⚠️ Attention** : À utiliser uniquement en développement

### **3. Serveur de développement avec proxy**
```javascript
// Dans vite.config.js ou webpack.config.js
proxy: {
  '/api': {
    target: 'https://jirig.be',
    changeOrigin: true,
    secure: true
  }
}
```

## 📋 Avantages du Proxy Local

### **✅ Avantages**
- **Simplicité** : Solution rapide et efficace
- **Transparence** : Aucune modification du code Flutter
- **Sécurité** : HTTPS maintenu vers l'API
- **Debugging** : Logs détaillés des requêtes
- **Flexibilité** : Facile à modifier ou étendre

### **⚠️ Limitations**
- **Local uniquement** : Ne fonctionne que sur la machine de développement
- **Performance** : Ajoute une couche supplémentaire
- **Maintenance** : Un service supplémentaire à gérer

## 🚀 Déploiement en Production

### **Option 1 : Proxy sur serveur**
```bash
# Sur le serveur de production
npm install
pm2 start proxy-server.js --name "jirig-proxy"
```

### **Option 2 : Configuration CORS**
```javascript
// Configuration CORS sur jirig.be
app.use(cors({
  origin: ['https://votre-app.com'],
  credentials: true
}));
```

### **Option 3 : CDN avec CORS**
- Utiliser un CDN qui gère CORS automatiquement
- CloudFlare, AWS CloudFront, etc.

## 🔧 Maintenance

### **Mise à jour des dépendances**
```bash
npm update
```

### **Monitoring**
```bash
# Vérifier que le proxy fonctionne
curl -I http://localhost:3001/api/get-infos-status

# Vérifier les logs
pm2 logs jirig-proxy
```

### **Redémarrage**
```bash
pm2 restart jirig-proxy
```

## 📚 Ressources

### **Documentation**
- [Express.js](https://expressjs.com/)
- [http-proxy-middleware](https://github.com/chimurai/http-proxy-middleware)
- [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)

### **Outils utiles**
- **Postman** : Tester les endpoints
- **curl** : Tests en ligne de commande
- **Browser DevTools** : Debugging des requêtes

---

## 🎯 Résumé

Le proxy local est une solution temporaire mais efficace pour résoudre les problèmes CORS lors du développement de l'application Flutter Jirig. Il permet de faire des requêtes API vers `https://jirig.be/api` depuis l'application web locale sans modification du code Flutter.

**Commandes essentielles :**
```bash
npm install    # Installation
npm start      # Démarrage
curl http://localhost:3001/api/get-infos-status  # Test
```

**Configuration Flutter :**
```dart
static const String baseUrl = 'http://localhost:3001/api';
```
