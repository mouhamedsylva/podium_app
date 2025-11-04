import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import '../models/country.dart';
import '../services/country_service.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../config/api_config.dart';

/// Écran de sélection de pays - Design exact de l'image de référence
class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> with TickerProviderStateMixin {
  final CountryService _countryService = CountryService();
  final TextEditingController _searchController = TextEditingController();

  List<Country> _allCountries = [];
  List<Country> _filteredCountries = [];
  Country? _selectedCountry;
  bool _termsAccepted = false;
  bool _isLoading = false;

  // Controllers d'animation
  late AnimationController _mainAnimationController;
  late AnimationController _listAnimationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  double _clamp01(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }

  @override
  void initState() {
    super.initState();
    
    // Initialiser les controllers d'animation
    _mainAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: Curves.easeIn,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Démarrer l'animation principale
    _mainAnimationController.forward();
    
    // Initialiser les traductions de manière asynchrone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTranslations();
      _loadCountries();
    });
  }

  Future<void> _initializeTranslations() async {
    // Initialiser les traductions en français par défaut
    if (mounted) {
      final translationService = Provider.of<TranslationService>(context, listen: false);
      try {
        await translationService.loadTranslations('fr');
      } catch (e) {
        print('⚠️ Erreur lors de l\'initialisation des traductions: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mainAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _countryService.initialize();
      final countries = await _countryService.fetchCountriesFromAPI();
      
      if (mounted) {
        setState(() {
          _allCountries = countries;
          _filteredCountries = countries;
          _isLoading = false;
        });
        // Démarrer l'animation de la liste après le chargement
        _listAnimationController.forward();
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des pays: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur lors du chargement des pays');
      }
    }
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        // Si le champ est vide, revenir à la liste complète
        _filteredCountries = _allCountries;
        _selectedCountry = null; // Réinitialiser la sélection
      } else {
        // Filtrer les pays selon la recherche
        _filteredCountries = _allCountries.where((country) =>
          country.sDescr.toLowerCase().contains(query.toLowerCase())
        ).toList();
        // Si on tape quelque chose, réinitialiser la sélection
        _selectedCountry = null;
      }
    });
    
    // Ne pas relancer l'animation à chaque frappe afin d'éviter les sauts visuels
    // La liste reste stable pendant l'édition et n'anime que lors du premier affichage
  }

  void _selectCountry(Country country) async {
    setState(() {
      _selectedCountry = country;
      // Mettre à jour le champ de recherche avec le pays sélectionné
      _searchController.text = country.sDescr;
      // Le container de sélection disparaîtra automatiquement
    });

    // Charger les traductions pour la langue du pays sélectionné
    if (mounted && country.sPaysLangue != null) {
      final translationService = Provider.of<TranslationService>(context, listen: false);
      try {
        await translationService.changeLanguage(country.sPaysLangue!);
      } catch (e) {
        print('⚠️ Erreur lors du changement de langue: $e');
        // L'erreur est gérée - les clés de traduction s'afficheront si pas de traduction
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedCountry != null && _termsAccepted) {
      setState(() => _isLoading = true);
      
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final success = await settingsService.saveCountrySelection(
        selectedCountry: _selectedCountry!,
        termsAccepted: _termsAccepted,
      );
      
      if (success && mounted) {
        context.go('/home');
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur lors de la sauvegarde');
      }
    } else {
      _showErrorSnackBar('Veuillez sélectionner un pays et accepter les conditions');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSelectedCountry({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        final safe = _clamp01(value);
        return Transform.scale(
          scale: safe,
          child: Opacity(
            opacity: safe,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
                vertical: isVerySmallMobile ? 6 : (isSmallMobile ? 7 : 8),
              ),
              decoration: BoxDecoration(
                color: Colors.white, // Fond blanc
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1 * safe),
                    blurRadius: 8 * safe,
                    offset: Offset(0, 2 * safe),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Drapeau
                  Container(
                    width: isVerySmallMobile ? 20 : (isSmallMobile ? 21 : 22),
                    height: isVerySmallMobile ? 14 : (isSmallMobile ? 14.5 : 15),
                    child: _buildFlagImage(_selectedCountry!),
                  ),
                  
                  SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                  
                  // Nom du pays
                  Expanded(
                    child: Text(
                      _selectedCountry!.sDescr,
                      style: TextStyle(
                        fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : (isMobile ? 16 : 18)),
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTermsDialog({required TranslationService translationService}) {
    // Chercher le contenu des conditions d'utilisation dans les traductions
    // Essayer différentes clés possibles basées sur SNAL-Project
    String termsContent = '';
    
    // Essayer les clés possibles pour le contenu complet des conditions
    final possibleKeys = [
      'ONBOARDING_Msg10', // Possible clé pour le contenu complet
      'TERMS_OF_USE_CONTENT',
      'TERMS_CONTENT',
      'CONDITIONS_D_UTILISATION_CONTENT',
      'ONBOARDING_TERMS_CONTENT',
      'PROJET_TERMS_CONTENT',
    ];
    
    for (final key in possibleKeys) {
      final content = translationService.translate(key);
      if (content != key) {
        // Si la traduction existe (ne retourne pas la clé elle-même)
        termsContent = content;
        break;
      }
    }
    
    // Si aucune clé n'est trouvée, utiliser le fallback
    if (termsContent.isEmpty) {
      termsContent = 'En utilisant Jirig, vous acceptez nos conditions d\'utilisation...\n\n'
          'Pour plus d\'informations, consultez notre politique.';
    }
    
    // Titre traduit - utiliser ONBOARDING_Msg06 qui correspond à "Voir les conditions" dans SNAL
    String termsTitle = translationService.translate('ONBOARDING_Msg06');
    if (termsTitle == 'ONBOARDING_Msg06') {
      termsTitle = translationService.translate('SELECT_COUNTRY_VIEW_TERMS');
      if (termsTitle == 'SELECT_COUNTRY_VIEW_TERMS') {
        termsTitle = 'Conditions d\'utilisation'; // Fallback
      }
    }
    
    // Bouton fermer traduit - utiliser ONBOARDING_Msg07 qui correspond au bouton de fermeture dans SNAL
    String closeButton = translationService.translate('ONBOARDING_Msg07');
    if (closeButton == 'ONBOARDING_Msg07') {
      closeButton = translationService.translate('CLOSE');
      if (closeButton == 'CLOSE') {
        closeButton = 'Fermer'; // Fallback
      }
    }
    
    showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 250),
      ),
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          termsTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            termsContent,
            style: const TextStyle(
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              closeButton,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Détection de la taille de l'écran pour la responsivité mobile
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isVerySmallMobile = screenWidth < 361;   // Galaxy Fold fermé, Galaxy S8+ (≤360px)
    final isSmallMobile = screenWidth < 431;       // iPhone XR/14 Pro Max, Pixel 7, Galaxy S20/A51 (361-430px)
    final isMobile = screenWidth < 768;            // Tous les mobiles standards (431-767px)
    final isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablettes
    
    return Consumer<TranslationService>(
      builder: (context, translationService, child) {
        // Ajustement des dimensions selon l'écran
        final horizontalPadding = isVerySmallMobile ? 8.0 : (isSmallMobile ? 12.0 : (isMobile ? 16.0 : 20.0));
        final verticalPadding = isVerySmallMobile ? 40.0 : (isSmallMobile ? 50.0 : (isMobile ? 60.0 : 80.0));
        final bottomPadding = isVerySmallMobile ? 40.0 : (isSmallMobile ? 50.0 : (isMobile ? 60.0 : 80.0));
        final containerPadding = horizontalPadding; // Même espacement que l'extérieur du container
        final borderRadius = isMobile ? 8.0 : 12.0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Image de fond hero5.png
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            bottom: -100,
            child: Image.asset(
              'assets/images/hero5.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.white);
              },
            ),
          ),
          // Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                left: horizontalPadding, 
                right: horizontalPadding, 
                top: verticalPadding, 
                bottom: bottomPadding
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: containerPadding, 
                    right: containerPadding, 
                    top: isVerySmallMobile ? 20.0 : (isSmallMobile ? 30.0 : (isMobile ? 40.0 : 50.0)), 
                    bottom: isVerySmallMobile ? 20.0 : (isSmallMobile ? 30.0 : (isMobile ? 40.0 : 50.0))
                  ),
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Titre principal
                  _buildTitle(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile, translationService: translationService),
                  
                  SizedBox(height: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : (isMobile ? 12 : 16))),
                  
                  // Sous-titre
                  _buildSubtitle(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile, translationService: translationService),
                  
                  SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : (isMobile ? 24 : 32))),
                  
                  // Section pays d'origine
                  _buildCountrySection(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile, translationService: translationService),
                  
                  SizedBox(height: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : (isMobile ? 24 : 32))),
                  
                  // Checkbox et conditions
                  _buildTermsSection(translationService: translationService),
                  
                  SizedBox(height: isVerySmallMobile ? 20 : (isSmallMobile ? 28 : (isMobile ? 32 : 40))),
                  
                  // Bouton Terminer
                  _buildSubmitButton(translationService: translationService),
                  
                  SizedBox(height: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : (isMobile ? 16 : 20))),
                  
                  // Note de bas de page
                  _buildFooterNote(translationService: translationService),
                ],
              ),
            ),
          ),
        ),      ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTitle({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false, required TranslationService translationService}) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: isVerySmallMobile ? 22 : (isSmallMobile ? 24 : (isMobile ? 27 : 24)),
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.4,
            ),
            children: [
              TextSpan(text: translationService.translate('SELECT_COUNTRY_TITLE_PART1')),
              TextSpan(
                text: 'IKEA',
                style: TextStyle(
                  color: Colors.amber[700],
                ),
              ),
              TextSpan(text: translationService.translate('SELECT_COUNTRY_TITLE_PART2')),
              TextSpan(
                text: 'Jirig',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false, required TranslationService translationService}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
        child: Text(
          translationService.translate('FRONTPAGE_Msg02'),
          style: TextStyle(
            fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14),
            color: Colors.black,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCountrySection({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false, required TranslationService translationService}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                translationService.translate('SELECT_COUNTRY_ORIGIN_COUNTRY'),
                style: TextStyle(
                  fontSize: isVerySmallMobile ? 14 : (isSmallMobile ? 15 : 16),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
        
        SizedBox(height: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
        
        // Barre de recherche toujours éditable
        TextField(
          controller: _searchController,
          onChanged: _filterCountries,
          enabled: true, // S'assurer que le champ est toujours éditable
          onTap: () {
            // Permettre l'édition immédiate
            if (_selectedCountry != null) {
              // Placer le curseur à la fin du texte pour permettre l'édition
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: _searchController.text.length),
              );
            }
          },
          decoration: InputDecoration(
            hintText: translationService.translate('SELECT_COUNTRY_SEARCH_PLACEHOLDER'),
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : 14),
            ),
            // Pas de drapeau dans le champ de recherche
            prefixIcon: null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isVerySmallMobile ? 16 : (isSmallMobile ? 20 : 25),
              vertical: isVerySmallMobile ? 10 : (isSmallMobile ? 11 : 12),
            ),
          ),
        ),
        
        // Afficher la liste des pays seulement si aucun pays n'est sélectionné
        if (_selectedCountry == null) ...[
          SizedBox(height: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 4 : 6))),
          _buildCountryList(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile, translationService: translationService),
        ],
        
        // Afficher le pays sélectionné sans container
        if (_selectedCountry != null) ...[
          SizedBox(height: isVerySmallMobile ? 2 : (isSmallMobile ? 3 : (isMobile ? 4 : 6))),
          _buildSelectedCountry(isMobile: isMobile, isSmallMobile: isSmallMobile, isVerySmallMobile: isVerySmallMobile),
        ],
      ],
        ),
      ),
    );
  }

  Widget _buildCountryList({bool isMobile = false, bool isSmallMobile = false, bool isVerySmallMobile = false, required TranslationService translationService}) {
    final containerHeight = isVerySmallMobile ? 200.0 : (isSmallMobile ? 220.0 : (isMobile ? 240.0 : 320.0));
    
    if (_isLoading) {
      return Container(
        height: containerHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredCountries.isEmpty) {
      return Container(
        height: containerHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'Aucun pays trouvé',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      height: containerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.grey[800]),
          trackColor: MaterialStateProperty.all(Colors.grey[300]),
          thickness: MaterialStateProperty.all(6.0),
          radius: const Radius.circular(3),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            // Empêcher la propagation du scroll vers le parent
            return true;
          },
          child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
            final country = _filteredCountries[index];
            final isSelected = _selectedCountry?.sPays == country.sPays;
            
            // Animation staggerée pour chaque élément de la liste
            final delay = index * 0.05; // 50ms de délai entre chaque élément
            
            return AnimatedBuilder(
              animation: _listAnimationController,
              builder: (context, child) {
                // Calcule un progress borné entre 0 et 1 pour chaque item, sans divisions par zéro
                const double itemInterval = 0.3; // fenêtre d'animation par item
                final double startDelay = delay.clamp(0.0, 0.7); // borne pour éviter >= 1.0
                final double raw = (_listAnimationController.value - startDelay)
                    .clamp(0.0, itemInterval);
                final double t = (itemInterval == 0)
                    ? 1.0
                    : raw / itemInterval; // 0..1
                final double animationProgress = Curves.easeOut.transform(t);

                return Transform.translate(
                  offset: Offset(0, 30 * (1 - _clamp01(animationProgress))),
                  child: Opacity(
                    opacity: _clamp01(animationProgress),
                    child: child,
                  ),
                );
              },
              child: InkWell(
                onTap: () => _selectCountry(country),
                hoverColor: Colors.grey[100],
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallMobile ? 12 : (isSmallMobile ? 14 : 16),
                    vertical: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12),
                  ),
                  color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.white,
                  child: Row(
                    children: [
                      // Drapeau image
                      Container(
                        width: isVerySmallMobile ? 24 : (isSmallMobile ? 26 : 28),
                        height: isVerySmallMobile ? 18 : (isSmallMobile ? 19 : 20),
                        child: _buildFlagImage(country),
                      ),
                      
                      SizedBox(width: isVerySmallMobile ? 8 : (isSmallMobile ? 10 : 12)),
                      
                      // Nom du pays
                      Expanded(
                        child: Text(
                          country.sDescr,
                          style: TextStyle(
                            fontSize: isVerySmallMobile ? 12 : (isSmallMobile ? 13 : (isMobile ? 14 : 15)),
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Widget _buildFlagImage(Country country) {
    // Utiliser l'image du drapeau depuis l'API ou les assets locaux
    final flagPath = country.flagImagePath;
    
    // Si le chemin commence par /img/ ou /public/, c'est une image depuis SNAL
    if (flagPath.startsWith('/img/') || flagPath.startsWith('/public/')) {
      // Utiliser le proxy pour charger l'image depuis SNAL
      final imageUrl = ApiConfig.getProxiedImageUrl(flagPath);
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          imageUrl,
          width: 28,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback vers les assets locaux
            return _buildLocalFlagImage(country.sPays);
          },
        ),
      );
    } else {
      // Utiliser les assets locaux
      return _buildLocalFlagImage(country.sPays);
    }
  }
  
  Widget _buildLocalFlagImage(String countryCode) {
    // Charger depuis les assets locaux
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.asset(
        'assets/img/flags/${countryCode.toUpperCase()}.PNG',
        width: 28,
        height: 20,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback vers un emoji
          return Center(
            child: Text(
              _getCountryFlagEmoji(countryCode),
              style: const TextStyle(fontSize: 18),
            ),
          );
        },
      ),
    );
  }
  
  String _getCountryFlagEmoji(String countryCode) {
    // Mapping simple de codes pays vers emojis de drapeaux (fallback)
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
      'LU': '🇱🇺',
    };
    return flags[countryCode] ?? '🏳️';
  }

  Widget _buildTermsSection({required TranslationService translationService}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() => _termsAccepted = value ?? false);
                },
                activeColor: const Color(0xFF2196F3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                child: Text(
                  translationService.translate('SELECT_COUNTRY_ACCEPT_TERMS'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => _showTermsDialog(translationService: translationService),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
                child: Text(
                  translationService.translate('SELECT_COUNTRY_VIEW_TERMS'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton({required TranslationService translationService}) {
    final canContinue = _selectedCountry != null && _termsAccepted;
    
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _mainAnimationController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: canContinue ? _saveSettings : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canContinue 
                  ? const Color(0xFF2196F3) 
                  : Colors.grey[300],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: canContinue ? 2 : 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    translationService.translate('SELECT_COUNTRY_FINISH_BUTTON'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNote({required TranslationService translationService}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            height: 1.3,
          ),
          children: [
            TextSpan(
              text: translationService.translate('SELECT_COUNTRY_FOOTER_TEXT'),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: () => _showTermsDialog(translationService: translationService),
                child: Text(
                  translationService.translate('SELECT_COUNTRY_TERMS_LINK'),
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}