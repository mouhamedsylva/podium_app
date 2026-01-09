# Workflow de mise à jour de l'application Podium

## 📋 Vue d'ensemble

Ce document explique le workflow complet de la mise à jour de l'application, depuis la publication d'une nouvelle version jusqu'à son installation par l'utilisateur.

---

## 🔄 Workflow complet

### Phase 1 : Préparation de la nouvelle version (Développeur)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Développement de la nouvelle version                 │
│    - Correction de bugs                                 │
│    - Nouvelles fonctionnalités                          │
│    - Améliorations de sécurité                          │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Mise à jour de pubspec.yaml                          │
│    version: 1.1.0+2  (version + build number)          │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Build et test de l'application                        │
│    - Build Android (APK/AAB)                           │
│    - Build iOS (IPA)                                    │
│    - Tests de régression                               │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Publication sur les stores                           │
│    - Upload sur Google Play Store                      │
│    - Upload sur Apple App Store                        │
│    - Déploiement web (si applicable)                   │
└─────────────────────────────────────────────────────────┘
```

---

### Phase 2 : Configuration backend (Développeur/Admin)

```
┌─────────────────────────────────────────────────────────┐
│ 5. Mise à jour de la base de données                    │
│                                                          │
│    UPDATE [dbo].[AppVersions]                           │
│    SET [sLatestVersion] = '1.1.0',                      │
│        [sMinimumVersion] = '1.0.0',                     │
│        [bForceUpdate] = 0,                               │
│        [sReleaseNotes] = 'Nouvelle version...'          │
│    WHERE [sPlatform] = 'android';                       │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Vérification de l'endpoint API                      │
│                                                          │
│    GET /api/get-app-mobile-infos-versions              │
│    ?version=1.0.0&platform=android                     │
│                                                          │
│    Réponse attendue:                                    │
│    {                                                     │
│      "updateAvailable": true,                           │
│      "latestVersion": "1.1.0",                          │
│      ...                                                 │
│    }                                                     │
└─────────────────────────────────────────────────────────┘
```

---

### Phase 3 : Détection côté application (Automatique)

```
┌─────────────────────────────────────────────────────────┐
│ 7. Démarrage de l'application                          │
│    (ou vérification périodique)                        │
│                                                          │
│    L'application appelle:                               │
│    updateService.checkOnAppStart(context)               │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 8. Récupération de la version actuelle                  │
│                                                          │
│    VersionService.getCurrentVersion()                   │
│    → "1.0.0" (depuis pubspec.yaml)                     │
│                                                          │
│    VersionService.getPlatform()                         │
│    → "android" | "ios" | "web"                         │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 9. Appel API backend                                    │
│                                                          │
│    GET /api/get-app-mobile-infos-versions              │
│    ?version=1.0.0&platform=android                      │
│                                                          │
│    Backend:                                             │
│    1. Récupère les infos depuis la DB                  │
│    2. Compare les versions                             │
│    3. Retourne le résultat                             │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 10. Analyse de la réponse                               │
│                                                          │
│     Si updateAvailable = true:                          │
│       → Afficher le dialogue                            │
│                                                          │
│     Si updateAvailable = false:                         │
│       → Aucune action                                   │
└─────────────────────────────────────────────────────────┘
```

---

### Phase 4 : Notification utilisateur

#### Scénario A : Mise à jour recommandée

```
┌─────────────────────────────────────────────────────────┐
│ 11a. Affichage du dialogue (recommandée)                │
│                                                          │
│     ┌──────────────────────────────────────┐            │
│     │  🔄 Mise à jour disponible           │            │
│     │                                       │            │
│     │  Version actuelle: 1.0.0             │            │
│     │  Nouvelle version: 1.1.0              │            │
│     │                                       │            │
│     │  Notes de version:                    │            │
│     │  - Corrections de bugs                │            │
│     │  - Nouvelles fonctionnalités          │            │
│     │                                       │            │
│     │  [Plus tard]  [Mettre à jour]        │            │
│     └──────────────────────────────────────┘            │
│                                                          │
│     L'utilisateur peut:                                 │
│     - Cliquer "Mettre à jour" → Ouvrir le store         │
│     - Cliquer "Plus tard" → Fermer le dialogue          │
└─────────────────────────────────────────────────────────┘
```

#### Scénario B : Mise à jour obligatoire

```
┌─────────────────────────────────────────────────────────┐
│ 11b. Affichage du dialogue (obligatoire)                │
│                                                          │
│     ┌──────────────────────────────────────┐            │
│     │  ⚠️ Mise à jour obligatoire          │            │
│     │                                       │            │
│     │  Version actuelle: 1.0.0             │            │
│     │  Nouvelle version: 1.1.0              │            │
│     │                                       │            │
│     │  ⚠️ Cette mise à jour est obligatoire │            │
│     │     pour continuer à utiliser          │            │
│     │     l'application.                    │            │
│     │                                       │            │
│     │              [Mettre à jour]          │            │
│     └──────────────────────────────────────┘            │
│                                                          │
│     L'utilisateur DOIT:                                 │
│     - Cliquer "Mettre à jour" → Ouvrir le store         │
│     - Le bouton "Plus tard" n'existe pas               │
│     - Le dialogue ne peut pas être fermé               │
└─────────────────────────────────────────────────────────┘
```

---

### Phase 5 : Action utilisateur

```
┌─────────────────────────────────────────────────────────┐
│ 12. L'utilisateur clique sur "Mettre à jour"           │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 13. Redirection vers le store                           │
│                                                          │
│    Android:                                             │
│    → Ouvre Google Play Store                            │
│    → Affiche la page de l'application                  │
│    → L'utilisateur peut installer la mise à jour       │
│                                                          │
│    iOS:                                                 │
│    → Ouvre App Store                                    │
│    → Affiche la page de l'application                  │
│    → L'utilisateur peut installer la mise à jour       │
│                                                          │
│    Web:                                                 │
│    → Recharge la page                                  │
│    → Charge la nouvelle version depuis le serveur      │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 14. Installation de la mise à jour                     │
│                                                          │
│    Android/iOS:                                         │
│    - L'utilisateur installe depuis le store             │
│    - L'application se met à jour                        │
│    - Au prochain démarrage: version 1.1.0               │
│                                                          │
│    Web:                                                 │
│    - La page se recharge automatiquement               │
│    - La nouvelle version est chargée                   │
└─────────────────────────────────────────────────────────┘
```

---

### Phase 6 : Vérification post-installation

```
┌─────────────────────────────────────────────────────────┐
│ 15. Prochain démarrage de l'application                 │
│                                                          │
│    VersionService.getCurrentVersion()                   │
│    → "1.1.0" (nouvelle version)                       │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 16. Nouvelle vérification                                │
│                                                          │
│    GET /api/get-app-mobile-infos-versions              │
│    ?version=1.1.0&platform=android                      │
│                                                          │
│    Réponse:                                             │
│    {                                                     │
│      "updateAvailable": false,                         │
│      "currentVersion": "1.1.0",                        │
│      "latestVersion": "1.1.0"                          │
│    }                                                     │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│ 17. Aucune mise à jour disponible                       │
│                                                          │
│    → L'application fonctionne normalement               │
│    → Aucun dialogue affiché                             │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Diagramme de flux complet

