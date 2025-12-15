# 📝 Guide de modification du Backend pour Deep Links Mobile

## 🎯 Objectif

Modifier le backend SNAL-Project (Nuxt 3) pour que la route `/connexion` détecte les appareils mobiles et redirige vers l'app mobile au lieu du site web.

---

## 📋 Fichier à modifier

**Fichier :** `SNAL-Project/app/pages/connexion.vue`

**Ligne :** 257 (dans `onMounted()`)

---

## 🔧 Modification à effectuer

### **Code actuel (lignes 257-294) :**

```vue
<script lang="ts" setup>
// ... (imports et setup existants)

// Handle magic link from URL
onMounted(async () => {
  const emailParam = route.query.email as string | undefined;
  const tokenParam = route.query.token as string | undefined;
  const callBackUrl = route.query.callBackUrl as string;
  
  console.log('callBackUrl-view', callBackUrl);
  console.log('emailParam', emailParam);
  console.log('tokenParam', tokenParam);
  
  if (emailParam && tokenParam) {
    console.log('Step Redirect with magic link');
    email.value = emailParam;
    password.value = tokenParam;
    awaitingToken.value = true;
    loading.value = true;
    
    try {
      // Connexion automatique
      await $fetch("/api/auth/login", {
        method: "POST",
        body: {
          email: email.value,
          password: password.value,
        },
      });
      
      await fetchUserSession();
      
      if(callBackUrl){
        await navigateTo(callBackUrl);
      } else {
        await navigateTo("/");
      }
    } catch (e) {
      console.error("Magic link login failed", e);
    } finally {
      loading.value = false;
    }
  }
});
</script>
```

---

### **Code modifié (avec détection mobile) :**

```vue
<script lang="ts" setup>
// ... (imports et setup existants - garder tel quel)

// ✅ FONCTION AJOUTÉE : Détecter si c'est un appareil mobile
const isMobileDevice = () => {
  if (process.client) {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }
  return false;
};

// Handle magic link from URL
onMounted(async () => {
  const emailParam = route.query.email as string | undefined;
  const tokenParam = route.query.token as string | undefined;
  const callBackUrl = route.query.callBackUrl as string;
  
  console.log('callBackUrl-view', callBackUrl);
  console.log('emailParam', emailParam);
  console.log('tokenParam', tokenParam);
  
  if (emailParam && tokenParam) {
    console.log('Step Redirect with magic link');
    
    // ✅ DÉTECTION MOBILE AJOUTÉE
    const isMobile = isMobileDevice();
    console.log('Est mobile ?', isMobile);
    
    if (isMobile) {
      // ✅ SUR MOBILE : Rediriger vers l'app via deep link
      console.log('Mobile détecté - Redirection vers l\'app mobile');
      
      const deepLink = `jirig://magic-login?email=${encodeURIComponent(emailParam)}&token=${encodeURIComponent(tokenParam)}&callBackUrl=${encodeURIComponent(callBackUrl || '/')}`;
      console.log('Deep link:', deepLink);
      
      // Tenter d'ouvrir l'app
      window.location.href = deepLink;
      
      // Si l'app ne s'ouvre pas dans 3 secondes, afficher un message
      setTimeout(() => {
        // Afficher un message avec bouton pour télécharger l'app
        document.body.innerHTML = `
          <div style="font-family: Arial, sans-serif; padding: 40px; text-align: center;">
            <div style="max-width: 400px; margin: 0 auto; background: white; padding: 30px; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
              <div style="font-size: 48px; margin-bottom: 20px;">📱</div>
              <h2 style="color: #0058A3; margin-bottom: 16px;">Ouvrir l'application Jirig</h2>
              <p style="color: #666; margin-bottom: 24px;">Cliquez sur le bouton ci-dessous pour ouvrir l'application</p>
              <a href="${deepLink}" style="display: inline-block; background: #0058A3; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; margin-bottom: 16px;">
                Ouvrir l'application
              </a>
              <br>
              <a href="https://play.google.com/store/apps/details?id=com.jirig.app" style="color: #0058A3; font-size: 14px;">
                Télécharger l'application
              </a>
            </div>
          </div>
        `;
      }, 3000);
      
      return; // ✅ Arrêter ici pour mobile
    }
    
    // ✅ SUR WEB : Continuer avec le flux normal (code existant)
    email.value = emailParam;
    password.value = tokenParam;
    awaitingToken.value = true;
    loading.value = true;
    
    try {
      // Connexion automatique
      await $fetch("/api/auth/login", {
        method: "POST",
        body: {
          email: email.value,
          password: password.value,
        },
      });
      
      await fetchUserSession();
      
      if(callBackUrl){
        await navigateTo(callBackUrl);
      } else {
        await navigateTo("/");
      }
    } catch (e) {
      console.error("Magic link login failed", e);
    } finally {
      loading.value = false;
    }
  }
});
</script>
```

---

## 📝 Étapes détaillées pour appliquer la modification

### **Étape 1 : Ouvrir le fichier**

1. Naviguer vers le projet backend :
   ```bash
   cd "C:\Users\simplon\Documents\Developement Web\flutter\Jirig_front\SNAL-Project"
   ```

2. Ouvrir le fichier :
   ```bash
   code app/pages/connexion.vue
   ```

---

### **Étape 2 : Ajouter la fonction de détection mobile**

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

### **Étape 3 : Modifier le onMounted**

**Remplacer tout le bloc `onMounted`** (lignes 257-294) par le code modifié ci-dessus.

**Points clés de la modification :**
1. ✅ Appel de `isMobileDevice()` au début
2. ✅ `if (isMobile)` → Redirection vers deep link `jirig://magic-login`
3. ✅ `else` → Flux normal pour web (code existant)
4. ✅ Timeout de 3 secondes avec interface de secours

