# Workflow de mise à jour de l'application Podium - Version textuelle

## Vue d'ensemble

Le système de mise à jour de l'application Podium permet de notifier automatiquement les utilisateurs lorsqu'une nouvelle version est disponible et de les guider pour l'installer. Le processus se déroule en plusieurs étapes, depuis le développement jusqu'à l'installation par l'utilisateur final.

---

## Phase 1 : Préparation de la nouvelle version

Tout commence par le développement d'une nouvelle version de l'application. Le développeur travaille sur les corrections de bugs, les nouvelles fonctionnalités ou les améliorations de sécurité. Une fois le développement terminé, la version est mise à jour dans le fichier de configuration de l'application, généralement dans un fichier comme pubspec.yaml pour Flutter, où la version est définie au format numéro de version suivi d'un numéro de build.

Ensuite, l'application est compilée et testée pour s'assurer qu'elle fonctionne correctement sur toutes les plateformes cibles : Android, iOS et Web. Les fichiers de build sont générés : fichiers APK ou AAB pour Android, fichiers IPA pour iOS, et les fichiers web sont préparés pour le déploiement.

Une fois les tests réussis, l'application est publiée sur les stores respectifs. Pour Android, cela signifie l'upload sur Google Play Store. Pour iOS, c'est l'upload sur l'Apple App Store. Pour le web, les fichiers sont déployés sur le serveur de production.

---

## Phase 2 : Configuration du backend

Après la publication sur les stores, le développeur ou l'administrateur doit mettre à jour la base de données pour informer le système qu'une nouvelle version est disponible. Cette mise à jour se fait dans une table dédiée qui stocke les informations de version pour chaque plateforme.

Les informations mises à jour incluent le numéro de la dernière version disponible, la version minimum requise pour continuer à utiliser l'application, un indicateur pour savoir si la mise à jour est obligatoire ou simplement recommandée, l'URL du store où l'utilisateur peut télécharger la mise à jour, et les notes de version qui expliquent ce qui a changé.

Une fois la base de données mise à jour, il est important de vérifier que l'endpoint API fonctionne correctement. Cet endpoint est appelé par l'application pour vérifier s'il existe une nouvelle version. Le développeur teste l'endpoint en lui envoyant la version actuelle de l'application et la plateforme, et vérifie que la réponse indique bien qu'une mise à jour est disponible.

---

## Phase 3 : Détection automatique par l'application

Lorsqu'un utilisateur démarre l'application, ou à intervalles réguliers, l'application vérifie automatiquement s'il existe une nouvelle version disponible. Ce processus commence par la récupération de la version actuelle de l'application installée sur l'appareil de l'utilisateur. Cette information est lue depuis les métadonnées de l'application.

Ensuite, l'application détermine sur quelle plateforme elle s'exécute : Android, iOS ou Web. Cette information est importante car les versions peuvent différer selon la plateforme, et les liens de téléchargement sont différents pour chaque store.

Une fois ces informations collectées, l'application fait une requête au serveur backend. Cette requête contient la version actuelle de l'application et la plateforme. Le serveur backend interroge alors la base de données pour récupérer les informations de version correspondant à cette plateforme.

Le serveur compare la version actuelle de l'application avec la dernière version disponible et la version minimum requise. Il détermine ainsi si une mise à jour est disponible, si elle est obligatoire, et si elle doit être forcée. Toutes ces informations sont renvoyées à l'application dans une réponse structurée.

---

## Phase 4 : Notification de l'utilisateur

Si une mise à jour est disponible, l'application affiche un dialogue à l'utilisateur. Ce dialogue présente différentes informations selon que la mise à jour est recommandée ou obligatoire.

Pour une mise à jour recommandée, le dialogue affiche un message indiquant qu'une nouvelle version est disponible. Il montre la version actuelle de l'application et la nouvelle version disponible. Les notes de version sont également affichées pour informer l'utilisateur des changements apportés. L'utilisateur a le choix entre deux options : mettre à jour maintenant ou reporter la mise à jour à plus tard. S'il choisit de reporter, le dialogue se ferme et l'application continue de fonctionner normalement. Le dialogue pourra réapparaître lors d'une prochaine vérification.

Pour une mise à jour obligatoire, le dialogue est similaire mais avec des différences importantes. Un message d'avertissement indique que la mise à jour est obligatoire pour continuer à utiliser l'application. Le bouton pour reporter la mise à jour n'existe pas, et l'utilisateur ne peut pas fermer le dialogue en cliquant en dehors. Il doit absolument cliquer sur le bouton de mise à jour pour continuer. Dans certains cas, l'application peut même bloquer certaines fonctionnalités tant que la mise à jour n'est pas installée.

---

## Phase 5 : Action de l'utilisateur