```
┌─────────────────────────────────────────────────────────────────┐
│                    WORKFLOW COMPLET                             │
└─────────────────────────────────────────────────────────────────┘

DÉVELOPPEUR                    BACKEND                    APPLICATION                    UTILISATEUR
     │                            │                            │                              │
     │ 1. Développe nouvelle      │                            │                              │
     │    version                 │                            │                              │
     │                            │                            │                              │
     │ 2. Build et publie         │                            │                              │
     │    sur les stores          │                            │                              │
     │                            │                            │                              │
     │ 3. Met à jour la DB        │                            │                              │
     │───────────────────────────>│                            │                              │
     │                            │                            │                              │
     │                            │                            │ 4. Démarre l'app            │
     │                            │                            │<─────────────────────────────│
     │                            │                            │                              │
     │                            │                            │ 5. Vérifie la version        │
     │                            │                            │──────────────────────────────>│
     │                            │                            │                              │
     │                            │ 6. Récupère infos DB      │                              │
     │                            │    Compare versions        │                              │
     │                            │<───────────────────────────│                              │
     │                            │                            │                              │
     │                            │ 7. Retourne résultat       │                              │
     │                            │───────────────────────────>│                              │
     │                            │                            │                              │
     │                            │                            │ 8. Affiche dialogue         │
     │                            │                            │──────────────────────────────>│
     │                            │                            │                              │
     │                            │                            │                              │ 9. Clique "Mettre à jour"
     │                            │                            │<─────────────────────────────│
     │                            │                            │                              │
     │                            │                            │ 10. Ouvre le store           │
     │                            │                            │──────────────────────────────>│
     │                            │                            │                              │
     │                            │                            │                              │ 11. Installe la mise à jour
     │                            │                            │<─────────────────────────────│
     │                            │                            │                              │
     │                            │                            │ 12. App redémarre           │
     │                            │                            │──────────────────────────────>│
     │                            │                            │                              │
     │                            │                            │ 13. Vérifie à nouveau        │
     │                            │                            │──────────────────────────────>│
     │                            │                            │                              │
     │                            │ 14. Retourne "à jour"      │                              │
     │                            │───────────────────────────>│                              │
     │                            │                            │                              │
     │                            │                            │ 15. Aucun dialogue          │
     │                            │                            │──────────────────────────────>│
```