---

### **Étape 4 : Sauvegarder et tester**

1. **Sauvegarder le fichier** (`Ctrl+S`)

2. **Redémarrer le serveur Nuxt** (si nécessaire) :
   ```bash
   # Dans SNAL-Project
   npm run dev
   # ou
   pm2 restart nuxt-app
   ```

3. **Tester en production** :
   - Demander un magic link depuis l'app mobile
   - Ouvrir l'email sur mobile
   - Cliquer sur le lien
   - **Résultat attendu :** L'app mobile s'ouvre au lieu du site web

---

## 🔍 Explication technique

### **Avant la modification :**

```
Email → Clic lien → Backend Nuxt → Page web /connexion
                                    ↓
                              Connexion sur le site web ❌
```

### **Après la modification :**

```
Email → Clic lien → Backend Nuxt détecte mobile
                           ↓
                    Redirection vers jirig://magic-login
                           ↓
                    Android intercepte → App s'ouvre ✅
```

---

## 📊 Flux complet après modification

### **Mobile :**

```
┌─────────────────────────────────────────────────────┐
│ 1. Email reçu avec lien                             │
│    https://jirig.be/connexion?email=...&token=...   │
│    ↓                                                 │
│ 2. Clic sur le lien (depuis mobile)                 │
│    ↓                                                 │
│ 3. Backend Nuxt charge /connexion                   │
│    ↓                                                 │
│ 4. onMounted() s'exécute                            │
│    ↓                                                 │
│ 5. isMobileDevice() → true                          │
│    ↓                                                 │
│ 6. Redirection JavaScript :                         │
│    window.location.href = "jirig://magic-login..."  │
│    ↓                                                 │
│ 7. Android intercepte le deep link                  │
│    ↓                                                 │
│ 8. App mobile s'ouvre                               │
│    ↓                                                 │
│ 9. DeepLinkService traite le lien                   │
│    ↓                                                 │
│ 10. Dialogue de confirmation                        │
│    ↓                                                 │
│ 11. Connexion réussie ✅                            │
└─────────────────────────────────────────────────────┘
```

### **Web (Desktop) :**

```
┌─────────────────────────────────────────────────────┐
│ 1. Email reçu avec lien                             │
│    ↓                                                 │
│ 2. Clic sur le lien (depuis desktop)                │
│    ↓                                                 │
│ 3. Backend Nuxt charge /connexion                   │
│    ↓                                                 │
│ 4. onMounted() s'exécute                            │
│    ↓                                                 │
│ 5. isMobileDevice() → false                         │
│    ↓                                                 │
│ 6. Flux normal (code existant) :                    │
│    - Appel API /api/auth/login                      │
│    - fetchUserSession()                             │
│    - navigateTo(callBackUrl)                        │
│    ↓                                                 │
│ 7. Connexion réussie sur le site web ✅            │
└─────────────────────────────────────────────────────┘
```

---

## ✅ Avantages de cette approche

### **🟢 Pour Mobile :**
- ✅ Détection automatique de l'appareil
- ✅ Redirection vers l'app mobile
- ✅ Interface de secours si l'app n'est pas installée
- ✅ Aucun fichier HTML supplémentaire à déployer

### **🟢 Pour Web :**
- ✅ Aucun changement du comportement existant
- ✅ Connexion automatique comme avant
- ✅ Redirection vers callBackUrl

### **🟢 Pour le développeur :**
- ✅ 1 seul fichier à modifier
- ✅ Code simple et lisible
- ✅ Facile à tester et débugger
- ✅ Pas de déploiement de fichiers statiques

---

## 🧪 Tests à effectuer

### **Test 1 : Mobile - Avec app installée**

