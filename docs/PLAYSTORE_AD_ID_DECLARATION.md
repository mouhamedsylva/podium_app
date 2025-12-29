# 📱 Déclaration Identifiant Publicitaire (AD_ID) - Google Play Console

## ❓ Question du Play Store

**"Votre appli utilise-t-elle un identifiant publicitaire ?"**  
*"Cela inclut tous les SDK que votre appli importe et qui utilisent des identifiants publicitaires."*

---

## ✅ Réponse Recommandée

### Cochez : ✅ **Oui, l'application utilise un identifiant publicitaire**

---

## 📝 Justification Détaillée (copier-coller)

```
L'application Jirig utilise le Facebook SDK (flutter_facebook_auth) pour permettre aux utilisateurs de se connecter via leur compte Facebook (authentification OAuth). 

Le Facebook SDK collecte automatiquement l'identifiant publicitaire (Advertising ID / AD_ID) pour des fins d'analytics et de mesure de performance des événements d'authentification, conformément aux pratiques standard du SDK Facebook.

Cette collecte est activée via la configuration du Facebook SDK dans le manifest Android (com.facebook.sdk.AdvertiserIDCollectionEnabled) et est nécessaire pour :
- Mesurer l'efficacité des événements d'authentification Facebook
- Analyser les conversions et l'engagement utilisateur
- Respecter les exigences du SDK Facebook pour l'authentification OAuth

L'application n'affiche PAS de publicités et n'utilise pas l'identifiant publicitaire pour cibler des publicités. L'identifiant est collecté uniquement par le SDK Facebook dans le cadre de l'authentification sociale et de l'analyse des événements d'authentification.

L'utilisateur peut désactiver la collecte de l'identifiant publicitaire via les paramètres de son appareil Android (Paramètres → Google → Publicités → Réinitialiser l'ID publicitaire ou Désactiver les publicités personnalisées).
```

---

## 🎯 Version Courte (si limite de caractères)

```
L'application utilise le Facebook SDK pour l'authentification OAuth. Le SDK Facebook collecte automatiquement l'identifiant publicitaire (AD_ID) pour l'analyse des événements d'authentification et la mesure de performance, conformément aux pratiques standard du SDK. L'application n'affiche pas de publicités et n'utilise pas l'identifiant pour le ciblage publicitaire. La collecte est uniquement liée à l'authentification sociale via Facebook.
```

---

## 📋 Contexte Technique

### Pourquoi l'AD_ID est présent

1. **Facebook SDK (flutter_facebook_auth)** :
   - Utilisé pour l'authentification OAuth Facebook
   - Le SDK collecte automatiquement l'AD_ID pour l'analytics
   - Configuration dans `AndroidManifest.xml` : `com.facebook.sdk.AdvertiserIDCollectionEnabled = true`

2. **Google Sign-In SDK** :
   - Utilisé pour l'authentification OAuth Google
   - Peut également collecter l'AD_ID pour l'analytics

### Utilisation de l'AD_ID

- ✅ **Analytics** : Mesure des événements d'authentification
- ✅ **Performance** : Analyse de l'efficacité des connexions sociales
- ❌ **Publicités** : L'application n'affiche PAS de publicités
- ❌ **Ciblage** : L'identifiant n'est PAS utilisé pour cibler des publicités

---

## 🔍 Vérification

### SDKs qui peuvent collecter l'AD_ID

1. **flutter_facebook_auth** (Facebook SDK)
   - Configuration : `com.facebook.sdk.AdvertiserIDCollectionEnabled = true`
   - Usage : Authentification OAuth + Analytics

2. **google_sign_in** (Google Sign-In SDK)
   - Usage : Authentification OAuth + Analytics

### SDKs qui n'utilisent PAS l'AD_ID

- ❌ Aucun SDK de publicité (AdMob, etc.)
- ❌ Aucun SDK de tracking publicitaire
- ❌ Aucun SDK de monétisation

---

## ⚠️ Points Importants à Mentionner

1. **Pas de publicités** : L'application n'affiche aucune publicité
2. **Authentification uniquement** : L'AD_ID est collecté uniquement dans le cadre de l'authentification sociale
3. **Respect de la vie privée** : L'utilisateur peut désactiver la collecte via les paramètres Android
4. **Conformité** : Conforme aux politiques Google Play et aux pratiques standard des SDKs d'authentification

---

## 📌 Réponse Finale pour Play Console

### Question : "Votre appli utilise-t-elle un identifiant publicitaire ?"

**Réponse :** ✅ **Oui**

### Justification (copier-coller) :

```
L'application Jirig utilise le Facebook SDK (flutter_facebook_auth) pour permettre aux utilisateurs de se connecter via leur compte Facebook (authentification OAuth). 

Le Facebook SDK collecte automatiquement l'identifiant publicitaire (Advertising ID / AD_ID) pour des fins d'analytics et de mesure de performance des événements d'authentification, conformément aux pratiques standard du SDK Facebook.

Cette collecte est activée via la configuration du Facebook SDK dans le manifest Android (com.facebook.sdk.AdvertiserIDCollectionEnabled) et est nécessaire pour :
- Mesurer l'efficacité des événements d'authentification Facebook
- Analyser les conversions et l'engagement utilisateur
- Respecter les exigences du SDK Facebook pour l'authentification OAuth

L'application n'affiche PAS de publicités et n'utilise pas l'identifiant publicitaire pour cibler des publicités. L'identifiant est collecté uniquement par le SDK Facebook dans le cadre de l'authentification sociale et de l'analyse des événements d'authentification.

L'utilisateur peut désactiver la collecte de l'identifiant publicitaire via les paramètres de son appareil Android (Paramètres → Google → Publicités → Réinitialiser l'ID publicitaire ou Désactiver les publicités personnalisées).
```

---

## ✅ Checklist

Avant de soumettre :

- [ ] ✅ Répondu "Oui" à la question sur l'identifiant publicitaire
- [ ] ✅ Justification copiée dans le formulaire Play Console
- [ ] ✅ Vérifié que l'explication est claire et précise
- [ ] ✅ Confirmé que l'application n'affiche pas de publicités

---

**Date de création** : $(date)  
**Version de l'app** : 1.0.0+1  
**Statut** : ✅ Explication prête pour Play Console