---

## ⏰ Timing et fréquence des vérifications

### Vérifications automatiques

1. **Au démarrage de l'application**
   - **Quand :** Immédiatement après le chargement de l'écran principal
   - **Type :** Uniquement les mises à jour **obligatoires**
   - **Raison :** Ne pas perturber l'utilisateur avec des mises à jour recommandées au démarrage

2. **Vérification périodique**
   - **Quand :** Toutes les 24 heures (configurable)
   - **Type :** Toutes les mises à jour (obligatoires + recommandées)
   - **Raison :** Informer l'utilisateur des nouvelles versions disponibles

3. **Vérification manuelle**
   - **Quand :** L'utilisateur clique sur "Vérifier les mises à jour" dans les paramètres
   - **Type :** Toutes les mises à jour
   - **Raison :** Permettre à l'utilisateur de vérifier manuellement

### Exemple de timeline

```
Jour 1, 10:00 - Publication de la version 1.1.0
  │
  ├─> 10:05 - Mise à jour de la base de données
  │
  ├─> 10:10 - Premier utilisateur démarre l'app
  │           → Vérifie la version
  │           → Mise à jour disponible détectée
  │           → Dialogue affiché (si recommandée)
  │
  ├─> 10:15 - Utilisateur installe la mise à jour
  │
  └─> 10:20 - Utilisateur redémarre l'app
              → Version 1.1.0 détectée
              → Aucune mise à jour disponible
              → Aucun dialogue
```

---

## 🔀 Différents scénarios

### Scénario 1 : Mise à jour recommandée normale

```
Version actuelle: 1.0.0
Version disponible: 1.1.0
Version minimum: 1.0.0
Force update: false

Résultat:
- updateAvailable: true
- updateRequired: false
- forceUpdate: false

Comportement:
- Dialogue affiché avec bouton "Plus tard"
- L'utilisateur peut fermer le dialogue
- L'application fonctionne normalement
```

### Scénario 2 : Mise à jour obligatoire

```
Version actuelle: 1.0.0
Version disponible: 1.2.0
Version minimum: 1.1.0
Force update: true

Résultat:
- updateAvailable: true
- updateRequired: true
- forceUpdate: true

Comportement:
- Dialogue affiché SANS bouton "Plus tard"
- Le dialogue ne peut pas être fermé
- L'utilisateur DOIT mettre à jour pour continuer
```

### Scénario 3 : Version à jour

```
Version actuelle: 1.1.0
Version disponible: 1.1.0
Version minimum: 1.0.0

Résultat:
- updateAvailable: false
- updateRequired: false

Comportement:
- Aucun dialogue affiché
- L'application fonctionne normalement
```

### Scénario 4 : Version future (développement)

```
Version actuelle: 1.2.0 (version de dev)
Version disponible: 1.1.0 (version production)
Version minimum: 1.0.0

Résultat:
- updateAvailable: false
- updateRequired: false

Comportement:
- Aucun dialogue affiché
- L'application fonctionne normalement
```

---

## 🛡️ Gestion des erreurs

### Erreur : API non disponible