1. **Installer l'app sur mobile**
2. **Demander un magic link** depuis l'app
3. **Ouvrir l'email sur le même appareil**
4. **Cliquer sur le lien**
5. **Résultat attendu :**
   - Page Nuxt se charge brièvement
   - Redirection automatique vers `jirig://magic-login`
   - App s'ouvre
   - Dialogue de confirmation apparaît

---

### **Test 2 : Mobile - Sans app installée**

1. **Désinstaller l'app** (ou utiliser un autre appareil)
2. **Cliquer sur un magic link**
3. **Résultat attendu :**
   - Page Nuxt se charge
   - Redirection vers `jirig://magic-login` tentée
   - Après 3 secondes : Interface avec bouton "Télécharger l'app"

---

### **Test 3 : Desktop/Web**

1. **Ouvrir l'email sur desktop**
2. **Cliquer sur le lien**
3. **Résultat attendu :**
   - Page Nuxt se charge
   - Connexion automatique (comme avant)
   - Redirection vers callBackUrl
   - ✅ Comportement identique à l'existant

---

## 🔍 Code détaillé avec commentaires

```vue
<script lang="ts" setup>
definePageMeta({
  layout: "old",
});
import { useColorApp } from "../composables/useColorApp";
const { loggedIn, fetch: fetchUserSession } = useUserSession();
const {getCallBackUrl} = useAppCookies();
const { colorapp, color01, color02, color03, color04 } = useColorApp();
const route = useRoute();
const router = useRouter();
const loading = ref(false);
const email = ref("");
const password = ref("");
const awaitingToken = ref(false);
const showMailModal = ref(false);

// ✅ NOUVELLE FONCTION : Détecter les appareils mobiles
const isMobileDevice = () => {
  // Vérifier qu'on est côté client (navigateur)
  if (process.client) {
    // Regex pour détecter les User-Agents mobiles
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  }
  return false;
};

// Handle magic link from URL
onMounted(async () => {
  const emailParam = route.query.email as string | undefined;
  const tokenParam = route.query.token as string | undefined;
  const callBackUrl = route.query.callBackUrl as string;
  
  console.log('🔗 Connexion - Paramètres reçus:');
  console.log('  callBackUrl:', callBackUrl);
  console.log('  emailParam:', emailParam);
  console.log('  tokenParam:', tokenParam ? '***' : 'absent');
  
  if (emailParam && tokenParam) {
    console.log('✅ Magic link détecté');
    
    // ✅ DÉTECTION MOBILE
    const isMobile = isMobileDevice();
    console.log('📱 Appareil mobile ?', isMobile);
    
    if (isMobile) {
      // ✅ MOBILE : Rediriger vers l'app via deep link
      console.log('🔄 Redirection vers l\'app mobile...');
      
      // Construire le deep link
      const deepLink = `jirig://magic-login?email=${encodeURIComponent(emailParam)}&token=${encodeURIComponent(tokenParam)}&callBackUrl=${encodeURIComponent(callBackUrl || '/')}`;
      console.log('🔗 Deep link:', deepLink);
      
      // Rediriger vers l'app mobile
      window.location.href = deepLink;
      
      // Si l'app ne s'ouvre pas dans 3 secondes, afficher une interface
      setTimeout(() => {
        console.log('⚠️ App non ouverte - Affichage interface de secours');
        
        document.body.innerHTML = `
          <div style="
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #0058A3 0%, #0078D4 100%);
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            padding: 20px;
          ">
            <div style="
              background: white;
              padding: 40px;
              border-radius: 20px;
              box-shadow: 0 10px 40px rgba(0,0,0,0.2);
              max-width: 400px;
              width: 100%;
              text-align: center;
            ">
              <div style="font-size: 64px; margin-bottom: 20px;">📱</div>
              <h2 style="color: #0058A3; font-size: 24px; font-weight: bold; margin-bottom: 16px;">
                Ouvrir l'application Jirig
              </h2>
              <p style="color: #666; margin-bottom: 32px; line-height: 1.6;">
                Cliquez sur le bouton ci-dessous pour ouvrir l'application mobile
              </p>
              <a href="${deepLink}" style="
                display: inline-block;
                background: #0058A3;
                color: white;
                padding: 16px 32px;
                text-decoration: none;
                border-radius: 12px;
                font-weight: bold;
                font-size: 16px;
                margin-bottom: 20px;
                box-shadow: 0 4px 12px rgba(0,88,163,0.3);
              ">
                🚀 Ouvrir l'app
              </a>
              <br>
              <a href="https://play.google.com/store/apps/details?id=com.jirig.app" style="
                color: #0058A3;
                font-size: 14px;
                text-decoration: underline;
              ">
                Télécharger l'application
              </a>
            </div>
          </div>
        `;
      }, 3000);
      
      return; // Arrêter l'exécution ici pour mobile
    }
    
    // ✅ WEB : Code original (inchangé)
    console.log('💻 Web détecté - Connexion normale');
    email.value = emailParam;
    password.value = tokenParam;
    awaitingToken.value = true;
    loading.value = true;
    
    try {
      await $fetch("/api/auth/login", {
        method: "POST",
        body: {
          email: email.value,
          password: password.value,
        },
      });
      
      await fetchUserSession();
      
      if(callBackUrl){
        await navigateTo(callBackUrl);
      } else {
        await navigateTo("/");
      }
    } catch (e) {
      console.error("Magic link login failed", e);
    } finally {
      loading.value = false;
    }
  }
});

