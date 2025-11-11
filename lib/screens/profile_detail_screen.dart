import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/country.dart';
import '../services/local_storage_service.dart';
import '../services/auth_notifier.dart';
import '../services/profile_service.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../config/api_config.dart'; // Added import for ApiConfig

/// Écran de profil utilisateur - Affiche les pays principal et favoris
class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({Key? key}) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isLoading = true;
  String _sPaysLangue = '';
  String _sPaysFav = '';
  Country? _selectedCountry;
  Map<String, String>? _userInfo;
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Recharger les données quand l'écran devient visible (pour voir les mises à jour après sauvegarde)
    // Utiliser une vérification pour éviter les rechargements inutiles
    if (!_isLoading) {
      _loadProfileData();
    }
  }

  /// Charger les données du profil depuis les cookies
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    
    try {
      // ✅ CORRECTION: Charger TOUJOURS depuis LocalStorageService en priorité
      // pour garantir que les données modifiées dans profile_screen sont affichées
      print('📱 Chargement depuis LocalStorageService (source de vérité)...');
      final profile = await LocalStorageService.getProfile();
      
      if (profile != null) {
        _sPaysLangue = profile['sPaysLangue']?.toString() ?? '';
        _sPaysFav = profile['sPaysFav']?.toString() ?? '';
        
        print('✅ Profil chargé depuis LocalStorageService:');
        print('   sPaysLangue: $_sPaysLangue');
        print('   sPaysFav: $_sPaysFav');
        
        // Si les données sont vides, essayer ProfileService comme fallback
        if (_sPaysLangue.isEmpty || _sPaysFav.isEmpty) {
          print('⚠️ Données vides dans LocalStorage, tentative avec ProfileService');
          await _profileService.syncWithCookies();
          _sPaysLangue = _profileService.sPaysLangue ?? _sPaysLangue;
          _sPaysFav = _profileService.sPaysFav ?? _sPaysFav;
          print('   sPaysLangue (ProfileService): $_sPaysLangue');
          print('   sPaysFav (ProfileService): $_sPaysFav');
        }
      } else {
        // Fallback vers ProfileService si LocalStorageService ne retourne rien
        print('⚠️ LocalStorageService vide, tentative avec ProfileService');
        await _profileService.syncWithCookies();
        _sPaysLangue = _profileService.sPaysLangue ?? '';
        _sPaysFav = _profileService.sPaysFav ?? '';
        print('   sPaysLangue (ProfileService): $_sPaysLangue');
        print('   sPaysFav (ProfileService): $_sPaysFav');
      }
    } catch (e) {
      print('❌ Erreur chargement profil: $e');
      _sPaysLangue = '';
      _sPaysFav = '';
    }

    try {
      final settingsService = SettingsService();
      final selected = await settingsService.getSelectedCountry();
      if (selected != null) {
        _selectedCountry = selected;
        final langue = selected.sPaysLangue;
        if (langue != null && langue.isNotEmpty) {
          _sPaysLangue = langue;
        } else {
          _sPaysLangue = selected.sPays;
        }
      }
    } catch (e) {
      print('⚠️ Impossible de récupérer le pays sélectionné: $e');
    } finally {
      _sPaysFav = _normalizeCountriesString(_sPaysFav);
      setState(() => _isLoading = false);
    }
  }

  /// Rafraîchir les données du profil depuis les cookies
  Future<void> _refreshProfileData() async {
    await _loadProfileData();
  }

  /// Obtenir le code de pays depuis sPaysLangue
  String _getCountryCodeFromLangue(String langue) {
    if (langue.contains('/')) {
      return langue.split('/')[0];
    }
    if (langue.contains('-')) {
      return langue.split('-')[0];
    }
    return 'FR'; // Default
  }

  /// Obtenir le nom du pays depuis le code (comme SNAL)
  String _getCountryNameFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'FR':
        return 'France';
      case 'DE':
        return 'Deutschland';
      case 'BE':
        return 'Belgique/België';
      case 'ES':
        return 'España';
      case 'IT':
        return 'Italia';
      case 'NL':
        return 'Nederland';
      case 'PT':
        return 'Portugal';
      case 'GB':
        return 'United Kingdom';
      default:
        return code;
    }
  }

  String _normalizeCountriesString(String raw) {
    if (raw.isEmpty) return '';
    final sanitized = raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    final codes = sanitized
        .split(',')
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    return codes.join(',');
  }

  /// Obtenir le chemin local du drapeau depuis les assets
  String _getFlagPath(String countryCode) {
    final code = countryCode.toUpperCase();
    print('🚩 Chargement du drapeau local pour: ' + code);
    // Chemin vers les assets locaux
    final flagPath = 'assets/img/flags/' + code + '.PNG';
    print('✅ Chemin du drapeau: ' + flagPath);
    print('🔍 Plateforme: ' + Theme.of(context).platform.toString());
    return flagPath;
  }

  /// URL du drapeau via proxy (évite les problèmes d'assets sur mobile)
  String _getFlagUrl(String countryCode) {
    final code = countryCode.toUpperCase();
    final url = ApiConfig.getProxiedImageUrl('https://jirig.be/img/flags/' + code + '.PNG');
    print('🌐 URL drapeau: ' + url);
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: CustomAppBar(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bouton "Modifier mon profil"
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Rediriger vers la page de modification du profil
                            context.go('/profile');
                          },
                          icon: Icon(Icons.edit, color: Colors.white),
                          label: Consumer<TranslationService>(
                            builder: (context, translationService, child) {
                              return Text(
                                translationService.translate('PROFILE_EDIT_BUTTON'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0051BA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 16 : 20,
                              horizontal: 24,
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 24 : 32),
                      
                      // Section Pays principal
                      SizedBox(
                        width: double.infinity,
                        child: _buildMainCountrySection(isMobile),
                      ),
                      SizedBox(height: isMobile ? 24 : 32),
                      
                      // Section Pays favoris
                      SizedBox(
                        width: double.infinity,
                        child: _buildFavoriteCountriesSection(isMobile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: CustomBottomNavigationBar(),
    );
  }

  Widget _buildMainCountrySection(bool isMobile) {
    String countryCode = _getCountryCodeFromLangue(_sPaysLangue);
    String countryName = _getCountryNameFromCode(countryCode);

    if (_selectedCountry != null) {
      countryCode = _selectedCountry!.countryCode.toUpperCase();
      countryName = _selectedCountry!.sDescr;
    }
    
    // Debug pour voir les données utilisées
    print('🔍 DEBUG Pays principal:');
    print('   _sPaysLangue: $_sPaysLangue');
    print('   countryCode: $countryCode');
    print('   countryName: $countryName');

    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 32 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translationService.translate('PROFILE_MAIN_COUNTRY'),
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            if (_sPaysLangue.isNotEmpty)
              Row(
                children: [
                  // Drapeau
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      _getFlagUrl(countryCode),
                      width: isMobile ? 32 : 36,
                      height: isMobile ? 24 : 27,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Erreur chargement drapeau principal URL: ' + error.toString());
                        return Container(
                          width: isMobile ? 32 : 36,
                          height: isMobile ? 24 : 27,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.flag,
                            color: Colors.grey[400],
                            size: isMobile ? 16 : 18,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  // Nom du pays
                  Text(
                    countryName,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  translationService.translate('PROFILE_NOT_SELECTED'),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildFavoriteCountriesSection(bool isMobile) {
    // Parser les pays favoris depuis sPaysFav (format: "FR,BE,NL,PT,DE,ES,IT") - comme SNAL
    final favoriteCountries = _sPaysFav.isNotEmpty ? _sPaysFav.split(',') : [];
    
    // Nettoyer les codes de pays (enlever les espaces) et filtrer AT et CH
    final cleanFavoriteCountries = favoriteCountries
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty && code != 'AT' && code != 'CH')
        .toList();
    
    // Debug pour voir les données utilisées
    print('🔍 DEBUG Pays favoris:');
    print('   _sPaysFav: $_sPaysFav');
    print('   favoriteCountries: $favoriteCountries');
    print('   cleanFavoriteCountries (sans AT/CH): $cleanFavoriteCountries');

    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 32 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translationService.translate('PROFILE_FAVORITE_COUNTRIES'),
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            if (cleanFavoriteCountries.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  translationService.translate('PROFILE_NO_FAVORITE_COUNTRIES'),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              Wrap(
                spacing: isMobile ? 8 : 12,
                runSpacing: isMobile ? 8 : 12,
                children: cleanFavoriteCountries.map((countryCode) {
                  final countryName = _getCountryNameFromCode(countryCode);
                  final flagPath = _getFlagPath(countryCode);
                  
                  print('🏴 Affichage drapeau favori: $countryCode - Mobile: $isMobile');

                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drapeau
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.network(
                            _getFlagUrl(countryCode),
                            width: isMobile ? 20 : 24,
                            height: isMobile ? 15 : 18,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Erreur chargement drapeau favori URL: ' + error.toString());
                              return Container(
                                width: isMobile ? 20 : 24,
                                height: isMobile ? 15 : 18,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.flag,
                                  color: Colors.grey[400],
                                  size: isMobile ? 10 : 12,
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        // Nom du pays
                        Text(
                          countryName,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
        );
      },
    );
  }
}