```
Scénario: Le backend ne répond pas

Comportement:
- L'application continue de fonctionner
- Aucun dialogue affiché
- Erreur loggée mais non visible par l'utilisateur
- Nouvelle tentative au prochain démarrage
```

### Erreur : Version invalide

```
Scénario: La version retournée par l'API est invalide

Comportement:
- Utilisation de valeurs par défaut
- Aucun dialogue affiché
- Erreur loggée
- L'application fonctionne normalement
```

### Erreur : Store non disponible

```
Scénario: Le lien du store ne s'ouvre pas

Comportement:
- Message d'erreur affiché à l'utilisateur
- L'utilisateur peut réessayer plus tard
- L'application continue de fonctionner
```

---

## 📝 Checklist pour une nouvelle version

### Avant la publication

- [ ] Tester la nouvelle version sur toutes les plateformes
- [ ] Vérifier que les fonctionnalités critiques fonctionnent
- [ ] Préparer les notes de version
- [ ] Préparer les URLs des stores (Play Store, App Store)

### Pendant la publication

- [ ] Uploader l'application sur les stores
- [ ] Mettre à jour la base de données avec les nouvelles versions
- [ ] Vérifier que l'endpoint API retourne les bonnes informations
- [ ] Tester l'endpoint avec curl ou Postman

### Après la publication

- [ ] Tester depuis l'application mobile que le dialogue s'affiche
- [ ] Vérifier que le lien du store fonctionne
- [ ] Surveiller les logs pour détecter d'éventuelles erreurs
- [ ] Vérifier que les utilisateurs reçoivent bien les notifications

### En cas de problème

- [ ] Vérifier les logs du backend
- [ ] Vérifier que la base de données contient les bonnes valeurs
- [ ] Tester l'endpoint API directement
- [ ] Vérifier que les stores ont bien publié la nouvelle version

---

## 🎯 Bonnes pratiques

### 1. Versioning

- Utilisez le **semantic versioning** : `MAJOR.MINOR.PATCH`
- **MAJOR** : Changements incompatibles (ex: 2.0.0)
- **MINOR** : Nouvelles fonctionnalités compatibles (ex: 1.1.0)
- **PATCH** : Corrections de bugs (ex: 1.0.1)

### 2. Mises à jour obligatoires

- Utilisez-les **uniquement** pour :
  - Corrections de sécurité critiques
  - Changements de compatibilité majeurs
  - Problèmes bloquants

- **Évitez** de les utiliser pour :
  - Nouvelles fonctionnalités
  - Améliorations mineures
  - Corrections de bugs non critiques

### 3. Notes de version

- Soyez **clairs et concis**
- Listez les **principales améliorations**
- Mentionnez les **corrections de bugs importantes**
- Utilisez un **langage accessible** aux utilisateurs

### 4. Timing

- Publiez les mises à jour **progressivement** (staged rollout)
- Surveillez les **erreurs** après publication
- Préparez un **plan de rollback** si nécessaire

---

## 🔍 Monitoring et analytics

### Métriques à surveiller

1. **Taux d'adoption**
   - Pourcentage d'utilisateurs ayant installé la nouvelle version
   - Temps moyen pour adopter une nouvelle version

2. **Erreurs**
   - Nombre d'erreurs lors de la vérification de version
   - Erreurs d'ouverture du store

3. **Engagement**
   - Nombre d'utilisateurs qui cliquent sur "Mettre à jour"
   - Nombre d'utilisateurs qui choisissent "Plus tard"

### Logs à surveiller

```
Backend:
- Nombre de requêtes de vérification de version
- Erreurs de connexion à la base de données
- Erreurs de parsing JSON

Frontend:
- Erreurs lors de l'appel API
- Erreurs lors de l'ouverture du store
- Versions détectées par plateforme
```

---

## ✅ Résumé

Le workflow de mise à jour suit ces étapes principales :

1. **Développement** → Nouvelle version développée et testée
2. **Publication** → Application publiée sur les stores
3. **Configuration** → Base de données mise à jour
4. **Détection** → Application vérifie automatiquement les mises à jour
5. **Notification** → Dialogue affiché à l'utilisateur
6. **Action** → Utilisateur installe la mise à jour
7. **Vérification** → Application confirme qu'elle est à jour

Ce processus garantit que les utilisateurs sont toujours informés des nouvelles versions disponibles et peuvent les installer facilement.
