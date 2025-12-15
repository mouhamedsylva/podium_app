# 📝 Guide complet : Modifier le Backend pour Deep Links Mobile

## 🎯 Objectif

Modifier le backend SNAL-Project (Nuxt 3) pour que les redirections OAuth et Magic Links fonctionnent correctement avec l'app mobile Flutter.

---

## 📦 Fichiers à modifier

| Fichier | Rôle | Modification |
|---------|------|--------------|
| `app/pages/connexion.vue` | Page de connexion magic link | ✅ Détection mobile + redirection |
| `server/api/auth/google.get.ts` | OAuth Google callback | ✅ Gérer callBackUrl + détection mobile |
| `server/api/auth/facebook.get.ts` | OAuth Facebook callback | ✅ Gérer callBackUrl + détection mobile |

---

## 🔧 MODIFICATION 1 : connexion.vue (Magic Links)

### **Fichier :** `SNAL-Project/app/pages/connexion.vue`

### **Étape 1 : Ajouter la fonction de détection mobile**

**Après la ligne 255** (après `const showMailModal = ref(false);`), ajouter :

```typescript
// ✅ Détecter si c'est un appareil mobile
const isMobileDevice = () => {
  if (process.client) {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }
  return false;
};
```

---

### **Étape 2 : Modifier le onMounted**

**Remplacer le bloc `onMounted`** (lignes 257-294) par :

```typescript
// Handle magic link from URL
onMounted(async () => {
  const emailParam = route.query.email as string | undefined;
  const tokenParam = route.query.token as string | undefined;
  const callBackUrl = route.query.callBackUrl as string;
  
  console.log('🔗 Connexion - Paramètres:', { emailParam, tokenParam: tokenParam ? '***' : null, callBackUrl });
  
  if (emailParam && tokenParam) {
    console.log('✅ Magic link détecté');
    
    // ✅ Détection mobile
    const isMobile = isMobileDevice();
    console.log('📱 Appareil mobile ?', isMobile);
    
    if (isMobile) {
      // ✅ MOBILE : Rediriger vers l'app
      console.log('🔄 Redirection vers app mobile');
      
      const deepLink = `jirig://magic-login?email=${encodeURIComponent(emailParam)}&token=${encodeURIComponent(tokenParam)}&callBackUrl=${encodeURIComponent(callBackUrl || '/')}`;
      console.log('🔗 Deep link:', deepLink);
      
      window.location.href = deepLink;
      
      // Interface de secours après 3 secondes
      setTimeout(() => {
        document.body.innerHTML = `
          <div style="min-height: 100vh; display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg, #0058A3 0%, #0078D4 100%); padding: 20px;">
            <div style="background: white; padding: 40px; border-radius: 20px; max-width: 400px; text-align: center;">
              <div style="font-size: 64px; margin-bottom: 20px;">📱</div>
              <h2 style="color: #0058A3; font-size: 24px; margin-bottom: 16px;">Ouvrir l'application Jirig</h2>
              <a href="${deepLink}" style="display: inline-block; background: #0058A3; color: white; padding: 16px 32px; text-decoration: none; border-radius: 12px; font-weight: bold; margin: 20px 0;">🚀 Ouvrir l'app</a>
              <br>
              <a href="https://play.google.com/store/apps/details?id=com.jirig.app" style="color: #0058A3; font-size: 14px;">Télécharger l'application</a>
            </div>
          </div>
        `;
      }, 3000);
      
      return;
    }
    
    // ✅ WEB : Flux normal
    console.log('💻 Web - Connexion normale');
    email.value = emailParam;
    password.value = tokenParam;
    awaitingToken.value = true;
    loading.value = true;
    
    try {
      await $fetch("/api/auth/login", {
        method: "POST",
        body: { email: email.value, password: password.value },
      });
      
      await fetchUserSession();
      await navigateTo(callBackUrl || "/");
    } catch (e) {
      console.error("Magic link login failed", e);
    } finally {
      loading.value = false;
    }
  }
});
```

---

## 🔧 MODIFICATION 2 : google.get.ts (OAuth Google)

### **Fichier :** `SNAL-Project/server/api/auth/google.get.ts`

### **Problème actuel :**

Ligne 135 :
```typescript
return sendRedirect(event, "/");
```

**Problème :** Redirige toujours vers `/` au lieu du `callBackUrl`

---

### **Solution : Gérer le callBackUrl**

**Remplacer la ligne 135** par :

```typescript
// ✅ Récupérer le callBackUrl depuis les query parameters
const query = getQuery(event);
const callBackUrl = query.callBackUrl as string || '/';