Lorsque l'utilisateur clique sur le bouton de mise à jour, l'application redirige l'utilisateur vers le store approprié. Pour Android, cela ouvre Google Play Store et affiche la page de l'application. Pour iOS, cela ouvre l'App Store et affiche la page de l'application. Pour le web, la page se recharge automatiquement pour charger la nouvelle version.

Une fois sur le store, l'utilisateur peut voir les détails de la nouvelle version, lire les notes de version complètes, et décider d'installer la mise à jour. Sur mobile, l'utilisateur clique sur le bouton d'installation dans le store, et le système d'exploitation gère le téléchargement et l'installation de la nouvelle version. Sur le web, le rechargement de la page charge automatiquement la nouvelle version depuis le serveur.

---

## Phase 6 : Vérification post-installation

Après l'installation de la mise à jour, lorsque l'utilisateur redémarre l'application, le système vérifie à nouveau la version. Cette fois, la version détectée est la nouvelle version qui vient d'être installée. L'application fait une nouvelle requête au serveur avec cette nouvelle version.

Le serveur compare cette nouvelle version avec les informations dans la base de données. Si la version installée correspond à la dernière version disponible, le serveur indique qu'aucune mise à jour n'est disponible. L'application ne montre alors aucun dialogue de mise à jour et fonctionne normalement.

---

## Fréquence des vérifications

Le système effectue des vérifications à différents moments. Au démarrage de l'application, une vérification est effectuée immédiatement après le chargement de l'écran principal. Cependant, à ce moment-là, seules les mises à jour obligatoires sont affichées. Cela évite de perturber l'utilisateur avec des notifications de mises à jour recommandées dès qu'il ouvre l'application.

En plus de la vérification au démarrage, le système effectue des vérifications périodiques. Par défaut, ces vérifications ont lieu toutes les vingt-quatre heures. Lors de ces vérifications périodiques, toutes les mises à jour sont prises en compte, qu'elles soient obligatoires ou simplement recommandées. Cela permet d'informer l'utilisateur des nouvelles versions disponibles même s'il n'a pas redémarré l'application récemment.

Enfin, l'utilisateur peut également déclencher une vérification manuelle depuis les paramètres de l'application. Un bouton permet de forcer une vérification immédiate, ce qui est utile si l'utilisateur souhaite vérifier s'il existe une nouvelle version sans attendre la vérification automatique.

---

## Scénarios différents

Le comportement du système varie selon différents scénarios. Dans le cas d'une mise à jour recommandée normale, l'utilisateur a la version 1.0.0 installée, et la version 1.1.0 est disponible. La version minimum requise reste 1.0.0, donc l'utilisateur n'est pas obligé de mettre à jour. Le système détecte qu'une mise à jour est disponible mais qu'elle n'est pas obligatoire. Un dialogue s'affiche avec un bouton pour reporter la mise à jour, et l'application continue de fonctionner normalement même si l'utilisateur choisit de ne pas mettre à jour immédiatement.

Dans le cas d'une mise à jour obligatoire, la situation est différente. L'utilisateur a toujours la version 1.0.0, mais maintenant la version minimum requise est passée à 1.1.0, et le système est configuré pour forcer la mise à jour. Le système détecte qu'une mise à jour est disponible, qu'elle est obligatoire, et qu'elle doit être forcée. Le dialogue affiché ne permet pas à l'utilisateur de reporter la mise à jour, et l'application peut bloquer certaines fonctionnalités tant que la mise à jour n'est pas installée.

Si l'utilisateur a déjà la dernière version installée, le système détecte qu'aucune mise à jour n'est disponible. Aucun dialogue n'est affiché, et l'application fonctionne normalement.

Il existe également le cas où un développeur teste une version de développement qui est plus récente que la version en production. Dans ce cas, le système détecte que la version installée est plus récente que la version disponible en production, et aucun dialogue de mise à jour n'est affiché.

---

## Gestion des erreurs

Le système est conçu pour gérer les erreurs de manière élégante sans perturber l'expérience utilisateur. Si le serveur backend n'est pas disponible ou ne répond pas, l'application continue de fonctionner normalement. L'erreur est enregistrée dans les logs pour le débogage, mais aucun message d'erreur n'est affiché à l'utilisateur. Une nouvelle tentative sera effectuée lors de la prochaine vérification.

Si la réponse du serveur contient des données invalides, par exemple une version dans un format incorrect, le système utilise des valeurs par défaut. L'application continue de fonctionner, et l'erreur est enregistrée dans les logs. Aucun dialogue de mise à jour n'est affiché dans ce cas.

Si le lien du store ne peut pas être ouvert, par exemple si l'application du store n'est pas installée ou si le lien est invalide, un message d'erreur est affiché à l'utilisateur. Ce message indique qu'il y a eu un problème pour ouvrir le store, et l'utilisateur peut réessayer plus tard. L'application continue de fonctionner normalement.

