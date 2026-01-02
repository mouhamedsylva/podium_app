# Implémentation Backend - Support Screen (podium_app)

## 📋 Analyse de `support_screen.dart`

### Données collectées par le formulaire

Le formulaire de support dans `support_screen.dart` collecte les informations suivantes :

- **sName** : Nom de l'utilisateur (requis)
- **sEmail** : Email de l'utilisateur (requis, validé)
- **sSubject** : Sujet du message (requis)
- **sMessage** : Message de l'utilisateur (requis, minimum 10 caractères)

### État actuel

Actuellement, le formulaire utilise un **fallback mailto** (ligne 202-213) :
```dart
// TODO: Implémenter l'appel API pour envoyer le message de support
await Future.delayed(const Duration(seconds: 1));

// Pour l'instant, on utilise mailto comme fallback
final mailtoUri = Uri.parse('mailto:$_supportEmail?subject=$emailSubject&body=$emailBody');
```

### Endpoint API à appeler

L'application Flutter doit appeler :
- **URL** : `POST /api/contact`
- **Body** : 
  ```json
  {
    "sName": "Nom de l'utilisateur",
    "sEmail": "email@example.com",
    "sSubject": "Sujet du message",
    "sMessage": "Contenu du message"
  }
  ```

---

## 🔧 Implémentation Backend (SNAL-Project)

### 1. Endpoint API existant

L'endpoint `/api/contact` existe déjà dans `SNAL-Project/server/api/contact.post.ts` mais nécessite quelques améliorations.

#### État actuel de l'endpoint

```typescript
// SNAL-Project/server/api/contact.post.ts
export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { sName, sEmail, sMessage, sSubject } = body;
  
  // Validation basique
  if (!sName || !sEmail || !sMessage || !sSubject) {
    throw createError({
      statusCode: 400,
      message: "Name, email, and message are required",
    });
  }
  
  // Appel à la stored procedure
  const xXml = `<root>...</root>`;
  const result = await pool.request()
    .input("xXml", sql.Xml, xXml)
    .execute("dbo.proc_send_contact_message");
  
  return { success: true, message: "Contact message saved successfully" };
});
```

#### Améliorations recommandées

1. **Récupérer le profil utilisateur** (iProfile) depuis les cookies
2. **Validation email** plus robuste
3. **Intégration Mailjet** pour envoyer un email de notification
4. **Gestion d'erreurs** améliorée
5. **Logs** plus détaillés

---

### 2. Stored Procedure : `proc_send_contact_message`

#### Structure de la table recommandée

```sql
-- Table pour stocker les messages de support
CREATE TABLE [dbo].[sh_contact_messages] (
    [iContactMessage] NUMERIC(18, 0) IDENTITY(1,1) PRIMARY KEY,
    [iProfile] NUMERIC(18, 0) NULL, -- NULL si utilisateur non connecté
    [sName] NVARCHAR(255) NOT NULL,
    [sEmail] NVARCHAR(255) NOT NULL,
    [sSubject] NVARCHAR(500) NOT NULL,
    [sMessage] NVARCHAR(MAX) NOT NULL,
    [dDateCreated] DATETIME NOT NULL DEFAULT GETDATE(),
    [sStatus] NVARCHAR(50) DEFAULT 'PENDING', -- PENDING, READ, REPLIED, CLOSED
    [sResponse] NVARCHAR(MAX) NULL, -- Réponse du support
    [dDateReplied] DATETIME NULL
);

-- Index pour améliorer les performances
CREATE INDEX IX_sh_contact_messages_iProfile ON [dbo].[sh_contact_messages]([iProfile]);
CREATE INDEX IX_sh_contact_messages_sStatus ON [dbo].[sh_contact_messages]([sStatus]);
CREATE INDEX IX_sh_contact_messages_dDateCreated ON [dbo].[sh_contact_messages]([dDateCreated]);
```

#### Stored Procedure complète

