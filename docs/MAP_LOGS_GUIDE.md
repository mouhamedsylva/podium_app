# 🗺️ Guide des Logs de la Carte

## 📊 Logs Ajoutés

### Initialisation
```
🗺️ ========== SimpleMapModal initState ==========
🗺️ Mode: Embedded / Dialog
```

### Géolocalisation
```
🗺️ Début getUserLocation
📍 Service de localisation activé: true/false
📍 Permission actuelle: LocationPermission.X
⚠️ Permission refusée, demande en cours...
📍 Nouvelle permission: LocationPermission.X
📍 Récupération position GPS...
✅ Position obtenue: LAT, LNG
```

### Chargement Magasins
```
🏪 Chargement des magasins...
🏪 Nombre de magasins: 3
  - IKEA Bruxelles: (LAT, LNG)
  - IKEA Anderlecht: (LAT, LNG)
  - IKEA Zaventem: (LAT, LNG)
✅ Magasins chargés
```

### Erreurs
```
⚠️ Service de localisation désactivé, utilisation position par défaut
❌ Permission refusée définitivement
❌ Permission refusée pour toujours
❌ Erreur getUserLocation: [error]
```

## 🎯 Flux Normal

```
1. Ouverture carte
   └─ 🗺️ SimpleMapModal initState
   └─ 🗺️ Mode: Embedded

2. Géolocalisation
   └─ 🗺️ Début getUserLocation
   └─ 📍 Service activé: true
   └─ 📍 Permission: whileInUse
   └─ 📍 Récupération position GPS...
   └─ ✅ Position: 50.8467, 4.3499

3. Magasins
   └─ 🏪 Chargement des magasins...
   └─ 🏪 Nombre: 3
   └─ ✅ Magasins chargés

4. Affichage carte
   └─ [Carte OpenStreetMap]
   └─ [Marqueur utilisateur]
   └─ [3 marqueurs IKEA]
```

## 📱 Comment Voir les Logs

1. **Ouvrir la console Flutter** dans VSCode ou terminal
2. **Cliquer sur l'icône localisation** (📍) dans la wishlist
3. **Observer les logs** qui s'affichent

## 🔍 Diagnostic par Logs

### Cas 1: Position par Défaut
```
🗺️ Début getUserLocation
📍 Service de localisation activé: false
⚠️ Service de localisation désactivé, utilisation position par défaut
```
**Solution**: Activer la localisation dans les paramètres

### Cas 2: Permission Refusée
```
📍 Permission actuelle: denied
⚠️ Permission refusée, demande en cours...
📍 Nouvelle permission: denied
❌ Permission refusée définitivement
```
**Solution**: Autoriser la localisation pour l'app

### Cas 3: Erreur GPS
```
📍 Récupération position GPS...
❌ Erreur getUserLocation: [error details]
```
**Solution**: Vérifier connexion GPS/réseau

### Cas 4: Succès
```
📍 Récupération position GPS...
✅ Position obtenue: 50.8467, 4.3499
🏪 Nombre de magasins: 3
✅ Magasins chargés
```
**Résultat**: Carte affichée avec position réelle

## 🏪 Données Actuelles (Factices)

La carte utilise actuellement des données factices :

```dart
List<Map<String, dynamic>> _getIkeaStores() {
  return [
    {
      'name': 'IKEA Bruxelles',
      'address': 'Boulevard de la Woluwe 34, 1200 Woluwe-Saint-Lambert',
      'lat': userLat + 0.01,
      'lng': userLng + 0.01,
      'phone': '+32 2 720 00 00',
      'hours': '10h00 - 21h00',
      'distance': '2.5 km'
    },
    // + 2 autres magasins
  ];
}
```

**Note**: Ces magasins sont positionnés **relativement** à la position de l'utilisateur :
- IKEA Bruxelles: +0.01° lat, +0.01° lng
- IKEA Anderlecht: -0.008° lat, +0.015° lng
- IKEA Zaventem: +0.02° lat, -0.005° lng

## 🔧 Pour Connecter à l'API SNAL

Si vous voulez utiliser de vraies données depuis SNAL, il faut :

1. **Réactiver l'endpoint dans le proxy**
   ```javascript
   // proxy-server.js
   app.get('/api/get-ikea-store-list', async (req, res) => {
     const { lat, lng } = req.query;
     // Appel à SNAL
   });
   ```

2. **Ajouter la méthode dans api_service.dart**
   ```dart
   Future<List<Map<String, dynamic>>> getIkeaStores({
     required double lat,
     required double lng,
   }) async {
     // Appel à l'API
   }
   ```

3. **Modifier _loadStores() dans simple_map_modal.dart**
   ```dart
   Future<void> _loadStores() async {
     final stores = await _apiService.getIkeaStores(
       lat: _userLocation!.latitude,
       lng: _userLocation!.longitude,
     );
     // Utiliser les vraies données
   }
   ```

## 📊 Exemple de Logs Complets

```
🗺️ ========== SimpleMapModal initState ==========
🗺️ Mode: Embedded
🗺️ Début getUserLocation
📍 Service de localisation activé: true
📍 Permission actuelle: LocationPermission.whileInUse
📍 Récupération position GPS...
✅ Position obtenue: 50.8467, 4.3499
🏪 Chargement des magasins...
🏪 Nombre de magasins: 3
  - IKEA Bruxelles: (50.8567, 4.3599)
  - IKEA Anderlecht: (50.8387, 4.3649)
  - IKEA Zaventem: (50.8667, 4.3449)
✅ Magasins chargés
```

## ✅ Vérification

Pour confirmer que la carte fonctionne :

1. ✅ Logs d'initialisation apparaissent
2. ✅ Position GPS obtenue (ou par défaut)
3. ✅ 3 magasins chargés
4. ✅ Carte OpenStreetMap affichée
5. ✅ Marqueur bleu (utilisateur) visible
6. ✅ 3 marqueurs IKEA (bleu/jaune) visibles
7. ✅ Clic sur marqueur = info magasin

**Testez maintenant en cliquant sur l'icône de localisation !** 🗺️