console.log('🔄 OAuth Google réussi - Redirection vers:', callBackUrl);

// ✅ Rediriger vers le callBackUrl (ou "/" par défaut)
return sendRedirect(event, callBackUrl);
```

---

### **Code complet modifié (lignes 20-143) :**

```typescript
async onSuccess(event, { user }) {
  try {
    console.log('google.get.ts : Received user data from Google:', JSON.stringify(user, null, 2))

    const { getGuestProfile, setGuestProfile, setiBasketFromInitialization } =
      useAppCookies(event);
    const guestProfile = getGuestProfile();

    let sPaysListe = guestProfile.sPaysFav || "";
    let sPaysLangue = guestProfile.sPaysLangue || "";
    let sTypeAccount = "EMAIL";

    const nom = user.family_name || "";
    const prenom = user.given_name || "";
    const email = user.email || "";
    const sProviderId = user.sub || "";

    const sProvider = "google";
    const xXml = `
      <root>
        <email>${email}</email>
        <sProviderId>${sProviderId}</sProviderId>
        <sProvider>${sProvider}</sProvider>
        <nom>${nom}</nom>
        <prenom>${prenom}</prenom>
        <sTypeAccount>${sTypeAccount}</sTypeAccount>
        <iPaysOrigine>${sPaysLangue}</iPaysOrigine>
        <sLangue>${sPaysLangue}</sLangue>
        <sPaysListe>${sPaysListe}</sPaysListe>
        <sPaysLangue>${sPaysLangue}</sPaysLangue>
      </root>
      `.trim();
    console.log("xXml", xXml);

    const pool = await connectToDatabase();

    const newProfile = await pool
      .request()
      .input("xXml", sql.Xml, xXml)
      .execute("dbo.proc_user_signup_4All_user_v2");

    let profileData = newProfile.recordset[0];
    console.log('profileData from google', profileData);
    
    let profileBasket;
    let newProfileData;
    if (profileData && profileData.iProfile) {
      profileBasket = await pool
        .request()
        .input("profileId", profileData.iProfile)
        .query("SELECT top 1 iBasket FROM dbo.Baskets WHERE iProfile = @profileId");
      
      newProfileData = profileBasket.recordset[0];
      console.log("iBasket from google", newProfileData);
    }

    let basketInit = profileData.iBasketProfil;
    console.log('basketInit', basketInit)
    
    if (profileData) {
      setGuestProfile({
        iProfile: profileData.iProfileEncrypted,
        iBasket: profileData.iBasketProfil,
        sPaysLangue: profileData.sPaysLangue,
      });
    }
    
    setiBasketFromInitialization(basketInit);
    
    await setUserSession(event, {
      user: {
        iProfile: profileData.iProfile,
        sNom: profileData.sNom,
        sPrenom: profileData.sPrenom,
        sEmail: profileData.sEmail,
        sPhoto: profileData.sPhoto,
        sRue: profileData.sRue,
        sZip: profileData.sZip,
        sCity: profileData.sCity,
        iPays: profileData.iPays,
        sTel: profileData.sTel,
        sLangue: profileData.sLangue,
        sPaysFav: profileData.sPaysFav,
        sTypeAccount: profileData.sTypeAccount,
        sPaysLangue: profileData.sPaysLangue,
      },
      loggedInAt: Date.now(),
      loggedIn: true,
    });
    
    // ✅ MODIFICATION ICI : Gérer le callBackUrl
    const query = getQuery(event);
    let callBackUrl = query.callBackUrl as string || '/';
    
    // Si le callBackUrl est encodé, le décoder
    if (callBackUrl.startsWith('%2F') || callBackUrl.includes('%')) {
      callBackUrl = decodeURIComponent(callBackUrl);
    }
    
    console.log('🔄 OAuth Google réussi - Redirection vers:', callBackUrl);
    
    return sendRedirect(event, callBackUrl);
  } catch (error: any) {
    console.error("Error during Google authentication:", error);
    throw createError({
      statusCode: 500,
      message: "An error occurred during authentication",
    });
  }
},
```

---

## 🔧 MODIFICATION 3 : facebook.get.ts (OAuth Facebook)

### **Fichier :** `SNAL-Project/server/api/auth/facebook.get.ts`

**Même modification que pour Google** (chercher `sendRedirect` et ajouter la gestion du `callBackUrl`)

---

## 📊 Récapitulatif des modifications

### **1. `connexion.vue` (Magic Links)**

**Avant :**
```typescript
onMounted(async () => {
  if (emailParam && tokenParam) {
    // Connexion automatique sur web
    await $fetch("/api/auth/login", ...);
    await navigateTo(callBackUrl || "/");
  }
});
```

**Après :**
```typescript
onMounted(async () => {
  if (emailParam && tokenParam) {
    if (isMobileDevice()) {
      // ✅ Redirection vers app mobile
      window.location.href = "jirig://magic-login?...";
    } else {
      // Connexion web normale
      await $fetch("/api/auth/login", ...);
      await navigateTo(callBackUrl || "/");
    }
  }
});
```

---

### **2. `google.get.ts` et `facebook.get.ts` (OAuth)**

**Avant :**
```typescript
return sendRedirect(event, "/");
```

**Après :**
```typescript
const query = getQuery(event);
const callBackUrl = decodeURIComponent(query.callBackUrl as string || '/');
return sendRedirect(event, callBackUrl);
```

---

## 🧪 Tests après modifications

### **Test 1 : Magic Link sur mobile**

1. Demander un magic link depuis l'app mobile
2. Ouvrir l'email sur mobile
3. Cliquer sur le lien
4. **Résultat attendu :**
   - Backend détecte mobile
   - Redirection vers `jirig://magic-login`
   - App s'ouvre
   - Dialogue de confirmation
   - Connexion réussie