```sql
CREATE PROCEDURE [dbo].[proc_send_contact_message]
    @xXml XML
AS
BEGIN
    -- Created by [Votre nom]
    -- Date : 2025-01-XX
    -- But : Enregistrer un message de support depuis l'application mobile/web
    -- Historique : 
    --   - 2025-01-XX : Création initiale

    SET NOCOUNT ON;
    
    DECLARE @sCurrProcName VARCHAR(MAX) = ISNULL(OBJECT_NAME(@@PROCID), 'proc_send_contact_message');
    DECLARE @sResult VARCHAR(MAX) = '';
    
    -- Variables pour extraire les données du XML
    DECLARE @iProfile NUMERIC(18, 0) = NULL;
    DECLARE @sName NVARCHAR(255) = '';
    DECLARE @sEmail NVARCHAR(255) = '';
    DECLARE @sSubject NVARCHAR(500) = '';
    DECLARE @sMessage NVARCHAR(MAX) = '';
    DECLARE @iContactMessage NUMERIC(18, 0) = NULL;

    BEGIN TRY
        -- ✅ Logs et traces (selon le template SNAL)
        INSERT INTO [dbo].[sh_debug_xml] (xXml) VALUES (@xXml);
        
        INSERT INTO [dbo].[SH_LOG] ([sLogName], [sDescr], [dDateLog], [sComment], [sUser])
        VALUES (@sCurrProcName, 'Start procedure', GETDATE(), '', '');

        -- ✅ Extraire les données du XML
        SET @iProfile = @xXml.value('(/root/iProfile)[1]', 'NUMERIC(18, 0)');
        SET @sName = LTRIM(RTRIM(@xXml.value('(/root/sName)[1]', 'NVARCHAR(255)')));
        SET @sEmail = LTRIM(RTRIM(@xXml.value('(/root/sEmail)[1]', 'NVARCHAR(255)')));
        SET @sSubject = LTRIM(RTRIM(@xXml.value('(/root/sSubject)[1]', 'NVARCHAR(500)')));
        SET @sMessage = LTRIM(RTRIM(@xXml.value('(/root/sMessage)[1]', 'NVARCHAR(MAX)')));

        -- ✅ Validation des données
        IF @sName IS NULL OR @sName = ''
        BEGIN
            SET @sResult = 'ERROR: sName is required';
            THROW 50000, @sResult, 1;
        END

        IF @sEmail IS NULL OR @sEmail = '' OR @sEmail NOT LIKE '%@%.%'
        BEGIN
            SET @sResult = 'ERROR: sEmail is required and must be valid';
            THROW 50000, @sResult, 1;
        END

        IF @sSubject IS NULL OR @sSubject = ''
        BEGIN
            SET @sResult = 'ERROR: sSubject is required';
            THROW 50000, @sResult, 1;
        END

        IF @sMessage IS NULL OR @sMessage = '' OR LEN(@sMessage) < 10
        BEGIN
            SET @sResult = 'ERROR: sMessage is required and must be at least 10 characters';
            THROW 50000, @sResult, 1;
        END

        -- ✅ Insérer le message dans la table
        INSERT INTO [dbo].[sh_contact_messages] (
            [iProfile],
            [sName],
            [sEmail],
            [sSubject],
            [sMessage],
            [dDateCreated],
            [sStatus]
        )
        VALUES (
            @iProfile,
            @sName,
            @sEmail,
            @sSubject,
            @sMessage,
            GETDATE(),
            'PENDING'
        );

        -- ✅ Récupérer l'ID généré
        SET @iContactMessage = SCOPE_IDENTITY();

        -- ✅ Log de succès
        INSERT INTO [dbo].[SH_LOG] ([sLogName], [sDescr], [dDateLog], [sComment], [sUser])
        VALUES (@sCurrProcName, 'Contact message saved successfully', GETDATE(), 
                'iContactMessage: ' + CAST(@iContactMessage AS VARCHAR(MAX)), '');

        SET @sResult = 'SUCCESS: Contact message saved with ID ' + CAST(@iContactMessage AS VARCHAR(MAX));

        -- ✅ Retourner le résultat (optionnel, pour debug)
        SELECT 
            @iContactMessage AS iContactMessage,
            @sResult AS sResult,
            'SUCCESS' AS sStatus;

    END TRY
    BEGIN CATCH
        -- ✅ Gestion des erreurs
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        SET @sResult = 'ERROR: ' + @ErrorMessage;

        -- ✅ Log de l'erreur
        INSERT INTO [dbo].[SH_LOG] ([sLogName], [sDescr], [dDateLog], [sComment], [sUser])
        VALUES (@sCurrProcName, 'Error in procedure', GETDATE(), @ErrorMessage, '');

        -- ✅ Relancer l'erreur
        THROW;
    END CATCH
END;
GO
```

