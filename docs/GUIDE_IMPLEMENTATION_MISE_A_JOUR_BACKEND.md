# Guide d'implémentation - Mise à jour de l'application (Backend SNAL-Project)

## 📋 Vue d'ensemble

Ce guide vous explique comment implémenter le système de mise à jour de l'application côté backend dans SNAL-Project. Le système permet au frontend de vérifier les nouvelles versions disponibles et de déterminer si une mise à jour est nécessaire.

---

## ✅ Prérequis

### 1. Technologies utilisées

- **Nuxt 3** avec **H3** (framework HTTP)
- **SQL Server** (base de données)
- **mssql** (driver Node.js pour SQL Server)
- **Stored Procedures** (pour la logique métier)

### 2. Structure du projet

L'endpoint doit être créé dans :
```
SNAL-Project/server/api/get-app-mobile-infos-versions.get.ts
```

---

## 🚀 Étapes d'implémentation

### Étape 1 : Créer ou modifier l'endpoint API

**Fichier : `SNAL-Project/server/api/get-app-mobile-infos-versions.get.ts`**

Remplacez le contenu actuel par le code suivant :

```typescript
import { defineEventHandler, getQuery, createError } from "h3";
import { connectToDatabase } from "../db/index";
import sql from "mssql";

/**
 * Endpoint GET pour vérifier la version de l'application mobile
 * 
 * Query parameters:
 * - version: Version actuelle de l'application (ex: "1.0.0")
 * - platform: Plateforme de l'application ("android" | "ios" | "web")
 * 
 * Response:
 * {
 *   success: boolean,
 *   updateAvailable: boolean,
 *   updateRequired: boolean,
 *   forceUpdate: boolean,
 *   latestVersion: string,
 *   minimumVersion: string,
 *   currentVersion: string,
 *   updateUrl?: string,
 *   releaseNotes?: string,
 *   platform: string
 * }
 */
export default defineEventHandler(async (event) => {
  console.log("API - get-app-mobile-infos-versions.get.ts called");
  
  let pool;
  try {
    // Récupérer les paramètres de requête
    const query = getQuery(event);
    const clientVersion = (query.version as string) || "1.0.0";
    const platform = (query.platform as string) || "web";

    console.log("🔍 Vérification de version:", { clientVersion, platform });

    // Valider la plateforme
    const validPlatforms = ["android", "ios", "web"];
    if (!validPlatforms.includes(platform.toLowerCase())) {
      throw createError({
        statusCode: 400,
        message: `Plateforme invalide: ${platform}. Plateformes valides: ${validPlatforms.join(", ")}`,
      });
    }

    // Connecter à la base de données
    pool = await connectToDatabase();
    if (!pool) {
      throw createError({
        statusCode: 500,
        message: "Connexion à la base de données non disponible.",
      });
    }

    console.log("✅ Connected to database successfully mobile infos versions");

    // Appeler la stored procedure
    // Option 1: Si la stored procedure accepte un paramètre platform
    // const result = await pool
    //   .request()
    //   .input("sPlatform", sql.VarChar(10), platform.toLowerCase())
    //   .execute("proc_App_Version_GetInfos");
    
    // Option 2: Si la stored procedure ne prend pas de paramètre (récupère toutes les plateformes)
    const result = await pool.request().execute("proc_App_Version_GetInfos");

    console.log("📦 result info mobile", result);

    // Vérifier que le recordset existe et n'est pas vide
    if (!result.recordsets || result.recordsets.length === 0 || !result.recordsets[0] || result.recordsets[0].length === 0) {
      throw createError({
        statusCode: 404,
        message: "Aucune donnée retournée par la stored procedure.",
      });
    }

    const recordset = result.recordsets[0];
    console.log("📋 recordset infos mobile", recordset);

    // Récupérer la clé dynamique (première clé de l'objet)
    const keys = Object.keys(recordset[0]);
    if (!keys || keys.length === 0) {
      throw createError({
        statusCode: 500,
        message: "Aucune clé trouvée dans le recordset.",
      });
    }

    console.log("🔑 keys infos mobile", keys);

    // Récupérer la valeur du JSON
    const jsonString = recordset[0][keys[0]];
    if (!jsonString || typeof jsonString !== "string") {
      throw createError({
        statusCode: 500,
        message: "Données JSON invalides dans le recordset.",
      });
    }

    console.log("📄 jsonString infos mobile", jsonString);

    // Parser le JSON avec gestion d'erreur
    let parsedData;
    try {
      parsedData = JSON.parse(jsonString);
      console.log("✅ parsedData infos mobile", parsedData);
    } catch (parseError: any) {
      console.error("❌ Erreur parsing JSON:", parseError);
      throw createError({
        statusCode: 500,
        message: "Erreur lors du parsing des données JSON.",
        data: { error: parseError.message },
      });
    }

    // Extraire les informations de version pour la plateforme demandée
    let platformVersion;

    // Cas 1: parsedData est un tableau, chercher l'entrée correspondant à la plateforme
    if (Array.isArray(parsedData)) {
      platformVersion = parsedData.find(
        (item: any) => item.sPlatform?.toLowerCase() === platform.toLowerCase()
      );
      
      if (!platformVersion) {
        // Si aucune entrée pour la plateforme, utiliser la première ou une valeur par défaut
        platformVersion = parsedData[0] || {};
        console.warn(`⚠️ Aucune version trouvée pour la plateforme ${platform}, utilisation de la première entrée`);
      }
    }
    // Cas 2: parsedData est un objet avec des clés par plateforme
    else if (parsedData[platform.toLowerCase()]) {
      platformVersion = parsedData[platform.toLowerCase()];
    }
    // Cas 3: parsedData est un objet unique (une seule version pour toutes les plateformes)
    else if (typeof parsedData === "object" && parsedData !== null) {
      platformVersion = parsedData;
    }
    // Cas 4: Structure inconnue, utiliser des valeurs par défaut
    else {
      console.warn("⚠️ Structure de données inattendue, utilisation de valeurs par défaut");
      platformVersion = {
        sLatestVersion: "1.0.0",
        sMinimumVersion: "1.0.0",
        bForceUpdate: false,
        sUpdateUrl: null,
        sReleaseNotes: "Version par défaut",
      };
    }

    // Extraire les valeurs avec des noms de champs flexibles
    // La stored procedure peut retourner différents noms de colonnes
    const latestVersion = 
      platformVersion.sLatestVersion || 
      platformVersion.latestVersion || 
      platformVersion.version || 
      "1.0.0";
    
    const minimumVersion = 
      platformVersion.sMinimumVersion || 
      platformVersion.minimumVersion || 
      platformVersion.minVersion || 
      "1.0.0";
    
    const forceUpdate = 
      platformVersion.bForceUpdate !== undefined ? platformVersion.bForceUpdate : 
      platformVersion.forceUpdate !== undefined ? platformVersion.forceUpdate : 
      false;
    
    const updateUrl = 
      platformVersion.sUpdateUrl || 
      platformVersion.updateUrl || 
      platformVersion.url || 
      null;
    
    const releaseNotes = 
      platformVersion.sReleaseNotes || 
      platformVersion.releaseNotes || 
      platformVersion.notes || 
      null;

    console.log("📊 Informations de version extraites:", {
      latestVersion,
      minimumVersion,
      forceUpdate,
      updateUrl,
      releaseNotes,
    });

    // Comparer les versions
    const isUpdateRequired = compareVersions(clientVersion, minimumVersion) < 0;
    const isUpdateAvailable = compareVersions(clientVersion, latestVersion) < 0;

    console.log("🔍 Comparaison de versions:", {
      clientVersion,
      latestVersion,
      minimumVersion,
      isUpdateRequired,
      isUpdateAvailable,
    });

    // Construire la réponse
    const response = {
      success: true,
      updateAvailable: isUpdateAvailable,
      updateRequired: isUpdateRequired,
      forceUpdate: forceUpdate && isUpdateRequired,
      latestVersion: latestVersion,
      minimumVersion: minimumVersion,
      currentVersion: clientVersion,
      updateUrl: updateUrl,
      releaseNotes: releaseNotes,
      platform: platform.toLowerCase(),
    };

    console.log("✅ Réponse vérification version:", response);
    return response;

  } catch (error: any) {
    console.error("❌ Erreur lors de la vérification de version:", error);
    
    // Si c'est déjà une erreur H3, la relancer
    if (error.statusCode) {
      throw error;
    }
    
    // Sinon, créer une nouvelle erreur
    throw createError({
      statusCode: 500,
      message: "Erreur lors de la récupération des données des infos mobiles pour le versionning.",
      data: { error: error.message },
    });
  } finally {
    // La connexion est gérée par le pool, pas besoin de fermer manuellement
  }
});

/**
 * Fonction utilitaire pour comparer les versions (format: X.Y.Z)
 * Retourne:
 * - -1 si version1 < version2
 * - 0 si version1 === version2
 * - 1 si version1 > version2
 * 
 * Exemples:
 * - compareVersions("1.0.0", "1.0.1") => -1
 * - compareVersions("1.0.1", "1.0.0") => 1
 * - compareVersions("1.0.0", "1.0.0") => 0
 * - compareVersions("1.2.3", "1.2.4") => -1
 * - compareVersions("2.0.0", "1.9.9") => 1
 */
function compareVersions(version1: string, version2: string): number {
  // Nettoyer les versions (enlever les espaces, caractères spéciaux)
  const v1 = version1.trim().split("+")[0]; // Enlever le build number si présent (ex: "1.0.0+1" => "1.0.0")
  const v2 = version2.trim().split("+")[0];

  // Séparer en parties numériques
  const v1Parts = v1.split(".").map((part) => {
    const num = Number(part);
    return isNaN(num) ? 0 : num;
  });
  
  const v2Parts = v2.split(".").map((part) => {
    const num = Number(part);
    return isNaN(num) ? 0 : num;
  });

  // Trouver la longueur maximale
  const maxLength = Math.max(v1Parts.length, v2Parts.length);

  // Comparer partie par partie
  for (let i = 0; i < maxLength; i++) {
    const v1Part = v1Parts[i] || 0;
    const v2Part = v2Parts[i] || 0;

    if (v1Part < v2Part) return -1;
    if (v1Part > v2Part) return 1;
  }

  // Les versions sont identiques
  return 0;
}
```