---

### **Test 2 : Magic Link sur web**

1. Demander un magic link
2. Ouvrir l'email sur desktop
3. Cliquer sur le lien
4. **Résultat attendu :**
   - Connexion automatique sur le site web
   - Redirection vers callBackUrl
   - Pas d'impact sur le flux existant

---

### **Test 3 : OAuth sur mobile**

1. Cliquer sur "Continuer avec Google" dans l'app
2. WebView s'ouvre
3. Se connecter avec Google
4. **Résultat attendu :**
   - Google redirige vers `/api/auth/google`
   - Backend traite et redirige vers callBackUrl (`/oauth/callback`)
   - WebView détecte la redirection
   - WebView se ferme
   - App continue normalement

---

## 🚀 Commandes de déploiement

### **Développement local :**

```bash
cd SNAL-Project

# Redémarrer le serveur
npm run dev
```

### **Production (selon votre config) :**

```bash
cd SNAL-Project

# Build
npm run build

# Redémarrer (PM2)
pm2 restart nuxt-app

# Ou Docker
docker-compose restart backend
```

---

## 📝 Logs à vérifier

### **Dans la console navigateur (mobile) :**

```
🔗 Connexion - Paramètres: { emailParam: "...", callBackUrl: "/wishlist/..." }
✅ Magic link détecté
📱 Appareil mobile ? true
🔄 Redirection vers app mobile
🔗 Deep link: jirig://magic-login?email=...&token=...
```

### **Dans les logs serveur (OAuth) :**

```
google.get.ts : Received user data from Google: {...}
profileData from google {...}
🔄 OAuth Google réussi - Redirection vers: /oauth/callback?redirect=/wishlist
```

---

## ⚠️ Points d'attention

### **1. Sécurité**

Le `callBackUrl` vient de l'URL. Ajouter une validation :

```typescript
// Valider que le callBackUrl est une route interne
const isValidCallBack = (url: string) => {
  return url.startsWith('/') && !url.includes('//');
};

const callBackUrl = isValidCallBack(query.callBackUrl) 
  ? query.callBackUrl 
  : '/';
```

---

### **2. Encodage**

Les URLs peuvent être encodées (`%2F` au lieu de `/`) :

