import 'package:flutter/material.dart';
import '../models/app_version_info.dart';
import '../services/app_update_service.dart';

/// Dialogue pour afficher les informations de mise à jour
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
    final isRequired = versionInfo.needsUpdate; // Mise à jour obligatoire

    return PopScope(
      canPop: !isRequired, // Empêcher la fermeture si obligatoire
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.system_update,
              color: Color(0xFF0066FF),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                versionInfo.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF21252F),
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                versionInfo.message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF21252F),
                  height: 1.5,
                ),
              ),
              if (versionInfo.releaseNotes.isNotEmpty &&
                  versionInfo.releaseNotes != versionInfo.message) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes de version:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF21252F),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    versionInfo.releaseNotes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF21252F),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Version actuelle: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Text(
                    versionInfo.currentVersion,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF21252F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Nouvelle version: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                  Text(
                    versionInfo.latestVersion,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Bouton "Plus tard" (seulement si mise à jour optionnelle)
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Plus tard',
                style: TextStyle(
                  color: Color(0xFF666666),
                ),
              ),
            ),
          // Bouton "Mettre à jour"
          ElevatedButton(
            onPressed: () async {
              // Fermer le dialogue
              Navigator.of(context).pop();
              
              // Ouvrir le store
              await appUpdateService.openStore(versionInfo.updateUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Mettre à jour',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Afficher le dialogue de mise à jour
  static Future<void> show({
    required BuildContext context,
    required AppVersionInfo versionInfo,
  }) async {
    final isRequired = versionInfo.needsUpdate;
    
    await showDialog(
      context: context,
      barrierDismissible: !isRequired, // Empêcher la fermeture si obligatoire
      builder: (context) => AppUpdateDialog(
        versionInfo: versionInfo,
        isDismissible: !isRequired,
      ),
    );
  }
}
