import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 768;
    final padding = MediaQuery.of(context).padding;
    
    // Calculer la position pour être au-dessus de la navigation native
    final bottomPadding = padding.bottom > 0 ? padding.bottom : 0;
    
    return Dialog(
      alignment: Alignment.centerRight, // Positionné sur le côté droit
      insetPadding: EdgeInsets.only(
        right: isMobile ? 12 : 20,
        top: padding.top + 16, // Respecter la safe area du haut
        bottom: bottomPadding + 16, // Au-dessus de la navigation native
        left: isMobile ? 12 : 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        width: isMobile ? (screenWidth - 48) : 380, // Largeur adaptative avec padding
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.7, // Maximum 70% de la hauteur d'écran
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 24),
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
                    'Localisation',
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
              'Jirig utilise votre localisation pour :',
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
              icon: Icons.map,
              text: 'Afficher les magasins IKEA à proximité sur la carte',
              isMobile: isMobile,
            ),
            
            SizedBox(height: isMobile ? 16 : 18),
            
            _buildUsageItem(
              icon: Icons.center_focus_strong,
              text: 'Centrer la carte sur votre position actuelle',
              isMobile: isMobile,
            ),
            
            SizedBox(height: isMobile ? 16 : 18),
            
            _buildUsageItem(
              icon: Icons.search,
              text: 'Rechercher des magasins près de chez vous',
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
                      'Votre localisation est utilisée uniquement lorsque vous ouvrez la carte, et uniquement pendant que l\'application est ouverte.',
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
                        vertical: isMobile ? 16 : 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 48), // Hauteur minimale pour accessibilité
                    ),
                    child: Text(
                      'Refuser',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
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
                        vertical: isMobile ? 16 : 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      minimumSize: const Size(0, 48), // Hauteur minimale pour accessibilité
                    ),
                    child: Text(
                      'Accepter',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem({
    required IconData icon,
    required String text,
    required bool isMobile,
  }) {
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
              text,
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

