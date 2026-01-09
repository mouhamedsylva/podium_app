# Code complet pour `get-app-mobile-infos-versions.get.ts`

## Fichier : `SNAL-Project/server/api/get-app-mobile-infos-versions.get.ts`

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
    // Note: Si la stored procedure accepte un paramètre platform, décommenter la ligne suivante
    // const result = await pool
    //   .request()
    //   .input("sPlatform", sql.VarChar(10), platform.toLowerCase())
    //   .execute("proc_App_Version_GetInfos");
    
    // Sinon, utiliser la version sans paramètre
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

    // Vérifier que parsedData contient les informations nécessaires
    // La structure attendue depuis la base de données peut varier
    // Ici, on suppose que parsedData contient soit:
    // - Un objet avec les infos directement
    // - Un tableau d'objets avec les infos par plateforme
    // - Un objet avec des clés par plateforme

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

## Notes importantes

### 1. Structure de données attendue depuis la stored procedure

La stored procedure `proc_App_Version_GetInfos` doit retourner un JSON avec une structure similaire à l'un de ces formats :

**Format 1 - Tableau d'objets par plateforme :**
```json
[
  {
    "sPlatform": "android",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs"
  },
  {
    "sPlatform": "ios",
    "sLatestVersion": "1.1.0",
    "sMinimumVersion": "1.0.0",
    "bForceUpdate": false,
    "sUpdateUrl": "https://apps.apple.com/app/podium/id123456789",
    "sReleaseNotes": "Nouvelle version avec corrections de bugs"
  }
]
```

**Format 2 - Objet avec clés par plateforme :**
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

**Format 3 - Objet unique (une seule version pour toutes les plateformes) :**
```json
{
  "sLatestVersion": "1.1.0",
  "sMinimumVersion": "1.0.0",
  "bForceUpdate": false,
  "sUpdateUrl": "https://play.google.com/store/apps/details?id=com.jirig.podium",
  "sReleaseNotes": "Nouvelle version avec corrections de bugs"
}
```

### 2. Paramètres de la stored procedure

Si votre stored procedure `proc_App_Version_GetInfos` accepte un paramètre `sPlatform`, décommentez et utilisez cette version :

```typescript
const result = await pool
  .request()
  .input("sPlatform", sql.VarChar(10), platform.toLowerCase())
  .execute("proc_App_Version_GetInfos");
```

Sinon, utilisez la version sans paramètre (comme dans le code fourni).

### 3. Noms de colonnes flexibles

Le code gère plusieurs variantes de noms de colonnes :
- `sLatestVersion` ou `latestVersion` ou `version`
- `sMinimumVersion` ou `minimumVersion` ou `minVersion`
- `bForceUpdate` ou `forceUpdate`
- `sUpdateUrl` ou `updateUrl` ou `url`
- `sReleaseNotes` ou `releaseNotes` ou `notes`

### 4. Gestion des erreurs

Le code gère plusieurs cas d'erreur :
- Plateforme invalide
- Connexion à la base de données échouée
- Recordset vide
- JSON invalide
- Structure de données inattendue

### 5. Format de version

Les versions doivent être au format `X.Y.Z` (ex: `1.0.0`, `1.2.3`). Le code ignore automatiquement le build number si présent (ex: `1.0.0+1` => `1.0.0`).

### 6. Exemple d'utilisation

**Requête :**
```
GET /api/get-app-mobile-infos-versions?version=1.0.0&platform=android
```

**Réponse :**
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
  "releaseNotes": "Nouvelle version avec corrections de bugs",
  "platform": "android"
}
```
