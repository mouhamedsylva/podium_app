import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
    final horizontalPadding =
        isMobile ? (screenWidth < 360 ? 12.0 : 16.0) : 24.0;

    final translationService =
        Provider.of<TranslationService>(context, listen: true);
    final authNotifier = Provider.of<AuthNotifier>(context, listen: true);
    final isLoggedIn = authNotifier.isLoggedIn;
    final userInfo = authNotifier.userInfo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 12,
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
            Consumer2<SettingsService, CountryNotifier>(
              builder: (context, settingsService, countryNotifier, child) {
                if (settingsService == null || countryNotifier == null) {
                  return SizedBox(
                    width: isMobile ? 44 : 52,
                    height: isMobile ? 30 : 36,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                final currentLanguageCode = translationService.currentLanguage;
                final displayFlag = _getLanguageFlag(currentLanguageCode);

                return PopupMenuButton<String>(
                  onSelected: (String countryCode) {
                    _onCountrySelected(
                      context,
                      countryCode,
                      settingsService,
                      countryNotifier,
                    );
                  },
                  itemBuilder: (BuildContext context) =>
                      _buildLanguageMenuItems(),
                  child: isMobile
                      ? Text(
                          displayFlag,
                          style: const TextStyle(fontSize: 20),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              displayFlag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                  offset: const Offset(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  color: Colors.white,
                );
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double availableWidth = constraints.maxWidth;
                  final double spacing = isMobile
                      ? (availableWidth < 320 ? 8.0 : 12.0)
                      : 24.0;
                  final double actionWidth = isLoggedIn
                      ? (isMobile ? 40.0 : 44.0)
                      : (availableWidth < 360
                          ? 96.0
                          : (isMobile ? 116.0 : 140.0));

                  final double rawIconsWidth =
                      availableWidth - spacing - actionWidth;
                  final double iconsMaxWidth = rawIconsWidth <= 0
                      ? availableWidth * 0.6
                      : rawIconsWidth;

                  final connectionButton = _buildConnectionButton(
                    context,
                    isMobile,
                    translationService,
                    maxWidth: actionWidth,
                  );
                  final actionWidget = isLoggedIn
                      ? _buildUserAvatar(
                          context, isMobile, authNotifier, userInfo, translationService)
                      : connectionButton;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildSocialIcons(
                            isMobile,
                            maxWidth: iconsMaxWidth,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing),
                      if (isLoggedIn)
                        actionWidget
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: connectionButton,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcons(bool isMobile, {double? maxWidth}) {
    double iconSize = isMobile ? 26.0 : 30.0;
    double spacing = isMobile ? 18.0 : 24.0; // ✅ Encore plus d'espacement entre les icônes sociales

    final socialItems = [
      {
        'icon': FontAwesomeIcons.facebookF,
        'color': const Color(0xFF1877F2),
        'onTap': _goToFacebook,
      },
      {
        'icon': FontAwesomeIcons.instagram,
        'color': Colors.white,
        'gradient': const LinearGradient(
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        'onTap': _goToInstagram,
      },
      {
        'icon': FontAwesomeIcons.xTwitter,
        'color': Colors.black,
        'onTap': _goToTwitter,
      },
      {
        'icon': FontAwesomeIcons.tiktok,
        'color': Colors.black,
        'onTap': _goToTikTok,
      },
    ];

    final double totalBaseWidth =
        iconSize * socialItems.length + spacing * (socialItems.length - 1);

    if (maxWidth != null && maxWidth > 0 && maxWidth < totalBaseWidth) {
      final double scale = (maxWidth / totalBaseWidth).clamp(0.6, 1.0);
      iconSize *= scale;
      spacing *= scale;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < socialItems.length; i++) ...[
          _buildSocialIcon(
            socialItems[i]['icon'] as IconData,
            iconSize,
            socialItems[i]['onTap'] as VoidCallback,
            color: socialItems[i]['color'] as Color,
            gradient: socialItems[i]['gradient'] as LinearGradient?,
            accentColors: socialItems[i]['accentColors'] as List<Color>?,
          ),
          if (i != socialItems.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }

  Widget _buildSocialIcon(
    IconData icon,
    double size,
    VoidCallback onTap, {
    required Color color,
    LinearGradient? gradient,
    List<Color>? accentColors,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: gradient != null || accentColors != null
              ? BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(size * 0.35),
                )
              : null,
          child: Icon(
            icon,
            size: size * 0.68,
            color: gradient != null ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionButton(
    BuildContext context,
    bool isMobile,
    TranslationService translationService, {
    double? maxWidth,
  }) {
    final double minWidth = isMobile ? 88.0 : 110.0;
    final double resolvedMaxWidth = math.max(
      maxWidth ?? (isMobile ? 140.0 : 160.0),
      minWidth,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: resolvedMaxWidth,
      ),
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
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 10 : 12,
          ),
          minimumSize: Size.fromHeight(isMobile ? 38 : 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            translationService.translate('APPHEADER_LOGIN'),
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  /// Widget pour afficher l'avatar de l'utilisateur avec dropdown
  Widget _buildUserAvatar(BuildContext context, bool isMobile, AuthNotifier authNotifier, Map<String, String>? userInfo, TranslationService translationService) {
    final userName = '${userInfo?['prenom'] ?? ''} ${userInfo?['nom'] ?? ''}'.trim();
    final userPhoto = userInfo?['photo'];
    
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
                translationService.translate('PROFILE_LOGOUT'),
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
        width: isMobile ? 34 : 36,
        height: isMobile ? 34 : 36,
        alignment: Alignment.center,
        child: userPhoto != null && userPhoto.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  userPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      color: Colors.black87,
                      size: isMobile ? 28 : 30,
                    );
                  },
                ),
              )
            : Icon(
                Icons.person,
                color: Colors.black87,
                size: isMobile ? 28 : 30,
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
    final translationService = Provider.of<TranslationService>(context, listen: false);
    // Afficher une confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            translationService.translate('PROFILE_LOGOUT'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            translationService.translate('PROFILE_LOGOUT_CONFIRM'),
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                translationService.translate('WISHLIST_Msg30'),
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
              child: Text(translationService.translate('PROFILE_LOGOUT')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Effacer les informations de l'utilisateur via AuthNotifier
      await authNotifier.onLogout();
      
      // ✅ Afficher un message avec loading avant la redirection
      if (context.mounted) {
        // Afficher le dialog de redirection
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false, // Empêcher la fermeture
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0051BA)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      translationService.translate('LOGOUT_REDIRECT_MESSAGE') ?? 
                      'Vous allez être redirigé vers l\'onboarding...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
        
        // Attendre 2 secondes avant de rediriger
        await Future.delayed(const Duration(seconds: 2));
        
        // Fermer le dialog si toujours monté
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        
        // Rediriger vers l'onboarding
        if (context.mounted) {
          context.go('/country-selection');
        }
      }
    }
  }

  String _getLanguageFlag(String? languageCode) {
    const flags = {
      'fr': '🇫🇷',
      'en': '🇬🇧',
      'de': '🇩🇪',
      'es': '🇪🇸',
      'pt': '🇵🇹',
      'it': '🇮🇹',
      'nl': '🇳🇱',
    };
    return flags[languageCode?.toLowerCase()] ?? '🏳️';
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
                              // fontFamily non spécifié = utilise la police système (équivalent à system-ui)
                              fontStyle: FontStyle.normal, // Style: normal
                              fontSize: 16.0, // Size: 16px
                              fontWeight: FontWeight.w400, // Weight: 400 (normal)
                              color: Color.fromRGBO(0, 0, 0, 1.0), // Color: rgb(0, 0, 0) - noir
                              height: 24.0 / 16.0, // Line Height: 24px / 16px = 1.5
                              letterSpacing: 0.0, // Pas de letterSpacing
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
    // ✅ IMPORTANT: Ne PAS modifier selectedCountry lors du changement de langue
    // Le pays choisi lors de l'onboarding doit rester inchangé
    // Seulement mettre à jour la langue et sPaysLangue dans le profil
    
    // Créer un objet Country basique pour la notification (mais ne pas le sauvegarder comme selectedCountry)
    final country = Country(
      sPays: countryCode,
      sDescr: _getCountryName(countryCode),
      iPays: _getCountryId(countryCode),
      sPaysLangue: '$countryCode/$languageCode',
      image: '/img/flags/${countryCode.toUpperCase()}.PNG',
    );
    
    // ✅ Ne PAS mettre à jour selectedCountry dans SettingsService
    // settingsService.updateSelectedCountry(country); // ❌ DÉSACTIVÉ
    
    // Notifier les changements via le CountryNotifier (pour l'affichage)
    countryNotifier.updateSelectedCountry(country);
    
    // ✅ Ne PAS sauvegarder le nouveau pays comme selectedCountry
    // Seulement mettre à jour la langue dans les paramètres (sans modifier selectedCountry)
    settingsService.loadSettings().then((currentSettings) {
      settingsService.saveSettings(UserSettings(
        selectedCountry: currentSettings.selectedCountry, // ✅ Conserver le pays original de l'onboarding
        languageCode: languageCode, // ✅ Mettre à jour uniquement la langue
        termsAccepted: currentSettings.termsAccepted,
        favoriteCountries: currentSettings.favoriteCountries,
        lastUpdated: DateTime.now(),
      ));
    });
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