---

### 3. Amélioration de l'endpoint API

#### Version améliorée de `contact.post.ts`

```typescript
import {
  defineEventHandler,
  readBody,
  createError,
  getRequestIP,
} from "h3";
import { connectToDatabase } from "../db/index";
import sql from "mssql";
import { useAppCookies } from "~/composables/useAppCookies";
import Mailjet from "node-mailjet";

export default defineEventHandler(async (event) => {
  const body = await readBody(event);
  const { sName, sEmail, sMessage, sSubject } = body;

  // ✅ Validation des champs requis
  if (!sName || !sEmail || !sMessage || !sSubject) {
    throw createError({
      statusCode: 400,
      message: "Name, email, subject, and message are required",
    });
  }

  // ✅ Validation email basique
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(sEmail)) {
    throw createError({
      statusCode: 400,
      message: "Invalid email format",
    });
  }

  // ✅ Validation longueur du message
  if (sMessage.trim().length < 10) {
    throw createError({
      statusCode: 400,
      message: "Message must be at least 10 characters",
    });
  }

  // ✅ Récupérer le profil utilisateur (depuis cookies ou session)
  const { getGuestProfile } = useAppCookies(event);
  const guestProfile = getGuestProfile();
  
  let user: any = undefined;
  if (typeof getUserSession === "function") {
    const session = await getUserSession(event);
    user = session && typeof session === "object" 
      ? session.user || session 
      : undefined;
  }

  // Utiliser le profil invité si pas d'utilisateur connecté
  if (!user || typeof user !== "object" || user.iProfile === undefined) {
    if (guestProfile && typeof guestProfile === "object" && guestProfile.iProfile !== undefined) {
      user = {
        iProfile: guestProfile.iProfile,
        iBasket: guestProfile.iBasket,
      };
    }
  }

  const iProfile = user && typeof user === "object" ? user.iProfile : null;
  const requestIP = getRequestIP(event);

  // ✅ Connecter à la base de données
  const pool = await connectToDatabase();
  if (!pool) {
    throw createError({
      statusCode: 500,
      message: "Database connection not available",
    });
  }

  try {
    // ✅ Construire le XML selon le format SNAL
    const xXml = `
      <root>
        <iProfile>${iProfile || "-99"}</iProfile>
        <sName>${sName.replace(/[<>]/g, "")}</sName>
        <sEmail>${sEmail.replace(/[<>]/g, "")}</sEmail>
        <sSubject>${sSubject.replace(/[<>]/g, "")}</sSubject>
        <sMessage>${sMessage.replace(/[<>]/g, "")}</sMessage>
      </root>
    `.trim();

    console.log("📧 Contact XML payload:", xXml);

    // ✅ Appeler la stored procedure
    const result = await pool
      .request()
      .input("xXml", sql.Xml, xXml)
      .execute("dbo.proc_send_contact_message");

    console.log("📧 Database response:", result);

    // ✅ Vérifier le résultat
    const recordset = result.recordset?.[0];
    if (!recordset || recordset.sStatus !== "SUCCESS") {
      throw createError({
        statusCode: 500,
        message: "Failed to save contact message",
      });
    }

    const iContactMessage = recordset.iContactMessage;

    // ✅ Envoyer un email de notification via Mailjet (optionnel mais recommandé)
    const config = useRuntimeConfig();
    if (config.mjApiKeyPublic && config.mjApiKeyPrivate) {
      try {
        const mailjet = new Mailjet({
          apiKey: config.mjApiKeyPublic,
          apiSecret: config.mjApiKeyPrivate,
        });

        const emailData = {
          Messages: [
            {
              From: {
                Email: config.public.mailjetSender || "support@jirig.be",
                Name: "Jirig Support",
              },
              To: [
                {
                  Email: config.public.mailjetSender || "support@jirig.be",
                  Name: "Support Team",
                },
              ],
              Subject: `[Support] ${sSubject} - ${sName}`,
              HTMLPart: `
                <h2>Nouveau message de support</h2>
                <p><strong>ID Message:</strong> ${iContactMessage}</p>
                <p><strong>Nom:</strong> ${sName}</p>
                <p><strong>Email:</strong> ${sEmail}</p>
                <p><strong>Profil:</strong> ${iProfile || "Non connecté"}</p>
                <p><strong>IP:</strong> ${requestIP || "N/A"}</p>
                <hr>
                <h3>Sujet:</h3>
                <p>${sSubject}</p>
                <h3>Message:</h3>
                <p>${sMessage.replace(/\n/g, "<br>")}</p>
              `,
              TextPart: `
                Nouveau message de support
                ID Message: ${iContactMessage}
                Nom: ${sName}
                Email: ${sEmail}
                Profil: ${iProfile || "Non connecté"}
                IP: ${requestIP || "N/A"}
                
                Sujet: ${sSubject}
                Message: ${sMessage}
              `,
            },
          ],
        };

        const emailResult = await mailjet.post("send", { version: "v3.1" }).request(emailData);
        console.log("📧 Email notification sent:", emailResult.body);
      } catch (emailError: any) {
        // Ne pas faire échouer la requête si l'email échoue
        console.error("⚠️ Failed to send email notification:", emailError);
      }
    }

    // ✅ Retourner le succès
    return {
      success: true,
      message: "Contact message saved successfully",
      iContactMessage: iContactMessage,
    };
  } catch (error: any) {
    console.error("❌ Error saving contact message:", error);
    
    // ✅ Gestion d'erreur améliorée
    if (error.statusCode) {
      throw error; // Re-throw les erreurs HTTP créées
    }
    
    throw createError({
      statusCode: 500,
      message: error.message || "Internal server error",
      stack: error.stack,
    });
  }
});
```

