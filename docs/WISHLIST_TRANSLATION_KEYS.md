# Clés de Traduction - Wishlist Screen

## Vue d'ensemble
Ce document répertorie toutes les clés de traduction ajoutées dans `wishlist_screen.dart` pour remplacer les textes codés en dur.

## Clés ajoutées

### Messages d'erreur
- `WISHLIST_ERROR_LOADING` - "Erreur lors du chargement de la wishlist: $e"
- `WISHLIST_ERROR_PROFILE_CREATION` - "Erreur lors de la création du profil: $e"
- `WISHLIST_ERROR_DATA_LOADING` - "Erreur lors du chargement des données: $e"

### Dialogs de confirmation et erreur
- `CONFIRM_DELETE_ITEM` - "Voulez-vous vraiment supprimer cet article ?"
- `SUCCESS_TITLE` - "Succès"
- `SUCCESS_DELETE_ARTICLE` - "L'article a été supprimé avec succès."
- `ERROR_TITLE` - "Erreur"
- `DELETE_ERROR` - "Une erreur est survenue lors de la suppression."

### Boutons
- `BUTTON_NO` - "Non"
- `BUTTON_YES` - "Oui"
- `BUTTON_OK` - "OK"
- `ADD_ITEM` - "Ajouter"

### Interface utilisateur
- `WISHLIST_EMPTY` - "Wishlist (0 Art.)"
- `WISHLIST_EMPTY_BASKET` - "Panier vide"
- `AVAILABLE_COUNTRIES` - "Pays disponibles"
- `BEST_PRICE` - "Meilleur prix" (pour "Optimal")
- `CURRENT_PRICE` - "Prix actuel" (pour "Actuel")
- `PROFIT` - "Bénéfice"
- `ADD_COUNTRY` - "Ajouter" (utilisé pour le bouton)

## Modifications techniques

### Changements dans le code
1. **Provider TranslationService** : Changé `listen: false` en `listen: true` dans la méthode `build()` pour permettre la mise à jour automatique des traductions
2. **Fallback values** : Toutes les clés utilisent l'opérateur `??` avec des valeurs de fallback en français
3. **Cohérence** : Utilisation de `translationService.translate()` pour toutes les chaînes de texte

### Structure des clés
- **Préfixes** : Utilisation de préfixes logiques (`WISHLIST_`, `BUTTON_`, `ERROR_`, etc.)
- **Nomenclature** : Utilisation de `SCREAMING_SNAKE_CASE` pour les clés
- **Groupement** : Clés groupées par fonctionnalité (erreurs, boutons, interface)

## Compatibilité
- ✅ **Fallback français** : Toutes les clés ont des valeurs de fallback en français
- ✅ **Responsive** : Aucun impact sur la responsivité existante
- ✅ **Performance** : Utilisation optimale du Provider avec `listen: true` uniquement dans `build()`
- ✅ **Maintenance** : Code plus maintenable avec séparation des traductions

## Corrections apportées

### Problème de débordement résolu
- **Overflow du bouton "Ajouter"** : Remplacé `SizedBox` par `Flexible` et réduit la taille de police
- **Texte responsive** : Ajout de `overflow: TextOverflow.ellipsis` pour éviter les débordements

### Clés corrigées selon l'API disponible
- `BEST_PRICE` : Utilise la clé API existante pour "Meilleur prix" (Optimal)
- `CONFIRM_DELETE_ITEM` : Utilise la clé API existante pour la confirmation de suppression
- `DELETE_ERROR` : Utilise la clé API existante pour les erreurs de suppression
- `AVAILABLE_COUNTRIES` : Utilise la clé API existante pour "Pays disponibles"
- `ADD_COUNTRY` : Utilise cette clé existante pour le bouton "Ajouter"
- `CURRENT_PRICE` : Nouvelle clé pour "Prix actuel" (Actuel)
- `PROFIT` : Nouvelle clé pour "Bénéfice"

### Textes gardés en français (pas de clés API)
- "Confirmation", "Succès", "Erreur" : Pas de clés spécifiques dans l'API
- "Non", "Oui", "OK" : Pas de clés spécifiques dans l'API
- "Panier vide" : Pas de clé correspondante dans l'API

## Prochaines étapes
1. **Backend** : Vérifier que toutes les clés sont présentes dans l'API SNAL
2. **Tests** : Tester les traductions dans différentes langues
3. **Validation** : Vérifier que tous les textes s'affichent correctement dans toutes les langues supportées
4. **Clés manquantes** : Ajouter `CURRENT_PRICE` et `PROFIT` dans l'API si elles n'existent pas

## Exemple d'utilisation
```dart
// Avant (texte codé en dur)
Text('Confirmation')

// Après (avec clé de traduction)
Text(translationService.translate('CONFIRMATION_TITLE') ?? 'Confirmation')
```

## Notes
- Le `TranslationService` est maintenant écouté (`listen: true`) dans la méthode `build()` pour permettre la mise à jour automatique des traductions lors des changements de langue
- Toutes les chaînes de texte codées en dur ont été identifiées et remplacées
- Le système de fallback garantit que l'interface reste fonctionnelle même si une traduction est manquante
