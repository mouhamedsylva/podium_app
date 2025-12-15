# Clés de traduction - Page de profil

## Clés utilisées dans `profile_detail_screen.dart`

### Bouton principal
- `CONFIRM_EDIT_PROFILE` - "Modifier mon profil" / "¿Está seguro de que desea modificar su perfil?"
  - **Statut** : ✅ Existe dans l'API
  - **Usage** : Bouton principal d'édition du profil

### Messages système
- `PROFILE_REFRESHED` - "Profil rafraîchi depuis les cookies"
  - **Statut** : ❌ N'existe pas dans l'API
  - **Fallback** : Texte français codé en dur

### Sections principales
- `MAIN_COUNTRY` - "Pays principal" / "Hauptland"
  - **Statut** : ❌ N'existe pas dans l'API
  - **Fallback** : "Pays principal"

- `FAVORITE_COUNTRIES` - "Pays favoris" / "Lieblingsländer"
  - **Statut** : ❌ N'existe pas dans l'API
  - **Fallback** : "Pays favoris"

### Messages d'état
- `NO_FAVORITE_COUNTRIES` - "Aucun pays favori sélectionné"
  - **Statut** : ❌ N'existe pas dans l'API
  - **Fallback** : "Aucun pays favori sélectionné"

## Clés disponibles dans l'API (pertinentes)

### Pays et localisation
- `AVAILABLE_COUNTRIES` - "Países disponibles" / "Pays disponibles"
- `ADD_COUNTRY` - "Añadir país" / "Ajouter un pays"
- `ADD_REMOVE_COUNTRY` - "Añadir / Eliminar un país" / "Ajouter / Supprimer un pays"

### Actions de suppression
- `CONFIRM_DELETE_COUNTRY` - "¿Está seguro de que desea eliminar este país?" / "Êtes-vous sûr de vouloir supprimer ce pays ?"
- `DELETE_COUNTRY` - "Eliminar país" / "Supprimer le pays"
- `DELETE_CANCELLED` - "La eliminación ha sido cancelada." / "La suppression a été annulée."
- `DELETE_ERROR` - "Ocurrió un error durante la eliminación." / "Une erreur s'est produite lors de la suppression."

## Recommandations

### Clés à ajouter dans l'API
1. `MAIN_COUNTRY` - Pour "Pays principal" / "Hauptland"
2. `FAVORITE_COUNTRIES` - Pour "Pays favoris" / "Lieblingsländer"
3. `NO_FAVORITE_COUNTRIES` - Pour "Aucun pays favori sélectionné"
4. `PROFILE_REFRESHED` - Pour "Profil rafraîchi depuis les cookies"

### Clés alternatives possibles
- Utiliser `AVAILABLE_COUNTRIES` pour les sections de pays si les clés spécifiques n'existent pas
- Utiliser `CONFIRM_EDIT_PROFILE` pour le bouton (déjà implémenté)

## Exemple d'utilisation
```dart
// Bouton principal
Text(translationService.translate('CONFIRM_EDIT_PROFILE') ?? 'Modifier mon profil')

// Section pays principal
Text(translationService.translate('MAIN_COUNTRY') ?? 'Pays principal')

// Section pays favoris
Text(translationService.translate('FAVORITE_COUNTRIES') ?? 'Pays favoris')

// Message d'état vide
Text(translationService.translate('NO_FAVORITE_COUNTRIES') ?? 'Aucun pays favori sélectionné')
```

## Notes
- Toutes les clés utilisent des fallbacks en français
- Le système de traduction est déjà intégré avec `TranslationService`
- Les traductions se mettent à jour automatiquement lors du changement de langue