---

## Processus de publication d'une nouvelle version

Quand une nouvelle version est prête à être publiée, plusieurs étapes doivent être suivies. Avant la publication, il est important de tester la nouvelle version sur toutes les plateformes pour s'assurer qu'elle fonctionne correctement. Les fonctionnalités critiques doivent être vérifiées, et les notes de version doivent être préparées. Les URLs des stores doivent également être préparées et vérifiées.

Pendant la publication, l'application est uploadée sur les stores respectifs. La base de données est mise à jour avec les nouvelles informations de version. L'endpoint API est testé pour vérifier qu'il retourne les bonnes informations. Des tests sont effectués depuis l'application mobile pour vérifier que le dialogue de mise à jour s'affiche correctement.

Après la publication, il est important de surveiller les logs pour détecter d'éventuelles erreurs. Il faut vérifier que les utilisateurs reçoivent bien les notifications de mise à jour et que les liens vers les stores fonctionnent correctement.

En cas de problème, plusieurs vérifications peuvent être effectuées. Les logs du backend peuvent être consultés pour identifier les erreurs. La base de données peut être vérifiée pour s'assurer qu'elle contient les bonnes valeurs. L'endpoint API peut être testé directement avec des outils comme curl ou Postman. Il faut également vérifier que les stores ont bien publié la nouvelle version.

---

## Bonnes pratiques

Pour un système de mise à jour efficace, plusieurs bonnes pratiques doivent être suivies. Le versioning doit suivre le semantic versioning, avec des numéros de version au format majeur, mineur, patch. Les changements majeurs qui ne sont pas compatibles avec les versions précédentes incrémentent le numéro majeur. Les nouvelles fonctionnalités compatibles incrémentent le numéro mineur. Les corrections de bugs incrémentent le numéro de patch.

Les mises à jour obligatoires doivent être utilisées avec parcimonie. Elles ne devraient être utilisées que pour les corrections de sécurité critiques, les changements de compatibilité majeurs, ou les problèmes bloquants. Elles ne devraient pas être utilisées pour les nouvelles fonctionnalités, les améliorations mineures, ou les corrections de bugs non critiques.

Les notes de version doivent être claires et concises. Elles doivent lister les principales améliorations et mentionner les corrections de bugs importantes. Le langage utilisé doit être accessible aux utilisateurs, sans jargon technique excessif.

Le timing de publication est également important. Il est recommandé de publier les mises à jour progressivement, en commençant par un petit pourcentage d'utilisateurs, puis en augmentant progressivement. Cela permet de détecter les problèmes éventuels avant que tous les utilisateurs ne soient affectés. Il est également important de surveiller les erreurs après publication et de préparer un plan de rollback si nécessaire.

---

## Monitoring et suivi

Pour s'assurer que le système de mise à jour fonctionne correctement, plusieurs métriques peuvent être surveillées. Le taux d'adoption mesure le pourcentage d'utilisateurs qui ont installé la nouvelle version. Le temps moyen pour adopter une nouvelle version peut également être suivi pour comprendre le comportement des utilisateurs.

Les erreurs doivent être surveillées, notamment le nombre d'erreurs lors de la vérification de version et les erreurs d'ouverture du store. L'engagement des utilisateurs peut être mesuré en suivant le nombre d'utilisateurs qui cliquent sur le bouton de mise à jour par rapport à ceux qui choisissent de reporter la mise à jour.

Les logs doivent être surveillés régulièrement. Côté backend, il faut surveiller le nombre de requêtes de vérification de version, les erreurs de connexion à la base de données, et les erreurs de parsing des données JSON. Côté frontend, il faut surveiller les erreurs lors de l'appel API, les erreurs lors de l'ouverture du store, et les versions détectées par plateforme.

---

## Résumé

Le workflow de mise à jour de l'application suit un processus structuré qui commence par le développement et la publication d'une nouvelle version. Le backend est configuré pour indiquer qu'une nouvelle version est disponible. L'application détecte automatiquement cette nouvelle version lors de vérifications régulières. L'utilisateur est notifié via un dialogue qui s'affiche dans l'application. L'utilisateur peut alors choisir d'installer la mise à jour immédiatement ou de la reporter, sauf dans le cas d'une mise à jour obligatoire où l'installation est requise. Une fois la mise à jour installée, le système vérifie à nouveau et confirme que l'application est à jour.

Ce processus garantit que les utilisateurs sont toujours informés des nouvelles versions disponibles et peuvent les installer facilement, tout en permettant aux développeurs de contrôler quand une mise à jour doit être obligatoire pour des raisons de sécurité ou de compatibilité.