---

### Étape 2 : Créer la table AppVersions (si nécessaire)

Si vous n'avez pas encore de table pour stocker les versions, créez-la avec ce script SQL :

**Fichier : `SNAL-Project/database/migrations/create_app_versions_table.sql`**

```sql
-- Table pour stocker les informations de version par plateforme
CREATE TABLE [dbo].[AppVersions] (
    [iAppVersion] INT IDENTITY(1,1) PRIMARY KEY,
    [sPlatform] NVARCHAR(10) NOT NULL, -- 'android', 'ios', 'web'
    [sLatestVersion] NVARCHAR(20) NOT NULL, -- Version la plus récente (ex: '1.1.0')
    [sMinimumVersion] NVARCHAR(20) NOT NULL, -- Version minimum requise (ex: '1.0.0')
    [bForceUpdate] BIT NOT NULL DEFAULT 0, -- Si true, la mise à jour est obligatoire
    [sUpdateUrl] NVARCHAR(500) NULL, -- URL du store (Play Store, App Store, etc.)
    [sReleaseNotes] NVARCHAR(MAX) NULL, -- Notes de version
    [dCreatedAt] DATETIME NOT NULL DEFAULT GETDATE(),
    [dUpdatedAt] DATETIME NOT NULL DEFAULT GETDATE(),
    
    -- Contrainte d'unicité par plateforme
    CONSTRAINT [UQ_AppVersions_Platform] UNIQUE ([sPlatform])
);

-- Index pour améliorer les performances
CREATE INDEX [IX_AppVersions_Platform] ON [dbo].[AppVersions] ([sPlatform]);

-- Données initiales
INSERT INTO [dbo].[AppVersions] ([sPlatform], [sLatestVersion], [sMinimumVersion], [bForceUpdate], [sUpdateUrl], [sReleaseNotes])
VALUES
    ('android', '1.0.0', '1.0.0', 0, 'https://play.google.com/store/apps/details?id=com.jirig.podium', 'Version initiale'),
    ('ios', '1.0.0', '1.0.0', 0, 'https://apps.apple.com/app/podium/id123456789', 'Version initiale'),
    ('web', '1.0.0', '1.0.0', 0, NULL, 'Version initiale');

-- Procédure pour mettre à jour la date de modification
CREATE TRIGGER [dbo].[TR_AppVersions_UpdateDate]
ON [dbo].[AppVersions]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE [dbo].[AppVersions]
    SET [dUpdatedAt] = GETDATE()
    WHERE [iAppVersion] IN (SELECT [iAppVersion] FROM inserted);
END;
```

