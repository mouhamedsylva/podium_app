# 📍 Stratégie de Gestion du Refus de Permission de Localisation

## 🎯 Principe Fondamental

**L'application Jirig doit continuer à fonctionner normalement même si l'utilisateur refuse la permission de localisation.**

La localisation est une fonctionnalité **optionnelle** qui améliore l'expérience utilisateur mais n'est pas essentielle au fonctionnement de l'application.

---

## ✅ Comportement Recommandé

### 1. **Quand l'utilisateur refuse dans le popup**

#### Actions immédiates :
- ✅ **Ne pas bloquer l'utilisateur** : L'application continue normalement
- ✅ **Afficher un message informatif** : Snackbar non intrusif expliquant que l'app fonctionne normalement
- ✅ **Sauvegarder le choix** : Mémoriser dans `SharedPreferences` pour ne pas redemander immédiatement
- ✅ **Utiliser une position par défaut** : Bruxelles (50.8467, 4.3499) pour la carte

#### Message affiché :
```
ℹ️ L'application fonctionnera normalement. 
La carte utilisera une position par défaut.
```

### 2. **Fonctionnalités qui continuent de fonctionner**

Même sans localisation, l'utilisateur peut :
- ✅ Comparer les prix entre pays
- ✅ Rechercher des produits
- ✅ Scanner des codes QR
- ✅ Gérer sa wishlist
- ✅ Consulter son profil
- ✅ Utiliser la carte avec position par défaut (Bruxelles)

### 3. **Fonctionnalités limitées**

Sans localisation, certaines fonctionnalités sont limitées :
- ⚠️ La carte ne se centre pas automatiquement sur la position de l'utilisateur
- ⚠️ La recherche de magasins "près de chez vous" n'est pas disponible
- ⚠️ Les distances calculées ne sont pas précises

**Mais l'utilisateur peut toujours :**
- Rechercher des magasins par nom ou adresse
- Naviguer manuellement sur la carte
- Voir tous les magasins IKEA disponibles

---

## 🔄 Possibilité de Réactiver Plus Tard

### Option 1 : Quand l'utilisateur ouvre la carte

Si l'utilisateur ouvre la fonctionnalité de carte et que la permission n'a jamais été accordée, on peut :
- Afficher un bouton discret "Activer la localisation"
- Proposer de réactiver la permission à ce moment-là
- Ne pas forcer, juste proposer

### Option 2 : Depuis les paramètres de l'application

Ajouter une section dans les paramètres du profil :
- "Localisation" avec un toggle
- Explication claire de l'utilité
- Bouton pour ouvrir les paramètres système si refusée définitivement

### Option 3 : Ne pas redemander automatiquement

**Recommandation principale** : Ne pas harceler l'utilisateur avec des demandes répétées.

- Si l'utilisateur refuse une fois, ne pas redemander automatiquement
- Attendre qu'il ouvre explicitement la carte
- Proposer alors une réactivation discrète

---

## 📱 Gestion des Différents États

### État 1 : Permission refusée (première fois)
```dart
LocationPermission.denied
```
**Action** : Message informatif + position par défaut

### État 2 : Permission refusée définitivement
```dart
LocationPermission.deniedForever
```
**Action** : 
- Message avec bouton "Paramètres" pour ouvrir les paramètres système
- Utiliser `Geolocator.openLocationSettings()`
- Position par défaut

### État 3 : Service de localisation désactivé
```dart
Geolocator.isLocationServiceEnabled() == false
```
**Action** : 
- Message informatif
- Position par défaut
- Suggérer d'activer le GPS dans les paramètres

---

## 💾 Stockage du Choix

### Clés SharedPreferences utilisées :

1. **`location_info_shown`** (bool)
   - Indique si le popup d'information a déjà été affiché
   - Évite de redemander immédiatement

2. **`location_permission_refused`** (bool)
   - `true` : L'utilisateur a refusé la permission
   - `false` : L'utilisateur a accepté (ou pas encore demandé)
   - Permet de savoir si on doit proposer une réactivation

---

## 🎨 Messages Utilisateur

### Message de refus (Snackbar)
- **Couleur** : Bleu informatif
- **Durée** : 4 secondes
- **Style** : Floating avec icône
- **Message** : "L'application fonctionnera normalement. La carte utilisera une position par défaut."

### Message service désactivé (Snackbar)
- **Couleur** : Orange d'avertissement
- **Durée** : 4 secondes
- **Message** : "Le service de localisation est désactivé. Activez-le dans les paramètres pour utiliser la carte."

### Message refus définitif (Snackbar avec action)
- **Couleur** : Orange d'avertissement
- **Durée** : 5 secondes
- **Action** : Bouton "Paramètres" qui ouvre les paramètres système
- **Message** : "Pour activer la localisation, allez dans les paramètres de l'application."

---

## 🔧 Implémentation Technique

### Code dans `country_selection_screen.dart`

```dart
// Quand l'utilisateur refuse
if (accepted == false && mounted) {
  _showLocationRefusedMessage();
  await prefs.setBool('location_permission_refused', true);
}

// Quand l'utilisateur accepte
if (accepted == true && mounted) {
  await _requestLocationPermission();
  await prefs.setBool('location_permission_refused', false);
}
```

### Position par défaut utilisée

```dart
// Bruxelles, Belgique
LatLng(50.8467, 4.3499)
```

Cette position est déjà utilisée dans `simple_map_modal.dart` comme fallback.

---

## 📊 Matrice de Décision

| État | Action | Message | Position |
|------|--------|---------|----------|
| Refus dans popup | Continuer | Snackbar informatif | Par défaut |
| Permission refusée | Continuer | Snackbar informatif | Par défaut |
| Refus définitif | Continuer + bouton paramètres | Snackbar avec action | Par défaut |
| Service désactivé | Continuer | Snackbar d'avertissement | Par défaut |
| Permission accordée | Utiliser GPS | Aucun message | GPS réel |

---

## ✅ Checklist de Bonnes Pratiques

- [x] Ne pas bloquer l'utilisateur
- [x] Message informatif non intrusif
- [x] Sauvegarder le choix utilisateur
- [x] Utiliser position par défaut
- [x] Permettre réactivation plus tard
- [x] Ne pas harceler avec des demandes répétées
- [x] Gérer tous les états de permission
- [x] Messages clairs et concis

---

## 🚀 Améliorations Futures Possibles

1. **Bouton "Activer la localisation" dans la carte**
   - Afficher un bouton discret si la permission n'est pas accordée
   - Permet de réactiver à la demande

2. **Section paramètres dédiée**
   - Page de paramètres avec toggle localisation
   - Explication détaillée de l'utilité

3. **Analytics**
   - Tracker le taux de refus
   - Comprendre pourquoi les utilisateurs refusent
   - Améliorer le message si nécessaire

---

**Dernière mise à jour** : Après implémentation de la gestion du refus