---

### 4. Modification du code Flutter

#### Mise à jour de `support_screen.dart`

Remplacer la fonction `_submitForm()` (lignes 191-263) par :

```dart
Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    // ✅ Appel API au lieu du fallback mailto
    final response = await apiService.dio.post(
      '/contact',
      data: {
        'sName': _nameController.text.trim(),
        'sEmail': _emailController.text.trim(),
        'sSubject': _subjectController.text.trim(),
        'sMessage': _messageController.text.trim(),
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      setState(() {
        _isSubmitted = true;
        _isLoading = false;
      });
      
      // Animer le message de succès
      if (_animationsInitialized) {
        _successController.forward();
      }
      
      // Réinitialiser le formulaire après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          if (_animationsInitialized) {
            _successController.reverse();
          }
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isSubmitted = false;
                _formKey.currentState!.reset();
                _nameController.clear();
                _emailController.clear();
                _subjectController.clear();
                _messageController.clear();
              });
            }
          });
        }
      });
    } else {
      throw Exception(response.data['message'] ?? 'Erreur lors de l\'envoi');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
}
```

---

### 5. Configuration Mailjet (optionnel)

Si vous souhaitez recevoir des emails de notification, ajoutez dans `.env` :

```env
NUXT_MJ_APIKEY_PUBLIC=your_public_key
NUXT_MJ_APIKEY_PRIVATE=your_private_key
NUXT_MJ_SENDER=support@jirig.be
```

---

### 6. Tests à effectuer

#### Tests unitaires de la stored procedure