**Exécution :**
```sql
-- Exécutez ce script dans SQL Server Management Studio ou via votre outil de migration
```

---

### Étape 3 : Créer la stored procedure

**Fichier : `SNAL-Project/database/stored_procedures/proc_App_Version_GetInfos.sql`**

Créez la stored procedure qui retourne les informations de version au format JSON :

```sql
-- Stored Procedure pour récupérer les informations de version
-- Retourne un JSON avec les informations de version pour toutes les plateformes
CREATE PROCEDURE [dbo].[proc_App_Version_GetInfos]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Récupérer toutes les versions et les formater en JSON
    SELECT (
        SELECT 
            [sPlatform] AS sPlatform,
            [sLatestVersion] AS sLatestVersion,
            [sMinimumVersion] AS sMinimumVersion,
            [bForceUpdate] AS bForceUpdate,
            [sUpdateUrl] AS sUpdateUrl,
            [sReleaseNotes] AS sReleaseNotes,
            [dUpdatedAt] AS dUpdatedAt
        FROM [dbo].[AppVersions]
        FOR JSON PATH
    ) AS VersionData;
END;
```

**Alternative : Si vous voulez filtrer par plateforme**

Si vous préférez que la stored procedure accepte un paramètre `sPlatform`, utilisez cette version :