// ... (reste du code inchangé)
</script>
```

---

## 📦 Fichiers à modifier

| Fichier | Emplacement | Modifications |
|---------|-------------|---------------|
| `connexion.vue` | `SNAL-Project/app/pages/connexion.vue` | ✅ Ajouter fonction `isMobileDevice()` |
|  |  | ✅ Modifier `onMounted()` |

---

## 🚀 Déploiement

### **En développement local :**

```bash
cd SNAL-Project
npm run dev
# Le serveur redémarre automatiquement
```

### **En production :**

```bash
cd SNAL-Project
npm run build
pm2 restart nuxt-app
# ou selon votre config de déploiement
```

---

## ✅ Checklist de vérification

### **Avant modification :**
- [ ] Backup du fichier `connexion.vue` effectué
- [ ] Accès au serveur backend disponible
- [ ] Environnement de développement prêt

### **Après modification :**
- [ ] Fonction `isMobileDevice()` ajoutée
- [ ] `onMounted()` modifié avec détection mobile
- [ ] Code sauvegardé
- [ ] Serveur redémarré

### **Tests :**
- [ ] Test mobile avec app installée → App s'ouvre ✅
- [ ] Test mobile sans app → Interface de téléchargement ✅
- [ ] Test web/desktop → Connexion normale ✅

---

## 🔧 Debugging

### **Logs à vérifier (Console navigateur) :**

```javascript
🔗 Connexion - Paramètres reçus:
  callBackUrl: /wishlist/0x...
  emailParam: choupettecoly66@gmail.com
  tokenParam: ***
✅ Magic link détecté
📱 Appareil mobile ? true
🔄 Redirection vers l'app mobile...
🔗 Deep link: jirig://magic-login?email=...&token=...
```

### **Si l'app ne s'ouvre pas :**

1. Vérifier que le deep link est bien formé
2. Vérifier que l'app est installée
3. Vérifier l'AndroidManifest (intent-filter)
4. Tester manuellement avec `adb` :
   ```bash
   adb shell am start -W -a android.intent.action.VIEW \
     -d "jirig://magic-login?email=test@example.com&token=TEST&callBackUrl=/wishlist"
   ```

---

## 📝 Alternative : Middleware Nuxt

Si tu préfères une approche plus globale, tu peux créer un middleware :

**Créer `SNAL-Project/server/middleware/mobile-redirect.ts` :**

```typescript
export default defineEventHandler((event) => {
  const url = getRequestURL(event);
  
  // Vérifier si c'est la route /connexion
  if (url.pathname === '/connexion') {
    const userAgent = getRequestHeader(event, 'user-agent') || '';
    const isMobile = /Android|webOS|iPhone|iPad|iPod/i.test(userAgent);
    
    if (isMobile) {
      const email = url.searchParams.get('email');
      const token = url.searchParams.get('token');
      const callBackUrl = url.searchParams.get('callBackUrl') || '/';
      
      if (email && token) {
        const deepLink = `jirig://magic-login?email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}&callBackUrl=${encodeURIComponent(callBackUrl)}`;
        
        // Retourner une page HTML de redirection
        return `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <title>Redirection...</title>
            <script>window.location.href = "${deepLink}";</script>
          </head>
          <body>
            <p>Redirection vers l'application...</p>
          </body>
          </html>
        `;
      }
    }
  }
});
```

**Avantage :** Gère toutes les routes automatiquement

---

## 🎯 Recommandation finale

**Modifier `connexion.vue`** est la solution la plus simple :
- ✅ 1 seul fichier à modifier
- ✅ Pas de middleware supplémentaire
- ✅ Code clair et facile à maintenir
- ✅ Fonctionne immédiatement

**Temps estimé :** 10 minutes (modification + test)

---

## ✅ Résultat attendu

Après cette modification, quand tu cliques sur un magic link depuis mobile :
1. ✅ Le backend détecte que c'est mobile
2. ✅ Il redirige vers `jirig://magic-login`
3. ✅ Android ouvre ton app
4. ✅ L'utilisateur se connecte dans l'app

**Plus besoin de déployer des fichiers HTML externes ! 🎉**
