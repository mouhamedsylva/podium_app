# 📝 Clés de Traduction - FAQ Widget

Ce document liste toutes les clés de traduction utilisées dans `lib/widgets/faq_widget.dart` avec leurs textes par défaut (français).

---

## 📋 Liste des Clés de Traduction

### 🔍 Recherche

| Clé | Texte par Défaut |
|-----|------------------|
| `FAQ_SEARCH_PLACEHOLDER` | `Rechercher une question...` |

---

### 📭 État Vide / Aucun Résultat

| Clé | Texte par Défaut |
|-----|------------------|
| `FAQ_NO_RESULTS_TITLE` | `Aucun résultat trouvé` |
| `FAQ_NO_RESULTS_MESSAGE` | `Essayez avec d'autres mots-clés` |
| `FAQ_NO_QUESTIONS_TITLE` | `Aucune question disponible` |
| `FAQ_NO_QUESTIONS_MESSAGE` | `Les questions seront bientôt disponibles` |

---

### ⏳ État de Chargement

| Clé | Texte par Défaut |
|-----|------------------|
| `FAQ_LOADING` | `Chargement des questions...` |

---

### 📞 Section Contact

| Clé | Texte par Défaut |
|-----|------------------|
| `FAQ_CONTACT_TITLE` | `Vous ne trouvez pas votre réponse ?` |
| `FAQ_CONTACT_MESSAGE` | `Notre équipe est là pour vous aider` |
| `FRONTPAGE_Msg27` | `Contactez-nous` |

---

## 📊 Résumé

**Total de clés de traduction : 8**

### Par Catégorie

- **Recherche** : 1 clé
- **État Vide / Aucun Résultat** : 4 clés
- **État de Chargement** : 1 clé
- **Section Contact** : 3 clés

---

## 🔧 Utilisation dans le Code

Toutes ces clés sont utilisées avec le pattern suivant :

```dart
translationService.translate('CLÉ_DE_TRADUCTION')
```

**Note importante** : Les clés de traduction sont utilisées sans fallback. Assurez-vous que toutes les clés sont bien définies dans le service de traduction pour toutes les langues supportées.

---

## ✅ Checklist pour l'Implémentation

- [ ] Ajouter la clé dans le service de traduction
- [ ] Traduire en néerlandais (si nécessaire)
- [ ] Traduire en anglais (si nécessaire)
- [ ] Traduire dans les autres langues supportées
- [ ] Vérifier que la clé est bien utilisée dans `faq_widget.dart`
- [ ] Tester avec différentes langues

---

**Fichier source** : `lib/widgets/faq_widget.dart`  
**Date de création** : 2025-01-27  
**Statut** : ✅ Documentation complète

