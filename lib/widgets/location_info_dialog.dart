import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';

/// Dialog informatif sur l'utilisation de la localisation
/// S'affiche sur le côté de l'écran avec une animation
/// Positionné au-dessus de la navigation mobile native
class LocationInfoDialog extends StatelessWidget {
  const LocationInfoDialog({super.key});

  /// Afficher le dialog de manière asynchrone
  /// Retourne true si l'utilisateur accepte, false s'il refuse
  static Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // L'utilisateur doit choisir
      useSafeArea: false, // Positionner au-dessus de la navigation native
      builder: (BuildContext context) {
        return const LocationInfoDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 768;
    final padding = MediaQuery.of(context).padding;
    
    // Calculer la position pour être au-dessus de la navigation native
    final bottomPadding = padding.bottom > 0 ? padding.bottom : 0;
    
    return Dialog(
      alignment: Alignment.center, // ✅ Centré au lieu de centerRight
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        width: isMobile ? double.infinity : 400, // Largeur adaptative
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85, // Maximum 85% de la hauteur d'écran
          maxWidth: isMobile ? screenWidth - 32 : 400, // Largeur max avec padding
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        child: SingleChildScrollView( // ✅ Permet le scroll si le contenu est trop grand
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Icône de localisation
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: const Color(0xFF2196F3),
                    size: isMobile ? 32 : 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    translationService.translate('LOCATION_DIALOG_TITLE'),
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isMobile ? 24 : 28),
            
            // Message principal
            Text(
              translationService.translate('LOCATION_DIALOG_MAIN_MESSAGE'),
              style: TextStyle(
                fontSize: isMobile ? 17 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
                height: 1.5,
                letterSpacing: -0.3,
              ),
            ),
            
            SizedBox(height: isMobile ? 20 : 24),
            
            // Liste des utilisations
            _buildUsageItem(
              context: context,
              icon: Icons.map,
              translationKey: 'LOCATION_DIALOG_USAGE_STORES',
              isMobile: isMobile,
            ),
            
            SizedBox(height: isMobile ? 16 : 18),
            
            _buildUsageItem(
              context: context,
              icon: Icons.center_focus_strong,
              translationKey: 'LOCATION_DIALOG_USAGE_CENTER',
              isMobile: isMobile,
            ),
            
            SizedBox(height: isMobile ? 16 : 18),
            
            _buildUsageItem(
              context: context,
              icon: Icons.search,
              translationKey: 'LOCATION_DIALOG_USAGE_SEARCH',
              isMobile: isMobile,
            ),
            
            SizedBox(height: isMobile ? 24 : 28),
            
            // Note importante
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue[200]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: isMobile ? 22 : 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      translationService.translate('LOCATION_DIALOG_INFO_MESSAGE'),
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        color: Colors.blue[900],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isMobile ? 24 : 28),
            
            // Note sur la position par défaut en cas de refus
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_city,
                    color: Colors.grey[600],
                    size: isMobile ? 18 : 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      translationService.translate('LOCATION_DIALOG_DEFAULT_POSITION_INFO'),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey[700],
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isMobile ? 28 : 32),
            
            // Boutons Accepter / Refuser
            Row(
              children: [
                // Bouton Refuser
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(
                        color: Colors.grey[400]!,
                        width: 1.5,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(0, isMobile ? 48 : 52), // Hauteur minimale adaptative
                    ),
                    child: Text(
                      translationService.translate('LOCATION_DIALOG_REFUSE'),
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis, // ✅ Évite le débordement de texte
                    ),
                  ),
                ),
                
                SizedBox(width: isMobile ? 12 : 16),
                
                // Bouton Accepter
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      minimumSize: Size(0, isMobile ? 48 : 52), // Hauteur minimale adaptative
                    ),
                    child: Text(
                      translationService.translate('LOCATION_DIALOG_ACCEPT'),
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis, // ✅ Évite le débordement de texte
                    ),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageItem({
    required BuildContext context,
    required IconData icon,
    required String translationKey,
    required bool isMobile,
  }) {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2196F3),
            size: isMobile ? 22 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              translationService.translate(translationKey),
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                color: Colors.grey[800],
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