```sql
-- Stored Procedure pour récupérer les informations de version pour une plateforme spécifique
CREATE PROCEDURE [dbo].[proc_App_Version_GetInfos]
    @sPlatform NVARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Si une plateforme est spécifiée, retourner uniquement cette plateforme
    IF @sPlatform IS NOT NULL
    BEGIN
        SELECT (
            SELECT 
                [sPlatform] AS sPlatform,
                [sLatestVersion] AS sLatestVersion,
                [sMinimumVersion] AS sMinimumVersion,
                [bForceUpdate] AS bForceUpdate,
                [sUpdateUrl] AS sUpdateUrl,
                [sReleaseNotes] AS sReleaseNotes,
                [dUpdatedAt] AS dUpdatedAt
            FROM [dbo].[AppVersions]
            WHERE [sPlatform] = @sPlatform
            FOR JSON PATH
        ) AS VersionData;
    END
    ELSE
    BEGIN
        -- Sinon, retourner toutes les plateformes
        SELECT (
            SELECT 
                [sPlatform] AS sPlatform,
                [sLatestVersion] AS sLatestVersion,
                [sMinimumVersion] AS sMinimumVersion,
                [bForceUpdate] AS bForceUpdate,
                [sUpdateUrl] AS sUpdateUrl,
                [sReleaseNotes] AS sReleaseNotes,
                [dUpdatedAt] AS dUpdatedAt
            FROM [dbo].[AppVersions]
            FOR JSON PATH
        ) AS VersionData;
    END
END;
```

**Si vous utilisez cette version avec paramètre**, décommentez dans l'endpoint TypeScript :
```typescript
const result = await pool
  .request()
  .input("sPlatform", sql.VarChar(10), platform.toLowerCase())
  .execute("proc_App_Version_GetInfos");
```

---

### Étape 4 : Structure de données attendue

La stored procedure doit retourner un JSON dans l'un de ces formats :

#### Format 1 - Tableau d'objets (recommandé)

```json
[
  {
    "sPlatform": "android",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs et améliorations",
    "dUpdatedAt": "2024-01-15T10:30:00"
  },
  {
    "sPlatform": "ios",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://apps.apple.com/app/podium/id123456789",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs et améliorations",
    "dUpdatedAt": "2024-01-15T10:30:00"
  },
  {
    "sPlatform": "web",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": null,
    "sReleaseNotes": "Nouvelle version disponible. Rechargez la page pour mettre à jour.",
    "dUpdatedAt": "2024-01-15T10:30:00"
  }
]
```

#### Format 2 - Objet avec clés par plateforme

```json
{
  "android": {
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs"
  },
  "ios": {
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://apps.apple.com/app/podium/id123456789",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs"
  }
}
```

#### Format 3 - Objet unique (une seule version pour toutes les plateformes)

```json
{
  "sLatestVersion": "1.1.0",
  "sMinimumVersion": "1.0.0",
  "bForceUpdate": false,
  "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
  "sReleaseNotes": "Nouvelle version avec corrections de bugs"
}
```

---

### Étape 5 : Gérer les versions dans la base de données

#### Mettre à jour une version

