import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import '../services/auth_notifier.dart';
import '../services/translation_service.dart';
import '../widgets/terms_of_use_modal.dart';
import '../widgets/privacy_policy_modal.dart';
// OAuthHandler supprimé - utilisation directe des URLs SNAL
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
// Import conditionnel pour dart:html (Web uniquement)
import '../utils/web_utils.dart';
import 'package:animations/animations.dart';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  final String? callBackUrl;
  final bool? fromAuthError; // Paramètre pour indiquer qu'on vient d'une erreur d'authentification

  const LoginScreen({Key? key, this.callBackUrl, this.fromAuthError}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _awaitingCode = false;
  bool _showMailModal = false;
  String _errorMessage = '';
  // Validation e-mail en temps réel
  bool _isEmailValid = false;
  String _emailValidationMessage = '';
  bool _showEmailError = false;
  final FocusNode _emailFocusNode = FocusNode();
  // ✨ ANIMATIONS - Style "Elegant Entry" (6ème style de l'app)
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _buttonsController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<Offset> _formSlideAnimation;
  late Animation<double> _formFadeAnimation;
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    // Sauvegarder le callBackUrl dès l'initialisation si présent
    if (widget.callBackUrl != null && widget.callBackUrl!.isNotEmpty) {
      LocalStorageService.saveCallBackUrl(widget.callBackUrl!);
      print('💾 CallBackUrl sauvegardé dans initState: ${widget.callBackUrl}');
    }
    
    // ✨ Initialiser les animations
    _initializeAnimations();
    
    // Vérifier périodiquement si l'utilisateur est connecté (retour OAuth)
    _startOAuthCheckTimer();

    // Ecouter le focus pour la validation au blur
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && !_isLoading) {
        final text = _emailController.text.trim();
        final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
        if (mounted) {
          setState(() {
            _isEmailValid = isValid || text.isEmpty;
            _showEmailError = text.isNotEmpty && !isValid;
            _emailValidationMessage = _showEmailError ? 'Adresse email invalide' : '';
          });
        }
      }
    });
  }

  void _onEmailChanged(String value) {
    final String trimmed = value.trim();
    // Regex simple et robuste pour e-mail
    final bool isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
    setState(() {
      // Considérer l'état vide comme neutre (pas d'erreur)
      _isEmailValid = isValid || trimmed.isEmpty;
      // Ne pas afficher d'erreur en cours de frappe (sera affiché au blur ou submit)
      if (trimmed.isEmpty) {
        _showEmailError = false;
        _emailValidationMessage = '';
      }
    });
  }
  
  /// ✨ Initialiser les animations (Style "Elegant Entry")
  void _initializeAnimations() {
    try {
      _animationsInitialized = true;
      
      // Logo : Scale + Rotation légère
      _logoController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );
      
      _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
      );
      
      _logoRotationAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
      );
      
      // Formulaire : Slide from bottom
      _formController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      _formSlideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));
      
      _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _formController, curve: Curves.easeIn),
      );
      
      // Boutons sociaux : Controller pour stagger
      _buttonsController = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      print('✅ Animations Login initialisées (style Elegant Entry)');
      
      // Démarrer les animations en séquence
      Future.delayed(Duration.zero, () {
        if (mounted && _animationsInitialized) {
          _logoController.forward();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _formController.forward();
          });
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _buttonsController.forward();
          });
        }
      });
    } catch (e) {
      print('❌ Erreur initialisation animations login: $e');
      _animationsInitialized = false;
    }
  }
  
  /// Timer pour vérifier si l'utilisateur s'est connecté via OAuth dans une autre fenêtre
  void _startOAuthCheckTimer() {
    // Vérifier toutes les 2 secondes si l'utilisateur est connecté
    Future.delayed(Duration(seconds: 2), () async {
      if (!mounted) return;
      
      try {
        final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
        await authNotifier.refresh();
        
        if (authNotifier.isLoggedIn) {
          print('✅ OAuth détecté - Utilisateur connecté');
          
          // Récupérer le callBackUrl
          final callBackUrl = await LocalStorageService.getCallBackUrl() ?? widget.callBackUrl ?? '/wishlist';
          await LocalStorageService.clearCallBackUrl();
          
          // Afficher popup et rediriger
          if (mounted) {
            await _showSuccessPopup();
            context.go(callBackUrl);
          }
        } else {
          // Continuer à vérifier
          if (mounted) {
            _startOAuthCheckTimer();
          }
        }
      } catch (e) {
        print('⚠️ Erreur vérification OAuth: $e');
        if (mounted) {
          _startOAuthCheckTimer();
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    // Dispose des animations
    try {
      if (_animationsInitialized) {
        _logoController.dispose();
        _formController.dispose();
        _buttonsController.dispose();
      }
    } catch (e) {
      print('❌ Erreur dispose animations login: $e');
    }
    super.dispose();
  }

  /// Connexion avec email (étape 1: demande du code)
  Future<void> _loginWithEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer votre adresse email';
        _showEmailError = false;
        _emailValidationMessage = '';
      });
      return;
    }
    final bool emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailValid) {
      setState(() {
        _showEmailError = true;
        _emailValidationMessage = 'Adresse email invalide';
        _errorMessage = '';
      });
      return; // ❌ Ne pas passer à la suite ni ouvrir le modal
    }

    // ✅ Réinitialiser les erreurs avant de continuer
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showEmailError = false;
      _emailValidationMessage = '';
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      if (!_awaitingCode) {
        // Étape 1 : demande du code
        // ✅ Récupérer le callBackUrl et le sauvegarder
        final callBackUrl = widget.callBackUrl ?? '/wishlist';
        await LocalStorageService.saveCallBackUrl(callBackUrl);
        print('💾 CallBackUrl sauvegardé avant demande de code: $callBackUrl');
        
        // ✅ MÊME LOGIQUE QUE SNAL : Créer un profil avec des identifiants vides
        final existingProfile = await LocalStorageService.getProfile();
        if (existingProfile == null || existingProfile['sPaysLangue'] == null || existingProfile['sPaysLangue']!.isEmpty) {
          print('⚠️ Pas de profil valide, création d\'un profil avec identifiants vides (comme Jirig)...');
          
          // Récupérer le pays sélectionné depuis les settings
          final settingsService = SettingsService();
          final selectedCountry = await settingsService.getSelectedCountry();
          final sPaysLangue = selectedCountry?.sPaysLangue ?? '';
          final sPaysFav = selectedCountry?.sPays ?? '';
          
          // ✅ Créer un profil avec des identifiants par défaut (comme SNAL)
          // SNAL créera les vrais iProfile et iBasket lors de la validation du code
          await LocalStorageService.saveProfile({
            'iProfile': '0', // Utiliser '0' comme valeur par défaut
            'iBasket': '0',  // Utiliser '0' comme valeur par défaut
            'sPaysLangue': sPaysLangue,
            'sPaysFav': sPaysFav,
          });
          print('✅ Profil créé avec identifiants vides (comme Jirig): sPaysLangue: $sPaysLangue et sPaysFav: $sPaysFav');
        }
        
        final response = await apiService.login(_emailController.text.trim());
        
        print('📧 Code envoyé à ${_emailController.text}');

        setState(() {
          _awaitingCode = true;
          _showMailModal = true;
        });

        // Attendre que le setState soit terminé avant d'afficher le modal
        await Future.delayed(Duration(milliseconds: 100));
        if (mounted) {
          _openMailModal();
        }
      } else {
        // Étape 2 : validation du code
        if (_codeController.text.trim().isEmpty) {
          setState(() {
            _errorMessage = 'Veuillez entrer le code reçu par email';
          });
          return;
        }

        final response = await apiService.login(
          _emailController.text.trim(),
          code: _codeController.text.trim(),
        );

        // ✅ VÉRIFIER LA RÉPONSE DE L'API AVANT DE REDIRIGER
        // Vérifier si la réponse indique un succès (status == 'OK' ou success == true)
        final isSuccess = response != null && 
                         (response['status'] == 'OK' || response['success'] == true);
        
        if (!isSuccess) {
          // Le code est invalide ou la connexion a échoué
          setState(() {
            _isLoading = false;
            _errorMessage = response?['message'] ?? 
                           response?['error'] ?? 
                           'Code invalide. Veuillez vérifier le code reçu par email et réessayer.';
          });
          print('❌ Code invalide ou connexion échouée: ${response?['message'] ?? response?['error']}');
          print('❌ Réponse complète: $response');
          return;
        }

        print('✅ Connexion réussie - Code validé');

        // Rediriger vers la page callback ou la page d'accueil (comme SNAL)
        if (mounted) {
          // Récupérer callBackUrl depuis l'URL ou localStorage (comme SNAL)
          String? callBackUrl = widget.callBackUrl;

          // Si pas de callBackUrl dans l'URL, vérifier localStorage
          if (callBackUrl == null || callBackUrl.isEmpty) {
            callBackUrl = await LocalStorageService.getCallBackUrl();
          }

          // Par défaut, rediriger vers la wishlist (comme SNAL qui va vers la page principale)
          if (callBackUrl == null || callBackUrl.isEmpty) {
            callBackUrl = '/wishlist';
          }

          // Décoder l'URL si elle est encodée (comme SNAL)
          if (callBackUrl.startsWith('%2F')) {
            callBackUrl = Uri.decodeComponent(callBackUrl);
          }

          print('🔄 Redirection vers: $callBackUrl');

          // Effacer le callBackUrl après utilisation (comme SNAL)
          await LocalStorageService.clearCallBackUrl();

          // Afficher le popup de succès avant la redirection
          await _showSuccessPopup();

          // Notifier l'AuthNotifier de la connexion
          if (mounted) {
            final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
            await authNotifier.onLogin();
          }

          // Redirection après le popup
          if (mounted) {
            context.go(callBackUrl);
          }
        }
      }
    } catch (e) {
      print('❌ Erreur de connexion: $e');
      String errorMsg = 'Erreur lors de la connexion. Veuillez réessayer.';
      
      // ✅ Extraire le message d'erreur de la réponse si disponible
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          errorMsg = errorData['message'] ?? 
                    errorData['error'] ?? 
                    'Code invalide ou erreur de connexion. Veuillez vérifier le code et réessayer.';
        }
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Connexion avec Google - Basée sur SNAL google.get.ts
  Future<void> _loginWithGoogle() async {
    print('🔐 Connexion avec Google');
    try {
      // Sauvegarder le callBackUrl pour le récupérer après OAuth
      final callBackUrl = widget.callBackUrl ?? '/wishlist';
      await LocalStorageService.saveCallBackUrl(callBackUrl);
      
      // URL de connexion Google basée sur SNAL (directement)
      String authUrl = 'https://jirig.be/api/auth/google';

      print('🌐 Redirection vers Google OAuth: $authUrl');
      print('📝 Note: Après la connexion sur Jirig, revenez à cette application');

      // Ouvrir directement l'URL SNAL
      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      
      // Afficher un message à l'utilisateur
      setState(() {
        _errorMessage = 'Après la connexion sur Jirig, revenez à cette application';
      });
      
    } catch (e) {
      print('❌ Erreur connexion Google: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la connexion avec Google';
      });
    }
  }

  /// Connexion avec Facebook - Basée sur SNAL facebook.get.ts
  Future<void> _loginWithFacebook() async {
    print('🔐 Connexion avec Facebook');
    try {
      // Sauvegarder le callBackUrl pour le récupérer après OAuth
      final callBackUrl = widget.callBackUrl ?? '/wishlist';
      await LocalStorageService.saveCallBackUrl(callBackUrl);
      
      // URL de connexion Facebook basée sur SNAL (directement)
      String authUrl = 'https://jirig.be/api/auth/facebook';

      print('🌐 Redirection vers Facebook OAuth: $authUrl');
      print('📝 Note: Après la connexion sur SNAL, revenez à cette application');

      // Ouvrir directement l'URL SNAL
      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      
      // Afficher un message à l'utilisateur
      setState(() {
        _errorMessage = 'Après la connexion sur SNAL, revenez à cette application';
      });
      
    } catch (e) {
      print('❌ Erreur connexion Facebook: $e');
      setState(() {
        _errorMessage = 'Erreur lors de la connexion avec Facebook';
      });
    }
  }

  void _openMailModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey[50]!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Icône email avec animation
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0051BA).withOpacity(0.1),
                        Color(0xFF0051BA).withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFF0051BA).withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 40,
                    color: Color(0xFF0051BA),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Titre stylisé
                Text(
                  '📧 Code envoyé !',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Message principal avec email en surbrillance
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF0051BA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF0051BA).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Nous avons envoyé un code de connexion à',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF0051BA),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF0051BA).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _emailController.text.trim(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Instructions
                Text(
                  'Ouvrez votre boîte mail et entrez le code reçu :',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Boutons avec icônes et animations
                _buildMailButton(
                  'Gmail',
                  'https://mail.google.com/mail/u/0/#inbox',
                  Colors.red[600]!,
                  Icons.mail_outline,
                ),
                const SizedBox(height: 12),
                _buildMailButton(
                  'Outlook',
                  'https://outlook.office.com/mail/',
                  Colors.blue[600]!,
                  Icons.alternate_email,
                ),
                const SizedBox(height: 12),
                _buildMailButton(
                  'Yahoo Mail',
                  'https://mail.yahoo.com/',
                  Colors.purple[600]!,
                  Icons.email_outlined,
                ),
                const SizedBox(height: 24),
                
                // Bouton de fermeture stylisé
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      "J'ai reçu le code",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10b981), // Vert émeraude
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: Color(0xFF10b981).withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Widget pour créer un bouton de mail stylisé
  Widget _buildMailButton(String label, String url, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: color.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _animationsInitialized
            ? TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final safeOpacity = value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, -20 * (1 - value)), // Descend depuis le haut
                    child: Opacity(
                      opacity: safeOpacity,
                      child: child,
                    ),
                  );
                },
              child: AppBar(
                backgroundColor: const Color(0xFF0051BA), // Bleu Jirig principal
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () {
                  // Retourner à la page précédente
                  if (kIsWeb) {
                    try {
                      WebUtils.navigateBack();
                    } catch (e) {
                      // Fallback pour Android/iOS ou si l'historique est vide
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // ✅ Rediriger vers wishlist au lieu de splash
                        context.go('/wishlist');
                      }
                    }
                  } else {
                    // Mobile: utiliser la navigation Flutter
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      // ✅ Rediriger vers wishlist au lieu de splash
                      context.go('/wishlist');
                    }
                  }
                },
      ),
                ),
              )
          : AppBar(
              backgroundColor: const Color(0xFF0051BA), // Bleu Jirig principal
              elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () {
                    // Retourner à la page précédente
                    if (kIsWeb) {
                      try {
                        WebUtils.navigateBack();
                      } catch (e) {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          // ✅ Rediriger vers wishlist au lieu de splash
                          context.go('/wishlist');
                        }
                      }
                    } else {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        // ✅ Rediriger vers wishlist au lieu de splash
                        context.go('/wishlist');
                      }
                    }
                  },
                      ),
                    ),
                  ),
      body: SafeArea(
        child: Column(
          children: [
            // Contenu principal
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      // Partie gauche - Image/Visuel (masquée sur mobile et tablette)
                      if (isDesktop)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0051BA),
                              Color(0xFF003D82),
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Motif de fond (cercles décoratifs)
                            Positioned(
                              top: 40,
                              left: 40,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 160,
                              right: 80,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 80,
                              left: 80,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 160,
                              right: 40,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            // Contenu central
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(48.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Bienvenue sur Jirig',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 36 : 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: isDesktop ? 24 : 16),
                                      Text(
                                        'Connectez-vous et explorez toutes les fonctionnalités de notre plateforme',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 20 : 16,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    SizedBox(height: 32),
                                    // Animation de points
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildBouncingDot(0),
                                        SizedBox(width: 8),
                                        _buildBouncingDot(100),
                                        SizedBox(width: 8),
                                        _buildBouncingDot(200),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Dégradé décoratif en bas
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 128,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0),
                                      Colors.black.withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Partie droite - Formulaire de connexion
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: EdgeInsets.all(
                          isMobile ? 16 : (isTablet ? 32 : 48)
                        ),
                        child: Column(
                          children: [
                            // Conteneur du formulaire
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: isMobile ? double.infinity : 500
                              ),
                              padding: EdgeInsets.all(
                                isMobile ? 20 : (isTablet ? 28 : 32)
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 16 : 24
                                ),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: isMobile ? 15 : 20,
                                    offset: Offset(0, isMobile ? 4 : 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Logo et titre avec animation
                                  if (_animationsInitialized)
                                    ScaleTransition(
                                      scale: _logoScaleAnimation,
                                      child: AnimatedBuilder(
                                        animation: _logoRotationAnimation,
                                        builder: (context, child) {
                                          return Transform.rotate(
                                            angle: _logoRotationAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: isMobile ? 64 : 80,
                                          height: isMobile ? 64 : 80,
                                          decoration: BoxDecoration(
                                            color: Color(0xFF0051BA).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Image.asset(
                                              'assets/img/logo_mobile.png',
                                              width: isMobile ? 40 : 50,
                                              height: isMobile ? 40 : 50,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.account_circle,
                                                  size: isMobile ? 40 : 50,
                                                  color: Color(0xFF0051BA),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                  Container(
                                    width: isMobile ? 64 : 80,
                                    height: isMobile ? 64 : 80,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF0051BA).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/img/logo_mobile.png',
                                        width: isMobile ? 40 : 50,
                                        height: isMobile ? 40 : 50,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.account_circle,
                                            size: isMobile ? 40 : 50,
                                            color: Color(0xFF0051BA),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 12 : 16),
                                  // Titre avec animation
                                  if (_animationsInitialized)
                                    FadeTransition(
                                      opacity: _formFadeAnimation,
                                      child: SlideTransition(
                                        position: _formSlideAnimation,
                                        child: Column(
                                          children: [
                                  Text(
                                    'Connexion',
                                    style: TextStyle(
                                      fontSize: isMobile ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 6 : 8),
                                  Text(
                                    'Accédez à votre compte',
                                    style: TextStyle(
                                      fontSize: isMobile ? 13 : 15,
                                      color: Colors.grey[600],
                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        Text(
                                          'Connexion',
                                          style: TextStyle(
                                            fontSize: isMobile ? 20 : 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[900],
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 6 : 8),
                                        Text(
                                          'Accédez à votre compte',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 15,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                  ),
                                  SizedBox(height: isMobile ? 24 : 32),
                                  // Formulaire avec animation
                                  if (!_awaitingCode)
                                    // Champ email
                                    _animationsInitialized
                                    ? FadeTransition(
                                        opacity: _formFadeAnimation,
                                        child: SlideTransition(
                                          position: _formSlideAnimation,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Adresse email',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 13 : 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              SizedBox(height: isMobile ? 6 : 8                                                ),
                                              TextField(
                                                controller: _emailController,
                                                keyboardType: TextInputType.emailAddress,
                                                onChanged: _onEmailChanged,
                                                focusNode: _emailFocusNode,
                                                decoration: InputDecoration(
                                                  hintText: 'votre@email.com',
                                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                                  prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide(color: const Color(0xFF0051BA), width: 2),
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: isMobile ? 12 : 16, 
                                                    vertical: isMobile ? 12 : 16
                                                  ),
                                                  errorText: _showEmailError ? _emailValidationMessage : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ), // Ferme SlideTransition
                                      ) // Ferme FadeTransition
                                    : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Adresse email',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 6 : 8),
                                        TextField(
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                          onChanged: _onEmailChanged,
                                          focusNode: _emailFocusNode,
                                          decoration: InputDecoration(
                                            hintText: 'votre@email.com',
                                            hintStyle: TextStyle(color: Colors.grey[400]),
                                            prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: const Color(0xFF0051BA), width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 12 : 16, 
                                              vertical: isMobile ? 12 : 16
                                            ),
                                            errorText: _showEmailError ? _emailValidationMessage : null,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    // Champ code
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code de vérification',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 6 : 8),
                                        TextField(
                                          controller: _codeController,
                                          decoration: InputDecoration(
                                            hintText: 'Entrez le code reçu par e-mail',
                                            hintStyle: TextStyle(color: Colors.grey[400]),
                                            prefixIcon: Icon(Icons.pin_outlined, color: Colors.grey[600]),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey[300]!),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Color(0xFF0051BA), width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 12 : 16, 
                                              vertical: isMobile ? 12 : 16
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  SizedBox(height: isMobile ? 16 : 24),
                                  // Message d'erreur
                                  if (_errorMessage.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      margin: EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: TextStyle(
                                                color: Colors.red[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Bouton de soumission
                                  SizedBox(
                                    width: double.infinity,
                                    height: isMobile ? 44 : 48,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _loginWithEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF0051BA),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text(
                                                  _awaitingCode ? 'Connexion...' : 'Envoi du code...',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.login, size: isMobile ? 18 : 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  _awaitingCode ? 'Valider le code' : 'Envoi du code',
                                                  style: TextStyle(
                                                    fontSize: isMobile ? 14 : 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: isMobile ? 24 : 32),
                                  // Séparateur
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey[300])),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                                        child: Text(
                                          'Ou continuer avec',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey[300])),
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 16 : 24),
                                  // Boutons de connexion sociale avec animation
                                  Column(
                                    children: [
                                      // Google avec animation
                                      _buildSocialButton(
                                        index: 0,
                                        isMobile: isMobile,
                                          onPressed: _loginWithGoogle,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                            // Logo Google
                                            Image.asset(
                                              'assets/images/google.png',
                                                width: 20,
                                                height: 20,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(Icons.account_circle, size: 20, color: Colors.grey);
                                              },
                                              ),
                                              SizedBox(width: isMobile ? 8 : 12),
                                              Flexible(
                                                child: Text(
                                                  'Continuer avec Google',
                                                  style: TextStyle(
                                                    fontSize: isMobile ? 14 : 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      // Facebook avec animation
                                      _buildSocialButton(
                                        index: 1,
                                        isMobile: isMobile,
                                          onPressed: _loginWithFacebook,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                            // Logo Facebook
                                              Image.asset(
                                              'assets/images/facebook.png',
                                                width: 20,
                                                height: 20,
                                                errorBuilder: (context, error, stackTrace) {
                                                return Icon(Icons.facebook, color: Colors.blue, size: 20);
                                                },
                                              ),
                                              SizedBox(width: isMobile ? 8 : 12),
                                              Flexible(
                                                child: Text(
                                                  'Continuer avec Facebook',
                                                  style: TextStyle(
                                                    fontSize: isMobile ? 14 : 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 16 : 24),
                                  // Footer text avec animation
                                  if (_animationsInitialized)
                                    FadeTransition(
                                      opacity: _buttonsController,
                                      child: Column(
                                        children: [
                                  Text(
                                    'En vous connectant, vous acceptez nos',
                                    style: TextStyle(
                                      fontSize: isMobile ? 10 : 12,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      Consumer<TranslationService>(
                                        builder: (context, translationService, child) {
                                          return GestureDetector(
                                            onTap: () {
                                              TermsOfUseModal.show(context, translationService: translationService);
                                            },
                                            child: Text(
                                              'Conditions d\'utilisation',
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12,
                                                color: Color(0xFF0051BA),
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        'et notre',
                                        style: TextStyle(
                                          fontSize: isMobile ? 10 : 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Consumer<TranslationService>(
                                        builder: (context, translationService, child) {
                                          return GestureDetector(
                                            onTap: () {
                                              PrivacyPolicyModal.show(context, translationService: translationService);
                                            },
                                            child: Text(
                                              'Politique de confidentialité',
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12,
                                                color: Color(0xFF0051BA),
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        Text(
                                          'En vous connectant, vous acceptez nos',
                                          style: TextStyle(
                                            fontSize: isMobile ? 10 : 12,
                                            color: Colors.grey[600],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 4),
                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            Consumer<TranslationService>(
                                              builder: (context, translationService, child) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    TermsOfUseModal.show(context, translationService: translationService);
                                                  },
                                                  child: Text(
                                                    'Conditions d\'utilisation',
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 10 : 12,
                                                      color: Color(0xFF0051BA),
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            Text(
                                              'et notre',
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Consumer<TranslationService>(
                                              builder: (context, translationService, child) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    PrivacyPolicyModal.show(context, translationService: translationService);
                                                  },
                                                  child: Text(
                                                    'Politique de confidentialité',
                                                    style: TextStyle(
                                                      fontSize: isMobile ? 10 : 12,
                                                      color: Color(0xFF0051BA),
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                          ],
                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
  
  /// ✨ Construire un bouton social avec animation
  Widget _buildSocialButton({
    required int index,
    required bool isMobile,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    if (!_animationsInitialized) {
      return SizedBox(
        width: double.infinity,
        height: isMobile ? 44 : 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      );
    }
    
    // ✨ Animation : Staggered fade + slide depuis le bas
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 150)), // Délai progressif
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final safeOpacity = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)), // Slide depuis le bas
          child: Opacity(
            opacity: safeOpacity,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: isMobile ? 44 : 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Widget pour les points animés
  Widget _buildBouncingDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -8 * (0.5 - (value - 0.5).abs()) * 2),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
        );
      },
      onEnd: () {
        // Relancer l'animation
        if (mounted) {
          Future.delayed(Duration(milliseconds: delay), () {
            if (mounted) setState(() {});
          });
        }
      },
    );
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
  
}