import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import '../services/translation_service.dart';
import '../services/settings_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_notifier.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/premium_banner.dart';
import '../widgets/qr_scanner_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  // Contrôleurs d'animation pour chaque section
  late AnimationController _titleController;
  late AnimationController _modulesController;
  late AnimationController _bannerController;
  
  late Animation<double> _titleFadeAnimation;
  late Animation<double> _titleScaleAnimation;
  
  bool _isAnimationComplete = false;
  
  @override
  void initState() {
    super.initState();
    try {
      // Animation du titre (fade + scale)
      _titleController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _titleController,
          curve: Curves.easeOut,
        ),
      );
      
      _titleScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _titleController,
          curve: Curves.elasticOut,
        ),
      );
      
      // Animation des modules (delayed)
      _modulesController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      // Animation de la bannière (delayed)
      _bannerController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      
      // Démarrer les animations de manière échelonnée
      _startStaggeredAnimations();
      
      // Note: Le pays sélectionné est maintenant initialisé automatiquement dans SettingsService et CountryNotifier
      _checkOAuthCallback();
    } catch (e) {
      print('Erreur lors de l\'initialisation: $e');
    }
  }
  
  /// Démarrer les animations de manière échelonnée
  void _startStaggeredAnimations() async {
    // Animation du titre (immédiate)
    _titleController.forward();
    
    // Animation des modules (après 200ms)
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _modulesController.forward();
    
    // Animation de la bannière (après 400ms)
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      _bannerController.forward();
      setState(() => _isAnimationComplete = true);
    }
  }

  /// Vérifier si l'utilisateur vient de se connecter via OAuth
  Future<void> _checkOAuthCallback() async {
    // Attendre un court instant pour que la page soit montée
    await Future.delayed(Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    try {
      // Vérifier si l'utilisateur est connecté
      final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
      await authNotifier.refresh();
      
      if (authNotifier.isLoggedIn) {
        print('✅ Utilisateur connecté détecté depuis OAuth');
        
        // Récupérer le callBackUrl depuis le localStorage
        final callBackUrl = await LocalStorageService.getCallBackUrl();
        
        if (callBackUrl != null && callBackUrl.isNotEmpty) {
          print('🔄 Redirection vers: $callBackUrl');
          
          // Effacer le callBackUrl
          await LocalStorageService.clearCallBackUrl();
          
          // Afficher le popup de succès
          await _showSuccessPopup();
          
          // Rediriger vers la page souhaitée
          if (mounted) {
            context.go(callBackUrl);
          }
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la vérification OAuth: $e');
    }
  }

  /// Afficher un popup de succès avec check vert
  Future<void> _showSuccessPopup() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Fermer automatiquement après 2 secondes
        Future.delayed(Duration(seconds: 2), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône de succès avec animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),
                // Titre
                Text(
                  'Connexion réussie !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                // Message
                Text(
                  'Vous allez être redirigé...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    try {
      _titleController.dispose();
      _modulesController.dispose();
      _bannerController.dispose();
    } catch (e) {
      print('Erreur lors du dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return 
    // buildAnimatedScreen(
      Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: const CustomAppBar(),
        ),
        body: Consumer2<TranslationService, SettingsService>(
          builder: (context, translationService, settingsService, child) {
            // Vérifier que les services sont disponibles
            if (translationService == null || settingsService == null) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  
                  // Hero Section avec titre - Animation échelonnée
                  _buildHeroSection(isMobile, translationService),
                  
                  const SizedBox(height: 40),
                  
                  // Modules Grid - Animation échelonnée
                  _buildModulesGrid(isMobile, translationService),
                  
                  const SizedBox(height: 32),
                  
                  // Bannière promotionnelle avec animation Fade + Scale
                  FadeScaleTransition(
                    animation: _bannerController,
                    child: const PremiumBanner(),
                  ),
                  
                  const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildHeroSection(bool isMobile, TranslationService translationService) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24.0 : 48.0),
      child: Column(
        children: [
          // Titre avec animation Fade + Scale
          FadeTransition(
            opacity: _titleFadeAnimation,
            child: ScaleTransition(
              scale: _titleScaleAnimation,
              child: _buildConcatenatedTitle(
                translationService,
                isMobile,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construire le titre en concaténant plusieurs clés de traduction
  /// avec IKEA en dur avec le style existant (orange)
  Widget _buildConcatenatedTitle(TranslationService translationService, bool isMobile) {
    final baseStyle = TextStyle(
      fontSize: isMobile ? 40 : 48,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      height: 1.3,
      letterSpacing: -0.5,
    );
    
    final ikeaStyle = TextStyle(
      fontSize: isMobile ? 40 : 48,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFF59E0B), // Orange
      height: 1.3,
      letterSpacing: -0.5,
    );
    
    List<InlineSpan> spans = [];
    
    // 1. "LOGINREQUIRED01": "Comparez les prix"
    spans.add(TextSpan(
      text: translationService.translateFromBackend('LOGINREQUIRED01'),
      style: baseStyle,
    ));
    
    // 2. Espace
    spans.add(const TextSpan(text: ' '));
    
    // 3. "IKEA" en dur avec style orange
    spans.add(TextSpan(
      text: 'IKEA',
      style: ikeaStyle,
    ));
    
    // 4. Espace
    spans.add(const TextSpan(text: ' '));
    
    // 5. "FRONTPAGE_Msg78": "dans plusieurs pays"
    spans.add(TextSpan(
      text: translationService.translateFromBackend('FRONTPAGE_Msg78'),
      style: baseStyle,
    ));
    
    // 6. Espace
    spans.add(const TextSpan(text: ' '));
    
    // 7. "FRONTPAGE_Msg79": "en un clic"
    spans.add(TextSpan(
      text: translationService.translateFromBackend('FRONTPAGE_Msg79'),
      style: baseStyle,
    ));
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  Widget _buildStyledTitle(String text, bool isMobile) {
    List<InlineSpan> spans = [];
    
    // Chercher "IKEA" et "pays" (ou "países") dans le texte
    RegExp ikeaRegex = RegExp(r'\bIKEA\b', caseSensitive: false);
    RegExp paysRegex = RegExp(r'\bpays\b|\bpaíses\b', caseSensitive: false);
    
    // Combiner les deux regex pour traiter dans l'ordre
    List<RegExpMatch> allMatches = [
      ...ikeaRegex.allMatches(text),
      ...paysRegex.allMatches(text),
    ];
    
    // Trier par position dans le texte
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    
    int lastEnd = 0;
    
    for (RegExpMatch match in allMatches) {
      // Ajouter le texte avant le match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: isMobile ? 40 : 48,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ));
      }
      
      // Vérifier si c'est IKEA ou pays
      if (ikeaRegex.hasMatch(match.group(0)!)) {
        // Ajouter IKEA en orange et italique
        spans.add(TextSpan(
          text: match.group(0)!,
          style: TextStyle(
            fontSize: isMobile ? 40 : 48,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFF59E0B), // Orange
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ));
      } else if (paysRegex.hasMatch(match.group(0)!)) {
        // Ajouter "pays" normal (sans icône)
        spans.add(TextSpan(
          text: match.group(0)!,
          style: TextStyle(
            fontSize: isMobile ? 40 : 48,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ));
      }
      
      lastEnd = match.end;
    }
    
    // Ajouter le texte restant
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontSize: isMobile ? 40 : 48,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          height: 1.3,
          letterSpacing: -0.5,
        ),
      ));
    }
    
    // Si aucun match trouvé, retourner le texte normal
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: TextStyle(
          fontSize: isMobile ? 40 : 48,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          height: 1.3,
          letterSpacing: -0.5,
        ),
      ));
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  Widget _buildModulesGrid(bool isMobile, TranslationService translationService) {
    final modules = [
      {
        'title': translationService.translateFromBackend('HOME_MODULE_SEARCH'),
        'icon': Icons.search,
        'color': const Color(0xFF3B82F6), // Bleu
        'route': '/product-code',
        'delay': 0, // Pas de délai
      },
      {
        'title': translationService.translateFromBackend('HOME_MODULE_SCANNER'),
        'icon': Icons.qr_code_scanner,
        'color': const Color(0xFFF59E0B), // Orange/Jaune
        'route': '/scanner',
        'delay': 150, // 150ms de délai
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 32.0),
      child: Row(
        children: modules.asMap().entries.map((entry) {
          final index = entry.key;
          final module = entry.value;
          
          final isLast = index == modules.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 12.0,
                right: isLast ? 0 : 12.0,
              ),
              child: _buildAnimatedModuleCard(
                title: module['title'] as String,
                icon: module['icon'] as IconData,
                color: module['color'] as Color,
                route: module['route'] as String,
                isMobile: isMobile,
                index: index,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  /// Module avec animation slide + fade
  Widget _buildAnimatedModuleCard({
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required bool isMobile,
    required int index,
  }) {
    // Animation slide depuis la gauche/droite selon l'index
    final slideAnimation = Tween<Offset>(
      begin: Offset(index == 0 ? -1.0 : 1.0, 0.0), // Gauche pour le 1er, droite pour le 2ème
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _modulesController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    // Animation fade
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _modulesController,
        curve: Curves.easeIn,
      ),
    );
    
    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: _buildModuleCard(
          title: title,
          icon: icon,
          color: color,
          route: route,
          isMobile: isMobile,
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required bool isMobile,
  }) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, action) {
        // Pour le scanner, retourner le modal directement
        if (route == '/scanner') {
          return const QrScannerModal();
        }
        // Pour les autres, naviguer
        Future.delayed(Duration.zero, () {
          if (context.mounted) {
            context.go(route);
          }
        });
        return const SizedBox(); // Placeholder
      },
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      closedColor: color,
      closedBuilder: (context, action) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween<double>(begin: 1.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                height: isMobile ? 180 : 200,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: isMobile ? 120 : 140,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        );
      },
      onClosed: (data) {
        // Action après fermeture si nécessaire
      },
    );
  }

}