```sql
-- Mettre à jour la version Android
UPDATE [dbo].[AppVersions]
SET 
    [sLatestVersion] = '1.1.0',
    [sMinimumVersion] = '1.0.0',
    [bForceUpdate] = 0,
    [sUpdateUrl] = 'https://play.google.com/store/apps/details?id=com.jirig.podium',
    [sReleaseNotes] = 'Nouvelle version avec corrections de bugs et améliorations'
WHERE [sPlatform] = 'android';
```

#### Forcer une mise à jour obligatoire

```sql
-- Rendre la mise à jour obligatoire pour Android
UPDATE [dbo].[AppVersions]
SET 
    [sLatestVersion] = '1.2.0',
    [sMinimumVersion] = '1.1.0',
    [bForceUpdate] = 1,
    [sReleaseNotes] = 'Mise à jour de sécurité obligatoire'
WHERE [sPlatform] = 'android';
```

#### Ajouter une nouvelle plateforme

```sql
-- Ajouter une nouvelle plateforme (ex: windows)
INSERT INTO [dbo].[AppVersions] ([sPlatform], [sLatestVersion], [sMinimumVersion], [bForceUpdate], [sUpdateUrl], [sReleaseNotes])
VALUES ('windows', '1.0.0', '1.0.0', 0, 'https://example.com/download', 'Version initiale Windows');
```

---

## 🧪 Tests et vérifications

### 1. Tester l'endpoint avec curl

```bash
# Test avec version Android
curl "http://localhost:3000/api/get-app-mobile-infos-versions?version=1.0.0&platform=android"

# Test avec version iOS
curl "http://localhost:3000/api/get-app-mobile-infos-versions?version=1.0.0&platform=ios"

# Test avec version Web
curl "http://localhost:3000/api/get-app-mobile-infos-versions?version=1.0.0&platform=web"
```

### 2. Tester avec Postman

**Requête GET :**
```
GET /api/get-app-mobile-infos-versions?version=1.0.0&platform=android
```

**Réponse attendue :**
```json
{
  "success": true,
  "updateAvailable": true,
  "updateRequired": false,
  "forceUpdate": false,
  "latestVersion": "1.1.0",
  "minimumVersion": "1.0.0",
  "currentVersion": "1.0.0",
  "updateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
  "releaseNotes": "Nouvelle version avec corrections de bugs et améliorations",
  "platform": "android"
}
```

### 3. Tester la stored procedure directement

```sql
-- Exécuter la stored procedure
EXEC [dbo].[proc_App_Version_GetInfos];

-- Vérifier les données dans la table
SELECT * FROM [dbo].[AppVersions];
```

### 4. Scénarios de test

#### Test 1 : Version à jour
- **Requête :** `version=1.1.0&platform=android`
- **Attendu :** `updateAvailable: false`

#### Test 2 : Mise à jour disponible
- **Requête :** `version=1.0.0&platform=android`
- **Attendu :** `updateAvailable: true`, `updateRequired: false`

#### Test 3 : Mise à jour obligatoire
- **Configuration DB :** `sMinimumVersion = "1.1.0"`, `bForceUpdate = 1`
- **Requête :** `version=1.0.0&platform=android`
- **Attendu :** `updateRequired: true`, `forceUpdate: true`

#### Test 4 : Plateforme invalide
- **Requête :** `version=1.0.0&platform=invalid`
- **Attendu :** Erreur 400 avec message

#### Test 5 : Version manquante
- **Requête :** `platform=android`
- **Attendu :** Utilise la version par défaut "1.0.0"

---

## 📝 Notes importantes

### 1. Format de version

Les versions doivent être au format **semantic versioning** : `X.Y.Z`
- `X` = Major (changements incompatibles)
- `Y` = Minor (nouvelles fonctionnalités compatibles)
- `Z` = Patch (corrections de bugs)

Exemples : `1.0.0`, `1.1.0`, `2.0.0`

### 2. Comparaison de versions

La fonction `compareVersions` compare les versions partie par partie :
- `1.0.0` < `1.0.1`
- `1.0.9` < `1.1.0`
- `1.9.9` < `2.0.0`

### 3. Mise à jour obligatoire vs recommandée

- **Mise à jour recommandée** : `updateAvailable: true`, `updateRequired: false`
  - L'utilisateur peut choisir de mettre à jour plus tard
  
- **Mise à jour obligatoire** : `updateRequired: true`, `forceUpdate: true`
  - L'utilisateur ne peut pas fermer le dialogue
  - L'application peut bloquer certaines fonctionnalités