```typescript
// Toujours décoder
const callBackUrl = decodeURIComponent(query.callBackUrl as string || '/');
```

---

### **3. Compatibilité**

Tester sur différents navigateurs mobiles :
- ✅ Chrome Android
- ✅ Safari iOS
- ✅ Samsung Internet
- ✅ Firefox Mobile

---

## 🎯 Alternative : Créer un middleware global

Si tu veux une solution plus élégante, crée un middleware :

### **Créer `SNAL-Project/server/middleware/mobile-deep-link.ts` :**

```typescript
export default defineEventHandler((event) => {
  const url = getRequestURL(event);
  
  // Vérifier si c'est la route /connexion avec paramètres
  if (url.pathname === '/connexion') {
    const userAgent = getRequestHeader(event, 'user-agent') || '';
    const isMobile = /Android|webOS|iPhone|iPad|iPod/i.test(userAgent);
    
    if (isMobile) {
      const email = url.searchParams.get('email');
      const token = url.searchParams.get('token');
      const callBackUrl = url.searchParams.get('callBackUrl') || '/';
      
      if (email && token) {
        console.log('📱 Middleware : Redirection mobile détectée');
        
        const deepLink = `jirig://magic-login?email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}&callBackUrl=${encodeURIComponent(callBackUrl)}`;
        
        // Retourner une page HTML de redirection
        setResponseStatus(event, 200);
        setResponseHeader(event, 'Content-Type', 'text/html');
        
        return `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Redirection...</title>
            <script>
              window.location.href = "${deepLink}";
              
              setTimeout(() => {
                document.body.innerHTML = '<div style="text-align: center; padding: 40px; font-family: Arial;"><h2>Ouvrir l\'application Jirig</h2><a href="${deepLink}" style="display: inline-block; background: #0058A3; color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; margin: 20px;">Ouvrir l\'app</a></div>';
              }, 3000);
            </script>
          </head>
          <body style="text-align: center; padding: 20px;">
            <h2>🔄 Redirection vers l'application...</h2>
          </body>
          </html>
        `;
      }
    }
  }
});
```

**Avantage :** Intercepte AVANT que la page Vue ne se charge (plus rapide)

---

## ✅ Checklist de déploiement

### **Préparation :**
- [ ] Backup des fichiers originaux
- [ ] Environnement de dev prêt
- [ ] Accès au serveur de production

### **Modifications :**
- [ ] `connexion.vue` modifié (détection mobile)
- [ ] `google.get.ts` modifié (callBackUrl)
- [ ] `facebook.get.ts` modifié (callBackUrl)
- [ ] Middleware créé (optionnel)

### **Tests :**
- [ ] Test magic link mobile → App s'ouvre
- [ ] Test magic link web → Connexion normale
- [ ] Test OAuth mobile → WebView fonctionne
- [ ] Test OAuth web → Redirection normale

### **Production :**
- [ ] Build effectué (`npm run build`)
- [ ] Déployé en production
- [ ] Tests en conditions réelles
- [ ] Logs vérifiés

---

## 🎯 Résultat final attendu

### **Magic Links - Mobile :**
```
Email → Clic → Backend détecte mobile → jirig://magic-login → App s'ouvre ✅
```

### **Magic Links - Web :**
```
Email → Clic → Backend connexion auto → Redirection web ✅
```

### **OAuth - Mobile :**
```
App → WebView → Google → Backend → /oauth/callback → WebView ferme → Connexion ✅
```

### **OAuth - Web :**
```
Site → Google → Backend → callBackUrl → Connexion ✅
```

---

## 📌 Temps estimé

- **Modification `connexion.vue`** : 5 minutes
- **Modification `google.get.ts`** : 3 minutes
- **Modification `facebook.get.ts`** : 3 minutes
- **Tests** : 10 minutes
- **Déploiement** : 5 minutes

**Total : ~25 minutes** ⏱️

---

## ✅ Conclusion

Ces modifications sont **minimales** et **non-invasives** :
- ✅ Pas de changement d'architecture
- ✅ Pas de nouvelles dépendances
- ✅ Rétrocompatible (web fonctionne comme avant)
- ✅ Ajoute juste la détection mobile

**Une fois fait, tes deep links fonctionneront parfaitement sans rien déployer d'externe ! 🚀**