```sql
-- Test 1: Message valide
DECLARE @xml1 XML = '
<root>
  <iProfile>123</iProfile>
  <sName>John Doe</sName>
  <sEmail>john@example.com</sEmail>
  <sSubject>Question sur les prix</sSubject>
  <sMessage>Bonjour, j''aimerais savoir comment fonctionne la comparaison de prix.</sMessage>
</root>';

EXEC proc_send_contact_message @xXml = @xml1;

-- Test 2: Utilisateur non connecté (iProfile = -99)
DECLARE @xml2 XML = '
<root>
  <iProfile>-99</iProfile>
  <sName>Jane Doe</sName>
  <sEmail>jane@example.com</sEmail>
  <sSubject>Problème technique</sSubject>
  <sMessage>Je rencontre un problème lors de la connexion à mon compte.</sMessage>
</root>';

EXEC proc_send_contact_message @xXml = @xml2;

-- Test 3: Vérifier les messages enregistrés
SELECT TOP 10 * FROM sh_contact_messages ORDER BY dDateCreated DESC;
```

#### Tests de l'endpoint API

```bash
# Test avec curl
curl -X POST http://localhost:3000/api/contact \
  -H "Content-Type: application/json" \
  -H "Cookie: GuestProfile=..." \
  -d '{
    "sName": "Test User",
    "sEmail": "test@example.com",
    "sSubject": "Test Subject",
    "sMessage": "This is a test message with more than 10 characters"
  }'
```

#### Tests depuis l'application Flutter

1. ✅ Remplir le formulaire avec des données valides
2. ✅ Vérifier que le message de succès s'affiche
3. ✅ Vérifier que le formulaire se réinitialise après 3 secondes
4. ✅ Tester avec un email invalide (doit afficher une erreur)
5. ✅ Tester avec un message trop court (doit afficher une erreur)
6. ✅ Vérifier dans la base de données que le message est bien enregistré

---

### 7. Améliorations futures possibles

1. **Système de tickets** : Ajouter un numéro de ticket unique
2. **Réponses** : Permettre au support de répondre directement depuis l'interface
3. **Catégories** : Ajouter des catégories de support (technique, facturation, etc.)
4. **Pièces jointes** : Permettre l'upload de fichiers/images
5. **Notifications push** : Notifier l'utilisateur quand le support répond
6. **Historique** : Afficher l'historique des messages dans le profil utilisateur
7. **FAQ automatique** : Suggérer des réponses de la FAQ selon le sujet

---

### 8. Checklist d'implémentation

- [ ] Créer la table `sh_contact_messages` dans MSSQL
- [ ] Créer la stored procedure `proc_send_contact_message`
- [ ] Tester la stored procedure avec différents cas
- [ ] Améliorer l'endpoint `/api/contact` avec les validations
- [ ] Ajouter l'intégration Mailjet (optionnel)
- [ ] Modifier `support_screen.dart` pour appeler l'API
- [ ] Tester depuis l'application Flutter
- [ ] Vérifier les logs dans `sh_debug_xml` et `SH_LOG`
- [ ] Documenter les erreurs possibles
- [ ] Ajouter les traductions pour les messages d'erreur

---

## 📝 Notes importantes

1. **Sécurité** : 
   - Échapper les caractères XML dangereux (`<`, `>`)
   - Valider l'email côté serveur
   - Limiter la longueur des champs
   - Protéger contre le spam (rate limiting)

2. **Performance** :
   - Les index sur `iProfile`, `sStatus`, et `dDateCreated` sont importants
   - Considérer l'archivage des anciens messages

3. **Conformité** :
   - Respecter le RGPD pour les données personnelles
   - Informer l'utilisateur de l'utilisation de ses données

---

## 🔗 Références

- Template stored procedure : `.github/instructions/snal.instructions.md`
- Endpoint contact existant : `SNAL-Project/server/api/contact.post.ts`
- Exemple Mailjet : `SNAL-Project/server/api/subscribe-newsletter.post.ts`
- Support screen Flutter : `podium_app/lib/screens/support_screen.dart`

