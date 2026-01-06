# 📝 Clés de Traduction - Support Screen

Ce document liste toutes les clés de traduction utilisées dans `lib/screens/support_screen.dart` avec leurs textes par défaut (français).

---

## 📋 Liste des Clés de Traduction

### ✅ Message de Succès

| Clé | Texte par Défaut |
|-----|------------------|
| `SUPPORT_SUCCESS_TITLE` | `Message envoyé !` |
| `SUPPORT_SUCCESS_MESSAGE` | `Votre message a été envoyé avec succès. Nous vous répondrons dans les plus brefs délais.` |
| `SUPPORT_SUCCESS_BUTTON` | `OK` |

---

### 📞 Section Contact

| Clé | Texte par Défaut |
|-----|------------------|
| `SUPPORT_CONTACT_US` | `Nous contacter` |
| `SUPPORT_CONTACT_DESCRIPTION` | `Vous pouvez nous contacter directement par email ou remplir le formulaire ci-dessous.` |

---

### 📝 Section Formulaire

| Clé | Texte par Défaut |
|-----|------------------|
| `SUPPORT_SEND_MESSAGE` | `Envoyer un message` |
| `SUPPORT_NAME` | `Nom` |
| `SUPPORT_NAME_REQUIRED` | `Le nom est requis` |
| `SUPPORT_EMAIL` | `Email` |
| `SUPPORT_EMAIL_REQUIRED` | `L'email est requis` |
| `SUPPORT_EMAIL_INVALID` | `Email invalide` |
| `SUPPORT_SUBJECT` | `Sujet` |
| `SUPPORT_SUBJECT_REQUIRED` | `Le sujet est requis` |
| `SUPPORT_MESSAGE` | `Message` |
| `SUPPORT_MESSAGE_REQUIRED` | `Le message est requis` |
| `SUPPORT_MESSAGE_TOO_SHORT` | `Le message doit contenir au moins 10 caractères` |
| `SUPPORT_SEND` | `Envoyer` |

---

### 🔗 Section Liens Utiles

| Clé | Texte par Défaut |
|-----|------------------|
| `SUPPORT_HELPFUL_LINKS` | `Liens utiles` |
| `SUPPORT_FAQ` | `Questions fréquentes` |
| `SUPPORT_FAQ_DESCRIPTION` | `Consultez notre FAQ pour trouver des réponses aux questions courantes` |
| `SUPPORT_TERMS` | `Conditions d'utilisation` |
| `SUPPORT_TERMS_DESCRIPTION` | `Consultez nos conditions d'utilisation` |
| `SUPPORT_PRIVACY` | `Politique de confidentialité` |
| `SUPPORT_PRIVACY_DESCRIPTION` | `Consultez notre politique de confidentialité` |

---

## 📊 Résumé

**Total de clés de traduction : 24**

### Par Catégorie

- **Message de succès** : 3 clés
- **Section Contact** : 2 clés
- **Section Formulaire** : 11 clés
- **Section Liens Utiles** : 8 clés

---

## 🔧 Utilisation dans le Code

Toutes ces clés sont utilisées avec le pattern suivant :

```dart
translationService.translate('CLÉ_DE_TRADUCTION') ?? 'Texte par défaut'
```

Si la clé n'existe pas dans le service de traduction, le texte par défaut (après `??`) sera utilisé.

---

## ✅ Checklist pour l'Implémentation

- [ ] Ajouter toutes les clés dans le service de traduction
- [ ] Traduire en néerlandais (si nécessaire)
- [ ] Traduire en anglais (si nécessaire)
- [ ] Vérifier que toutes les clés sont bien utilisées dans `support_screen.dart`
- [ ] Tester avec différentes langues

---

**Fichier source** : `lib/screens/support_screen.dart`  
**Date de création** : $(date)  
**Statut** : ✅ Documentation complète