### 4. URLs de mise à jour

- **Android :** URL du Play Store
  - Format : `https://play.google.com/store/apps/details?id=com.jirig.podium`
  
- **iOS :** URL de l'App Store
  - Format : `https://apps.apple.com/app/podium/id123456789`
  
- **Web :** `null` (la page se recharge automatiquement)

### 5. Gestion des erreurs

L'endpoint gère plusieurs cas d'erreur :
- Connexion à la base de données échouée → 500
- Plateforme invalide → 400
- Aucune donnée retournée → 404
- JSON invalide → 500
- Structure de données inattendue → Valeurs par défaut avec warning

---

## 🔧 Dépannage

### Problème : L'endpoint retourne une erreur 500

**Solutions :**
1. Vérifiez la connexion à la base de données
2. Vérifiez que la stored procedure existe : `EXEC proc_App_Version_GetInfos`
3. Vérifiez les logs du serveur pour voir l'erreur exacte
4. Vérifiez que la table `AppVersions` existe et contient des données

### Problème : Le JSON retourné est invalide

**Solutions :**
1. Vérifiez que la stored procedure retourne bien du JSON valide
2. Testez la stored procedure directement dans SQL Server Management Studio
3. Vérifiez que le format JSON correspond à l'un des formats attendus

### Problème : La comparaison de versions ne fonctionne pas

**Solutions :**
1. Vérifiez que les versions sont au format `X.Y.Z`
2. Vérifiez que les versions ne contiennent pas de caractères spéciaux
3. Testez la fonction `compareVersions` avec des valeurs de test

### Problème : La plateforme n'est pas trouvée

**Solutions :**
1. Vérifiez que la plateforme existe dans la table `AppVersions`
2. Vérifiez que le nom de la plateforme correspond exactement (case-sensitive)
3. Vérifiez que la stored procedure retourne bien les données pour cette plateforme

---

## 📚 Ressources

- [Nuxt 3 Server API](https://nuxt.com/docs/guide/directory-structure/server)
- [H3 Documentation](https://www.jsdocs.io/package/h3)
- [mssql Node.js Driver](https://github.com/tediousjs/node-mssql)
- [SQL Server FOR JSON](https://docs.microsoft.com/en-us/sql/relational-databases/json/format-query-results-as-json-with-for-json-sql-server)

---

## ✅ Checklist d'implémentation

- [ ] Créer/modifier l'endpoint `get-app-mobile-infos-versions.get.ts`
- [ ] Créer la table `AppVersions` (si nécessaire)
- [ ] Créer la stored procedure `proc_App_Version_GetInfos`
- [ ] Insérer les données initiales dans `AppVersions`
- [ ] Tester l'endpoint avec différentes versions
- [ ] Tester avec différentes plateformes
- [ ] Tester les cas d'erreur (plateforme invalide, version manquante)
- [ ] Vérifier les logs du serveur
- [ ] Documenter les URLs de mise à jour pour chaque plateforme
- [ ] Configurer les mises à jour obligatoires si nécessaire

---

## 🔄 Workflow de mise à jour

### Quand publier une nouvelle version

1. **Mettre à jour la version dans la base de données :**
   ```sql
   UPDATE [dbo].[AppVersions]
   SET [sLatestVersion] = '1.1.0',
       [sReleaseNotes] = 'Nouvelle version avec...'
   WHERE [sPlatform] = 'android';
   ```

2. **Publier l'application sur le store** (Play Store, App Store, etc.)

3. **Vérifier que l'endpoint retourne la bonne version :**
   ```bash
   curl "https://votre-domaine.com/api/get-app-mobile-infos-versions?version=1.0.0&platform=android"
   ```

4. **Tester depuis l'application mobile** pour vérifier que le dialogue s'affiche

### Rendre une mise à jour obligatoire

Si vous devez forcer tous les utilisateurs à mettre à jour (par exemple pour une correction de sécurité) :

```sql
UPDATE [dbo].[AppVersions]
SET 
    [sMinimumVersion] = '1.1.0',  -- Version minimum requise
    [bForceUpdate] = 1,            -- Forcer la mise à jour
    [sReleaseNotes] = 'Mise à jour de sécurité obligatoire. Veuillez mettre à jour immédiatement.'
WHERE [sPlatform] = 'android';
```

---

**Félicitations !** 🎉 Vous avez maintenant un système complet de gestion de versions côté backend pour votre application Podium.
