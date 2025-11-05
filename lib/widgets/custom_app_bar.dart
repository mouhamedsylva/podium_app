import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../services/country_notifier.dart';
import '../services/local_storage_service.dart';
import '../services/auth_notifier.dart';
import '../models/country.dart';
import '../models/user_settings.dart';
// Import conditionnel pour le web seulement (désactivé - on utilise url_launcher partout)
// import 'dart:html' as html show window;

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Consumer2<TranslationService, AuthNotifier>(
      builder: (context, translationService, authNotifier, child) {
        final isLoggedIn = authNotifier.isLoggedIn;
        final userInfo = authNotifier.userInfo;
        return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24, 
        vertical: 12
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            // Drapeau du pays sélectionné avec menu déroulant
            Consumer2<SettingsService, CountryNotifier>(
        builder: (context, settingsService, countryNotifier, child) {
                if (settingsService == null || countryNotifier == null) {
                  return Container(
                    width: isMobile ? 44 : 52,
                    height: isMobile ? 30 : 36,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                
                final selectedCountry = countryNotifier.selectedCountry ?? settingsService.selectedCountry;
                
                return PopupMenuButton<String>(
                  onSelected: (String countryCode) {
                    _onCountrySelected(context, countryCode, settingsService, countryNotifier);
                  },
                  itemBuilder: (BuildContext context) => _buildLanguageMenuItems(),
                  child: isMobile 
                    ? Text(
                        _getCountryFlag(selectedCountry?.sPays),
                        style: TextStyle(fontSize: 20),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getCountryFlag(selectedCountry?.sPays),
                            style: TextStyle(fontSize: 22),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                  offset: Offset(0, 40), // Position du menu
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  color: Colors.white,
                );
              },
            ),
            
            // Icônes sociales et bouton Connexion / Avatar
          Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
              children: [
                  _buildSocialIcons(isMobile),
                  SizedBox(width: isMobile ? 12 : 16),
                  // Afficher avatar si connecté, sinon bouton connexion
                  isLoggedIn
                      ? _buildUserAvatar(context, isMobile, authNotifier, userInfo)
                      : _buildConnectionButton(context, isMobile, translationService),
              ],
            ),
          ),
        ],
      ),
      ),
    );
      },
    );
  }

  Widget _buildSocialIcons(bool isMobile) {
    final spacing = isMobile ? 8.0 : 12.0;
    final iconSize = isMobile ? 32.0 : 38.0;
    
    return Row(
                      mainAxisSize: MainAxisSize.min,
          children: [
        // Facebook - cercle bleu
        _buildFacebookIcon(iconSize, _goToFacebook),
        SizedBox(width: spacing),
        // Instagram - dégradé
        _buildInstagramIcon(iconSize, _goToInstagram),
        SizedBox(width: spacing),
        // X (Twitter) - noir
        _buildXIcon(iconSize, _goToTwitter),
        SizedBox(width: spacing),
        // TikTok - logo avec couleurs cyan et magenta
        _buildTikTokIcon(iconSize, _goToTikTok),
      ],
    );
  }

  Widget _buildFacebookIcon(double size, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/face.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        ),
      ),
    );
  }

  Widget _buildInstagramIcon(double size, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/insta.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    ),
    );
  }

  Widget _buildXIcon(double size, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/twit.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
        ),
      ),
    );
  }

  Widget _buildTikTokIcon(double size, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        width: size,
        height: size,
        child: Image.asset(
          'assets/images/tiktok.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
            ),
          ),
        ),
    );
  }

  Widget _buildConnectionButton(BuildContext context, bool isMobile, TranslationService translationService) {
    return Flexible(
      child: ElevatedButton(
        onPressed: () {
          try {
            if (context.mounted) {
              context.go('/login');
            }
          } catch (e) {
            print('Erreur de navigation: $e');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0066FF),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 28, 
            vertical: isMobile ? 10 : 12
          ),
          minimumSize: Size(isMobile ? 90 : 110, isMobile ? 38 : 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: Text(
          translationService.translate('APPHEADER_LOGIN'),
          style: TextStyle(
            fontSize: isMobile ? 13 : 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Widget pour afficher l'avatar de l'utilisateur avec dropdown
  Widget _buildUserAvatar(BuildContext context, bool isMobile, AuthNotifier authNotifier, Map<String, String>? userInfo) {
    final userName = '${userInfo?['prenom'] ?? ''} ${userInfo?['nom'] ?? ''}'.trim();
    final userPhoto = userInfo?['photo'] ?? 'assets/img/avatar.png';
    
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'profile') {
          context.go('/profil');
        } else if (value == 'logout') {
          await _handleLogout(context, authNotifier);
        }
      },
      itemBuilder: (BuildContext context) => [
        // Nom de l'utilisateur avec icône profile encerclée (cliquable pour aller au profil)
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              // Icône profile encerclée
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.grey[600],
                  size: 16,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  userName.isNotEmpty ? userName : 'Utilisateur',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        // Option Déconnexion
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[600], size: 20),
              SizedBox(width: 12),
              Text(
                'Déconnexion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[600],
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: isMobile ? 36 : 40,
        height: isMobile ? 36 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/img/avatar.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                color: Colors.grey[600],
                size: isMobile ? 20 : 24,
              );
            },
          ),
        ),
      ),
      offset: Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 8,
      color: Colors.white,
    );
  }

  /// Gérer la déconnexion
  Future<void> _handleLogout(BuildContext context, AuthNotifier authNotifier) async {
    // Afficher une confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Déconnexion',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Déconnexion'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Effacer les informations de l'utilisateur via AuthNotifier
      await authNotifier.onLogout();
      
      // ✅ Ne pas rediriger - rester sur la page actuelle
      // L'utilisateur reste sur la page où il se trouve après la déconnexion
    }
  }

  String _getCountryFlag(String? countryCode) {
    const flags = {
      'BE': '🇧🇪',
      'FR': '🇫🇷',
      'DE': '🇩🇪',
      'ES': '🇪🇸',
      'IT': '🇮🇹',
      'NL': '🇳🇱',
      'PT': '🇵🇹',
      'GB': '🇬🇧',
      'US': '🇺🇸',
      'CA': '🇨🇦',
    };
    return flags[countryCode] ?? '🏳️';
  }

  List<PopupMenuEntry<String>> _buildLanguageMenuItems() {
    final languages = [
      {'code': 'FR', 'name': 'Français', 'flag': '🇫🇷'},
      {'code': 'GB', 'name': 'English', 'flag': '🇬🇧'},
      {'code': 'DE', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'ES', 'name': 'Español', 'flag': '🇪🇸'},
      {'code': 'PT', 'name': 'Português', 'flag': '🇵🇹'},
      {'code': 'IT', 'name': 'Italiano', 'flag': '🇮🇹'},
      {'code': 'NL', 'name': 'Nederlands', 'flag': '🇳🇱'},
    ];

    return languages.map((language) {
      return PopupMenuItem<String>(
        value: language['code']!,
                child: Row(
                  children: [
            Text(
              language['flag']!,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
                          Text(
              language['name']!,
                            style: const TextStyle(
                              fontSize: 14,
                fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  void _onCountrySelected(BuildContext context, String countryCode, SettingsService settingsService, CountryNotifier countryNotifier) {
    print('Pays sélectionné: $countryCode');
    
    // Mapper les codes pays vers les codes langue
    final languageMapping = {
      'FR': 'fr',
      'GB': 'en', 
      'DE': 'de',
      'ES': 'es',
      'PT': 'pt',
      'IT': 'it',
      'NL': 'nl',
    };
    
    final languageCode = languageMapping[countryCode] ?? 'fr';
    
    // Créer un objet Country temporaire pour mettre à jour le CountryNotifier
    _updateSelectedCountry(settingsService, countryNotifier, countryCode, languageCode);
    
    // Recharger les traductions avec la nouvelle langue de manière synchrone
    // pour une mise à jour immédiate
    final translationService = Provider.of<TranslationService>(context, listen: false);
    
    // Charger les traductions immédiatement
    translationService.loadTranslations(languageCode).then((_) {
      print('Langue changée vers: $languageCode');
      // Forcer une mise à jour de l'interface
      if (context.mounted) {
        // Déclencher un rebuild pour mettre à jour toutes les traductions
        (context as Element).markNeedsBuild();
      }
    }).catchError((e) {
      print('Erreur lors du changement de langue: $e');
    });
  }
  
  void _updateSelectedCountry(SettingsService settingsService, CountryNotifier countryNotifier, String countryCode, String languageCode) {
    // Créer un objet Country basique pour la mise à jour
    final country = Country(
      sPays: countryCode,
      sDescr: _getCountryName(countryCode),
      iPays: _getCountryId(countryCode),
      sPaysLangue: '$countryCode/$languageCode',
      image: '/img/flags/${countryCode.toUpperCase()}.PNG',
    );
    
    // Mettre à jour le pays sélectionné dans le SettingsService
    settingsService.updateSelectedCountry(country);
    
    // Notifier les changements via le CountryNotifier
    countryNotifier.updateSelectedCountry(country);
    
    // Sauvegarder les paramètres
    settingsService.saveSettings(UserSettings(
      selectedCountry: country,
      languageCode: languageCode,
      termsAccepted: true,
      favoriteCountries: [],
      lastUpdated: DateTime.now(),
    ));
  }
  
  String _getCountryName(String countryCode) {
    const countryNames = {
      'FR': 'France',
      'GB': 'United Kingdom',
      'DE': 'Germany',
      'ES': 'Spain',
      'PT': 'Portugal',
      'IT': 'Italy',
      'NL': 'Netherlands',
    };
    return countryNames[countryCode] ?? 'Unknown';
  }
  
  int _getCountryId(String countryCode) {
    const countryIds = {
      'FR': 1,
      'GB': 2,
      'DE': 3,
      'ES': 4,
      'PT': 5,
      'IT': 6,
      'NL': 7,
    };
    return countryIds[countryCode] ?? 1;
  }

  // Fonction utilitaire pour ouvrir les URLs
  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      // url_launcher fonctionne sur Web ET Mobile
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        );
        print('✅ Ouverture URL (${kIsWeb ? "web" : "mobile"}): $url');
      } else {
        print('❌ Impossible d\'ouvrir l\'URL: $url');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ouverture de l\'URL $url: $e');
    }
  }

  // Fonctions de redirection vers les réseaux sociaux
  Future<void> _goToInstagram() async {
    await _openUrl('https://www.instagram.com/my_jirig/');
  }

  Future<void> _goToFacebook() async {
    await _openUrl('https://www.facebook.com/profile.php?id=61576351702875');
  }

  Future<void> _goToTwitter() async {
    await _openUrl('https://x.com/MyJirig');
  }

  Future<void> _goToTikTok() async {
    await _openUrl('https://www.tiktok.com/@my_jirig?_t=ZG-8wcxnY4cSPI&_r=1');
  }
}

