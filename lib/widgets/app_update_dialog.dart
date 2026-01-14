import 'package:flutter/material.dart';
import '../models/app_version_info.dart';
import '../services/app_update_service.dart';
import '../services/local_storage_service.dart';

/// Dialogue professionnel pour afficher les informations de mise à jour
class AppUpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final bool isDismissible;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    this.isDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final appUpdateService = AppUpdateService();
    final isRequired = versionInfo.needsUpdate;
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isRequired,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête avec dégradé
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRequired
                        ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
                        : [const Color(0xFF0066FF), const Color(0xFF00A8FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Icône avec cercle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRequired ? Icons.priority_high : Icons.system_update_alt,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Titre
                    Text(
                      versionInfo.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Badge de type de mise à jour
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isRequired ? 'MISE À JOUR OBLIGATOIRE' : 'Mise à jour disponible',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Message principal avec icône
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              versionInfo.message,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Texte explicatif pour mise à jour obligatoire
                      if (isRequired) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFFB74D),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFFF9800),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cette mise à jour est nécessaire pour continuer à utiliser l\'application en toute sécurité.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Notes de version
                      if (versionInfo.releaseNotes.isNotEmpty &&
                          versionInfo.releaseNotes != versionInfo.message) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              color: theme.primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nouveautés de cette version',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF21252F),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            versionInfo.releaseNotes,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],

                      // Informations de version
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey[100]!,
                              Colors.grey[50]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildVersionRow(
                              icon: Icons.apps,
                              label: 'Version actuelle',
                              version: versionInfo.currentVersion,
                              color: Colors.grey[600]!,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            _buildVersionRow(
                              icon: Icons.new_releases,
                              label: 'Nouvelle version',
                              version: versionInfo.latestVersion,
                              color: const Color(0xFF0066FF),
                              isNew: true,
                            ),
                          ],
                        ),
                      ),

                      // Texte explicatif additionnel
                      if (!isRequired) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nous vous recommandons de mettre à jour pour profiter des dernières améliorations.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[900],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    // Bouton "Plus tard" (si optionnel)
                    if (!isRequired)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Plus tard',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    if (!isRequired) const SizedBox(width: 12),
                    // Bouton "Mettre à jour"
                    Expanded(
                      flex: isRequired ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await appUpdateService.openStore(versionInfo.updateUrl);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRequired
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF0066FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isRequired ? 'Mettre à jour maintenant' : 'Mettre à jour',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Widget pour afficher une ligne d'information de version
  Widget _buildVersionRow({
    required IconData icon,
    required String label,
    required String version,
    required Color color,
    bool isNew = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      version,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Afficher le dialogue de mise à jour
  static Future<void> show({
    required BuildContext context,
    required AppVersionInfo versionInfo,
  }) async {
    final isRequired = versionInfo.needsUpdate;

    // ✅ Si c'est une mise à jour forcée, sauvegarder les infos pour la prochaine fois
    if (isRequired) {
      print('💾 Sauvegarde des informations de mise à jour forcée...');
      await LocalStorageService.savePendingForceUpdate(versionInfo.toJson());
    }

    await showDialog(
      context: context,
      barrierDismissible: !isRequired,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => AppUpdateDialog(
        versionInfo: versionInfo,
        isDismissible: !isRequired,
      ),
    );
  }
}