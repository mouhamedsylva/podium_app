import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:convert'; // Gardé pour jsonEncode au cas où, mais l'appel se fait via Dio
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../services/settings_service.dart';
import '../services/auth_notifier.dart';
import '../services/translation_service.dart';
import '../config/api_config.dart';
import '../widgets/terms_of_use_modal.dart';
import '../widgets/privacy_policy_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_utils.dart';
import 'package:animations/animations.dart';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
// import 'package:loading_animation_widget/loading_animation_widget.dart';

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
  bool _isSocialLoading = false; // ✅ Nouvel état pour le chargement social
  bool _awaitingCode = false;
  String _errorMessage = '';
  // Validation e-mail en temps réel
  bool _isEmailValid = false;
  String _emailValidationMessage = '';
  bool _showEmailError = false;
  final FocusNode _emailFocusNode = FocusNode();
  bool _oauthCheckActive = false; // Flag pour indiquer si le timer OAuth est actif
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
    
    // ❌ NE PAS démarrer le timer OAuth automatiquement
    // Le timer sera démarré uniquement quand l'utilisateur clique sur un bouton OAuth

    // Ecouter le focus pour la validation au blur
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && !_isLoading) {
        final text = _emailController.text.trim();
        final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
        final translationService =
            Provider.of<TranslationService>(context, listen: false);
        if (mounted) {
          setState(() {
            _isEmailValid = isValid || text.isEmpty;
            _showEmailError = text.isNotEmpty && !isValid;
            _emailValidationMessage = _showEmailError
                ? translationService.translate('LOGIN_ERROR_INVALID_EMAIL')
                : '';
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
  /// Ne démarre que si l'utilisateur a cliqué sur un bouton OAuth
  void _startOAuthCheckTimer() {
    if (!_oauthCheckActive) {
      _oauthCheckActive = true;
      print('🔄 Démarrage du timer OAuth');
    }
    
    // Vérifier toutes les 2 secondes si l'utilisateur est connecté
    Future.delayed(Duration(seconds: 2), () async {
      if (!mounted || !_oauthCheckActive) return;
      
      try {
        final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
        await authNotifier.refresh();
        
        if (authNotifier.isLoggedIn) {
          print('✅ OAuth détecté - Utilisateur connecté');
          
          // Arrêter le timer
          _oauthCheckActive = false;
          
          // Récupérer le callBackUrl
          final callBackUrl = await LocalStorageService.getCallBackUrl() ?? widget.callBackUrl ?? '/wishlist';
          await LocalStorageService.clearCallBackUrl();
          
          // Afficher popup et rediriger
          if (mounted) {
            await _showSuccessPopup();
            context.go(callBackUrl);
          }
        } else {
          // Continuer à vérifier seulement si le timer est toujours actif
          if (mounted && _oauthCheckActive) {
            _startOAuthCheckTimer();
          }
        }
      } catch (e) {
        print('⚠️ Erreur vérification OAuth: $e');
        if (mounted && _oauthCheckActive) {
          _startOAuthCheckTimer();
        }
      }
    });
  }

  @override
  void dispose() {
    // Arrêter le timer OAuth si actif
    _oauthCheckActive = false;
    
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
    final translationService =
        Provider.of<TranslationService>(context, listen: false);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage =
            translationService.translate('LOGIN_ERROR_EMPTY_EMAIL');
        _showEmailError = false;
        _emailValidationMessage = '';
      });
      return;
    }
    final bool emailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailValid) {
      setState(() {
        _showEmailError = true;
        _emailValidationMessage =
            translationService.translate('LOGIN_ERROR_INVALID_EMAIL');
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
        
        final Map<String, dynamic> response = await apiService.login(_emailController.text.trim());
        print('📧 Code envoyé à ${_emailController.text}');

        // ⚠️ AVERTISSEMENT : Le code de vérification a été envoyé par email
        // L'utilisateur doit maintenant vérifier sa boîte Gmail (ou sa boîte mail) pour obtenir le code
        // Le code doit être entré manuellement dans le champ de code qui apparaîtra à l'écran
        // Ce processus est nécessaire pour sécuriser la connexion avec email + code

        setState(() {
          _awaitingCode = true;
          _codeController.clear(); // ✅ Ne pas pré-remplir le champ - l'utilisateur doit entrer le code manuellement
        });

        // ✅ Modal du code supprimé - l'utilisateur doit entrer le code manuellement
      } else {
        // Étape 2 : validation du code
        if (_codeController.text.trim().isEmpty) {
          setState(() {
            _errorMessage =
                translationService.translate('LOGIN_ERROR_EMPTY_CODE');
          });
          return;
        }

        final Map<String, dynamic> response = await apiService.login(
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
                           translationService.translate('LOGIN_ERROR_INVALID_CODE');
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
      String errorMsg =
          translationService.translate('LOGIN_ERROR_GENERIC');
      
      // ✅ Extraire le message d'erreur de la réponse si disponible
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map) {
          errorMsg = errorData['message'] ?? 
                    errorData['error'] ?? 
                    translationService
                        .translate('LOGIN_ERROR_CODE_OR_CONNECTION');
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

  /// Connexion avec Google - Basée sur SNAL google.get.ts et google-mobile.get.ts
  /// - Web : Flux OAuth classique SNAL (redirection vers le site)
  /// - Android : Google Sign-In Mobile (récupération idToken et appel /api/auth/google-mobile)
  Future<void> _loginWithGoogle() async {
    print('\n${List.filled(70, '=').join()}');
    print('🔐 === DÉBUT CONNEXION GOOGLE ===');
    print('${List.filled(70, '=').join()}');
    final translationService =
        Provider.of<TranslationService>(context, listen: false);
    
    // ✅ DEBUG: Afficher la plateforme détectée
    print('🔍 DEBUG Plateforme:');
    print('   kIsWeb: $kIsWeb');
    print('   kDebugMode: $kDebugMode');
    if (!kIsWeb) {
      print('   Platform.isAndroid: ${Platform.isAndroid}');
      print('   Platform.operatingSystem: ${Platform.operatingSystem}');
      print('   Platform.isIOS: ${Platform.isIOS}');
    }
    
    // ✅ DEBUG: Afficher la configuration API
    print('🔍 DEBUG Configuration API:');
    print('   ApiConfig.baseUrl: ${ApiConfig.baseUrl}');
    print('   ApiConfig.useProductionApiOnMobile: ${ApiConfig.useProductionApiOnMobile}');
    
    try {
      // ✅ Détecter la plateforme
      if (kIsWeb) {
        // Web : Flux OAuth classique SNAL (redirection vers le site)
        print('🌐 Mode Web détecté - Redirection vers SNAL OAuth');
        print('⚠️ ATTENTION: Vous êtes dans un navigateur, la redirection vers jirig.be est NORMALE pour le flux Web OAuth');
        _startOAuthCheckTimer();
        
        // Sauvegarder le callBackUrl pour le récupérer après OAuth
        final callBackUrl = widget.callBackUrl ?? '/wishlist';
        await LocalStorageService.saveCallBackUrl(callBackUrl);

        final authUrl = 'https://jirig.be/api/auth/google';
        print('🌐 Redirection vers Google OAuth (Web): $authUrl');
        print('📝 Après la connexion sur jirig.be, revenez à cette application');

        final uri = Uri.parse(authUrl);
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );

        // Afficher un message à l'utilisateur
        setState(() {
          _errorMessage =
              translationService.translate('LOGIN_MESSAGE_RETURN_APP');
        });
        print('✅ Redirection Web vers jirig.be effectuée');
        print('${List.filled(70, '=').join()}\n');
        return; // ✅ Sortir ici pour éviter d'exécuter le code Android
      } else if (Platform.isAndroid) {
        // ✅ Android : Google Sign-In Mobile (selon documentation)
        print('📱 Mode Android détecté - Utilisation de Google Sign-In Mobile');
        print('✅ Vous êtes dans une vraie app Android, le flux Google Sign-In devrait s\'exécuter');
        setState(() {
          _isSocialLoading = true;
          _errorMessage = '';
        });

        try {
          print('📱 === ÉTAPE 1: Configuration Google Sign-In ===');
          
          // ✅ Configuration Google Sign-In selon la documentation
          // serverClientId doit être le Web Client ID complet (XXXXX-XXXXX.apps.googleusercontent.com)
          const webClientId = '116497000948-90d84akvtp9g4favfmi63ciktp5rbgfu.apps.googleusercontent.com';
          
          // ✅ VÉRIFICATION CRITIQUE: S'assurer que le webClientId est valide
          if (webClientId.isEmpty || !webClientId.endsWith('.apps.googleusercontent.com')) {
            print('❌ ERREUR: Web Client ID invalide');
            throw Exception('Web Client ID invalide. Le Web Client ID doit se terminer par .apps.googleusercontent.com');
          }
          
          print('🔑 Configuration Google Sign-In avec serverClientId: ${webClientId.substring(0, 30)}...');
          
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
            serverClientId: webClientId, // Web Client ID pour Android
          );

          // ✅ Étape 1: Récupérer l'idToken via Google Sign-In
          print('📱 === ÉTAPE 2: Récupération idToken via Google Sign-In ===');
          print('🔑 Demande de connexion Google Sign-In...');
          print('⏳ En attente de la sélection du compte Google par l\'utilisateur...');
          
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
          
          if (googleUser == null) {
            // L'utilisateur a annulé la connexion
            print('⚠️ Connexion Google annulée par l\'utilisateur');
            print('ℹ️ Pas de redirection - retour normal à l\'app');
            setState(() {
              _isSocialLoading = false;
              _errorMessage = '';
            });
            print('${List.filled(70, '=').join()}\n');
            return;
          }

          print('✅ Compte Google récupéré: ${googleUser.email}');
          print('✅ Google User ID: ${googleUser.id}');
          
          // ✅ Étape 2: Récupérer l'idToken
          print('📱 === ÉTAPE 3: Récupération idToken depuis Google ===');
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;

          if (idToken == null) {
            print('❌ ERREUR: idToken est null');
            throw Exception('idToken non disponible depuis Google Sign-In');
          }

          print('✅ idToken récupéré: ${idToken.substring(0, 20)}...');
          print('✅ idToken length: ${idToken.length}');

          // ✅ Étape 3: Appeler l'endpoint Nuxt3 /api/auth/google-mobile
          print('📱 === ÉTAPE 4: Appel API /api/auth/google-mobile ===');
          print('📡 URL complète: ${ApiConfig.baseUrl}/auth/google-mobile?id_token=...');
          print('📡 Appel à /api/auth/google-mobile...');
          
          final apiService = ApiService();
          final response = await apiService.loginWithGoogleMobile(idToken);

          print('✅ Réponse API reçue:');
          print('   Status: ${response['status']}');
          print('   Keys: ${response.keys.toList()}');

          // ✅ Étape 4: Gérer la réponse
          if (response['status'] == 'success') {
            print('✅ Connexion Google réussie');
            print('📱 === ÉTAPE 5: Traitement de la réponse ===');
            
            // Notifier l'AuthNotifier de la connexion
            print('📢 Notification de la connexion à AuthNotifier...');
            final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
            await authNotifier.onLogin();
            print('✅ AuthNotifier notifié');
            
            // Rediriger vers la page souhaitée
            String? callBackUrl = widget.callBackUrl;
            if (callBackUrl == null || callBackUrl.isEmpty) {
              callBackUrl = '/wishlist'; // Par défaut vers la wishlist
            }

            print('📱 === ÉTAPE 6: Redirection interne dans l\'app ===');
            print('🔄 Redirection interne vers: $callBackUrl');
            print('ℹ️ ATTENTION: Cette redirection est INTERNE (context.go), pas vers jirig.be');

            // Afficher le popup de succès avant la redirection
            await _showSuccessPopup();

            // Redirection après le popup
            if (mounted) {
              print('✅ Widget monté, redirection interne en cours...');
              context.go(callBackUrl);
              print('✅ Redirection interne effectuée vers: $callBackUrl');
            } else {
              print('⚠️ Widget non monté, redirection annulée');
            }
            print('${List.filled(70, '=').join()}\n');
          } else {
            print('❌ ERREUR: Status de la réponse n\'est pas "success"');
            print('   Réponse complète: $response');
            throw Exception(response['message']?.toString() ?? response['error']?.toString() ?? 'Erreur lors de la connexion Google');
          }
        } catch (e, stackTrace) {
          print('❌ ERREUR connexion Google Mobile:');
          print('   Exception: $e');
          print('   Type: ${e.runtimeType}');
          print('   StackTrace:');
          print(stackTrace);
          print('ℹ️ ATTENTION: Cette erreur ne devrait PAS causer de redirection vers jirig.be');
          
          // ✅ Vérifier si c'est une DioException avec erreur 500
          // Si la connexion réussit quand même, ne pas afficher l'erreur technique
          String errorString = '';
          if (e is DioException) {
            final statusCode = e.response?.statusCode;
            if (statusCode == 500) {
              // Erreur 500 du serveur - peut être temporaire, message user-friendly
              errorString = 'Erreur temporaire du serveur. Veuillez réessayer.';
              print('⚠️ Erreur 500 détectée - Message user-friendly affiché');
            } else if (e.response?.data is Map) {
              // Extraire le message d'erreur du backend si disponible
              final errorData = e.response!.data as Map<String, dynamic>;
              errorString = errorData['message']?.toString() ?? 
                          errorData['error']?.toString() ?? 
                          'Erreur de communication avec le serveur.';
            } else {
              errorString = 'Erreur de communication avec le serveur.';
            }
          } else {
            // Autres types d'erreurs
            errorString = e.toString();
            if (errorString.startsWith('Exception: ')) {
              errorString = errorString.substring('Exception: '.length);
            }
            // Ne pas afficher les messages techniques complets à l'utilisateur
            if (errorString.contains('DioException') || 
                errorString.contains('bad response') ||
                errorString.contains('status code')) {
              errorString = 'Erreur de communication avec le serveur.';
            }
          }
          
          if (errorString.isNotEmpty) {
            setState(() {
              _errorMessage = errorString;
            });
          }
          print('${List.filled(70, '=').join()}\n');
        } finally {
          setState(() {
            _isSocialLoading = false;
          });
        }
      } else if (Platform.isIOS) {
        // ✅ iOS : Google Sign-In Mobile (même logique que Android)
        print('📱 Mode iOS détecté - Utilisation de Google Sign-In Mobile');
        print('✅ Vous êtes dans une vraie app iOS, le flux Google Sign-In devrait s\'exécuter');
        setState(() {
          _isSocialLoading = true;
          _errorMessage = '';
        });

        try {
          print('📱 === ÉTAPE 1: Configuration Google Sign-In (iOS) ===');
          
          // ✅ Configuration Google Sign-In pour iOS
          // Utiliser l'iOS Client ID spécifique (NUXT_OAUTH_IOS_CLIENT_ID)
          const iosClientId = '116497000948-rqah223nds6mkli2p74i7s713ccd8crd.apps.googleusercontent.com';
          
          // ✅ VÉRIFICATION CRITIQUE: S'assurer que l'iosClientId est valide
          if (iosClientId.isEmpty || !iosClientId.endsWith('.apps.googleusercontent.com')) {
            print('❌ ERREUR: iOS Client ID invalide');
            throw Exception('iOS Client ID invalide. Le iOS Client ID doit se terminer par .apps.googleusercontent.com');
          }
          
          print('🔑 Configuration Google Sign-In avec iOS Client ID: ${iosClientId.substring(0, 30)}...');
          
          final GoogleSignIn googleSignIn = GoogleSignIn(
            scopes: ['email', 'profile'],
            serverClientId: iosClientId, // iOS Client ID spécifique
          );

          // ✅ Étape 1: Récupérer l'idToken via Google Sign-In
          print('📱 === ÉTAPE 2: Récupération idToken via Google Sign-In (iOS) ===');
          print('🔑 Demande de connexion Google Sign-In...');
          print('⏳ En attente de la sélection du compte Google par l\'utilisateur...');
          
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
          
          if (googleUser == null) {
            // L'utilisateur a annulé la connexion
            print('⚠️ Connexion Google annulée par l\'utilisateur');
            print('ℹ️ Pas de redirection - retour normal à l\'app');
            setState(() {
              _isSocialLoading = false;
              _errorMessage = '';
            });
            print('${List.filled(70, '=').join()}\n');
            return;
          }

          print('✅ Compte Google récupéré: ${googleUser.email}');
          print('✅ Google User ID: ${googleUser.id}');
          
          // ✅ Étape 2: Récupérer l'idToken
          print('📱 === ÉTAPE 3: Récupération idToken depuis Google (iOS) ===');
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;

          if (idToken == null) {
            print('❌ ERREUR: idToken est null');
            throw Exception('idToken non disponible depuis Google Sign-In');
          }

          print('✅ idToken récupéré: ${idToken.substring(0, 20)}...');
          print('✅ idToken length: ${idToken.length}');

          // ✅ Étape 3: Appeler l'endpoint Nuxt3 /api/auth/google-mobile
          print('📱 === ÉTAPE 4: Appel API /api/auth/google-mobile (iOS) ===');
          print('📡 URL complète: ${ApiConfig.baseUrl}/auth/google-mobile?id_token=...');
          print('📡 Appel à /api/auth/google-mobile...');
          
          final apiService = ApiService();
          final response = await apiService.loginWithGoogleMobile(idToken);

          print('✅ Réponse API reçue:');
          print('   Status: ${response['status']}');
          print('   Keys: ${response.keys.toList()}');

          // ✅ Étape 4: Gérer la réponse
          if (response['status'] == 'success') {
            print('✅ Connexion Google réussie (iOS)');
            print('📱 === ÉTAPE 5: Traitement de la réponse ===');
            
            // Notifier l'AuthNotifier de la connexion
            print('📢 Notification de la connexion à AuthNotifier...');
            final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
            await authNotifier.onLogin();
            print('✅ AuthNotifier notifié');
            
            // Rediriger vers la page souhaitée
            String? callBackUrl = widget.callBackUrl;
            if (callBackUrl == null || callBackUrl.isEmpty) {
              callBackUrl = await LocalStorageService.getCallBackUrl();
            }
            if (callBackUrl == null || callBackUrl.isEmpty) {
              callBackUrl = '/wishlist'; // Par défaut vers la wishlist
            }
            await LocalStorageService.clearCallBackUrl();

            print('📱 === ÉTAPE 6: Redirection interne dans l\'app (iOS) ===');
            print('🔄 Redirection interne vers: $callBackUrl');
            print('ℹ️ ATTENTION: Cette redirection est INTERNE (context.go), pas vers jirig.be');

            // Afficher le popup de succès avant la redirection
            await _showSuccessPopup();

            // Redirection après le popup
            if (mounted) {
              print('✅ Widget monté, redirection interne en cours...');
              context.go(callBackUrl);
              print('✅ Redirection interne effectuée vers: $callBackUrl');
            } else {
              print('⚠️ Widget non monté, redirection annulée');
            }
            print('${List.filled(70, '=').join()}\n');
          } else {
            print('❌ ERREUR: Status de la réponse n\'est pas "success"');
            print('   Réponse complète: $response');
            throw Exception(response['message']?.toString() ?? response['error']?.toString() ?? 'Erreur lors de la connexion Google');
          }
        } catch (e, stackTrace) {
          print('❌ ERREUR connexion Google Mobile (iOS):');
          print('   Exception: $e');
          print('   Type: ${e.runtimeType}');
          print('   StackTrace:');
          print(stackTrace);
          print('ℹ️ ATTENTION: Cette erreur ne devrait PAS causer de redirection vers jirig.be');
          
          // ✅ Vérifier si c'est une DioException avec erreur 500
          // Si la connexion réussit quand même, ne pas afficher l'erreur technique
          String errorString = '';
          if (e is DioException) {
            final statusCode = e.response?.statusCode;
            if (statusCode == 500) {
              // Erreur 500 du serveur - peut être temporaire, message user-friendly
              errorString = 'Erreur temporaire du serveur. Veuillez réessayer.';
              print('⚠️ Erreur 500 détectée - Message user-friendly affiché');
            } else if (e.response?.data is Map) {
              // Extraire le message d'erreur du backend si disponible
              final errorData = e.response!.data as Map<String, dynamic>;
              errorString = errorData['message']?.toString() ?? 
                          errorData['error']?.toString() ?? 
                          'Erreur de communication avec le serveur.';
            } else {
              errorString = 'Erreur de communication avec le serveur.';
            }
          } else {
            // Autres types d'erreurs
            errorString = e.toString();
            if (errorString.startsWith('Exception: ')) {
              errorString = errorString.substring('Exception: '.length);
            }
            // Ne pas afficher les messages techniques complets à l'utilisateur
            if (errorString.contains('DioException') || 
                errorString.contains('bad response') ||
                errorString.contains('status code')) {
              errorString = 'Erreur de communication avec le serveur.';
            }
          }
          
          if (errorString.isNotEmpty) {
            setState(() {
              _errorMessage = errorString;
            });
          }
          print('${List.filled(70, '=').join()}\n');
        } finally {
          setState(() {
            _isSocialLoading = false;
          });
        }
      } else {
        // Autre plateforme non supportée
        print('⚠️ Plateforme non supportée pour Google Sign-In Mobile: ${Platform.operatingSystem}');
        setState(() {
          _errorMessage =
              translationService.translate('LOGIN_ERROR_GOOGLE') + ': Plateforme non supportée';
        });
      }
    } catch (e) {
      print('❌ Erreur connexion Google: $e');
      
      // ✅ Gestion d'erreur améliorée - messages user-friendly
      String errorString = '';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 500) {
          errorString = 'Erreur temporaire du serveur. Veuillez réessayer.';
          print('⚠️ Erreur 500 détectée - Message user-friendly affiché');
        } else if (e.response?.data is Map) {
          final errorData = e.response!.data as Map<String, dynamic>;
          errorString = errorData['message']?.toString() ?? 
                      errorData['error']?.toString() ?? 
                      'Erreur de communication avec le serveur.';
        } else {
          errorString = 'Erreur de communication avec le serveur.';
        }
      } else {
        errorString = e.toString();
        if (errorString.startsWith('Exception: ')) {
          errorString = errorString.substring('Exception: '.length);
        }
        // Ne pas afficher les messages techniques complets à l'utilisateur
        if (errorString.contains('DioException') || 
            errorString.contains('bad response') ||
            errorString.contains('status code') ||
            errorString.contains('RequestOptions.validateStatus')) {
          errorString = 'Erreur de communication avec le serveur.';
        }
      }
      
      setState(() {
        _isSocialLoading = false;
        if (errorString.isNotEmpty) {
          _errorMessage = errorString;
        }
      });
    }
  }

  /// Connexion avec Apple - Implémentation mobile native (iOS uniquement)
  /// Basée sur SNAL apple-mobile.ts
  Future<void> _loginWithApple() async {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    
    // Apple Sign-In n'est disponible que sur iOS
    if (!Platform.isIOS) {
      setState(() {
        _errorMessage = translationService.translate('LOGIN_ERROR_APPLE') ?? 'Apple Sign-In n\'est disponible que sur iOS';
      });
      return;
    }
    
    setState(() {
      _isSocialLoading = true;
      _errorMessage = '';
    });

    try {
      print('\n${List.filled(70, '=').join()}');
      print('🍎 === DÉBUT CONNEXION APPLE ===');
      print('${List.filled(70, '=').join()}');
      
      // 1. Lancer la connexion avec Apple Sign-In
      print('📱 === ÉTAPE 1: Demande de connexion Apple Sign-In ===');
      print('📱 Bundle ID attendu: be.jirig.app');
      print('📱 Vérification de la disponibilité Apple Sign-In...');
      
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      print('✅ Credential Apple obtenu');
      print('   User ID: ${credential.userIdentifier}');
      print('   Email: ${credential.email ?? 'Non fourni'}');
      print('   Identity Token: ${credential.identityToken?.substring(0, 20) ?? 'null'}...');

      // 2. Vérifier que l'identityToken est disponible
      if (credential.identityToken == null || credential.identityToken!.isEmpty) {
        throw Exception('Identity token non disponible depuis Apple Sign-In');
      }

      print('📱 === ÉTAPE 2: Appel API /api/auth/apple-mobile ===');
      print('📡 URL complète: ${ApiConfig.baseUrl}/auth/apple-mobile?identity_token=...');
      
      // 3. Utiliser ApiService pour faire l'appel
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.initialize();
      
      final responseBody = await apiService.loginWithAppleMobile(credential.identityToken!);

      print('✅ Réponse API reçue:');
      print('   Status: ${responseBody['status']}');
      print('   Keys: ${responseBody.keys.toList()}');

      if (responseBody['status'] == 'success') {
        print('✅ Connexion Apple réussie');
        print('📱 === ÉTAPE 3: Traitement de la réponse ===');
        
        // Notifier l'AuthNotifier
        print('📢 Notification de la connexion à AuthNotifier...');
        final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
        await authNotifier.onLogin();
        print('✅ AuthNotifier notifié');
        
        // Gérer la redirection
        String? callBackUrl = widget.callBackUrl;
        if (callBackUrl == null || callBackUrl.isEmpty) {
          callBackUrl = await LocalStorageService.getCallBackUrl();
        }
        if (callBackUrl == null || callBackUrl.isEmpty) {
          callBackUrl = '/wishlist';
        }
        await LocalStorageService.clearCallBackUrl();

        print('📱 === ÉTAPE 4: Redirection interne dans l\'app ===');
        print('🔄 Redirection interne vers: $callBackUrl');

        if (mounted) {
          await _showSuccessPopup();
          context.go(callBackUrl);
          print('✅ Redirection interne effectuée vers: $callBackUrl');
        }
        print('${List.filled(70, '=').join()}\n');
      } else {
        throw Exception('Erreur du serveur: ${responseBody['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      print("❌ Erreur lors de la connexion Apple: $e");
      print('${List.filled(70, '=').join()}\n');
      
      String errorMessage;
      if (e is DioException && e.response?.data is Map) {
        final errorData = e.response!.data as Map<String, dynamic>;
        errorMessage = errorData['message'] ?? 'Erreur de communication avec le serveur.';
      } else if (e is SignInWithAppleAuthorizationException) {
        // Gérer les erreurs spécifiques à Apple Sign-In
        print('❌ Erreur Apple Sign-In - Code: ${e.code}, Message: ${e.message}');
        print('❌ Erreur complète: $e');
        print('❌ Type d\'erreur: ${e.runtimeType}');
        
        if (e.code == AuthorizationErrorCode.canceled) {
          print('ℹ️ Connexion Apple annulée par l\'utilisateur');
          errorMessage = ''; // Ne pas afficher d'erreur si l'utilisateur a annulé
        } else if (e.code == AuthorizationErrorCode.unknown || 
                   e.message?.contains('error 1000') == true ||
                   e.message?.contains('1000') == true ||
                   e.toString().contains('1000')) {
          // Erreur 1000 = Problème de configuration
          print('❌ Erreur 1000 détectée - Problème de configuration Apple Sign-In');
          print('🔍 Vérifications nécessaires:');
          print('   1. Xcode: Signing & Capabilities → Sign In with Apple activé');
          print('   2. Apple Developer Portal: App ID be.jirig.app avec Sign In with Apple');
          print('   3. Backend: NUXT_APPLE_CLIENT_ID = be.jirig.app');
          print('   4. Provisioning Profile: Régénéré après activation de la capability');
          errorMessage = 'Erreur de configuration (1000). Vérifiez dans Xcode que "Sign In with Apple" est activé dans Signing & Capabilities, et que l\'App ID be.jirig.app est configuré dans Apple Developer Portal avec Sign In with Apple activé.';
        } else {
          errorMessage = 'Erreur Apple Sign-In: ${e.message ?? e.code.toString()}';
        }
      } else {
        errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }
      }
      
      if (errorMessage.isNotEmpty) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  /// Connexion avec Facebook - Implémentation mobile native
  Future<void> _loginWithFacebook() async {
    final translationService = Provider.of<TranslationService>(context, listen: false);
    setState(() {
      _isSocialLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Lancer la connexion avec le SDK natif de Facebook
      print('📱 === DÉBUT CONNEXION FACEBOOK ===');
      print('📱 Plateforme: ${Platform.isIOS ? "iOS" : "Android"}');
      
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      
      print('📱 Résultat Facebook: status=${result.status}, message=${result.message}');

      // 2. Vérifier si la connexion a réussi
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        print("✅ Token Facebook obtenu: ${accessToken.tokenString.substring(0, 20)}...");

        // 3. Utiliser ApiService pour faire l'appel et gérer les cookies (Centralisé)
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.initialize();
        
        final responseBody = await apiService.loginWithFacebookMobile(accessToken.tokenString);

        if (responseBody['status'] == 'success') {
          // Notifier l'AuthNotifier
          final authNotifier = Provider.of<AuthNotifier>(context, listen: false);
          await authNotifier.onLogin();
          
          // Gérer la redirection
          String callBackUrl = await LocalStorageService.getCallBackUrl() ?? widget.callBackUrl ?? '/wishlist';
          await LocalStorageService.clearCallBackUrl();

          if (mounted) {
            await _showSuccessPopup();
            context.go(callBackUrl);
          }
        } else {
          throw Exception('Erreur du serveur: ${responseBody['message'] ?? 'Erreur inconnue'}');
        }

      } else {
        // Gérer les cas où l'utilisateur annule ou échoue la connexion
        print('⚠️ Statut de la connexion Facebook: ${result.status}');
        print('ℹ️ Message: ${result.message}');
        if(result.status != LoginStatus.cancelled) {
          throw Exception('La connexion Facebook a échoué.');
        }
      }
    } catch (e, stackTrace) {
      print("❌ Erreur lors de la connexion Facebook:");
      print("   Exception: $e");
      print("   Type: ${e.runtimeType}");
      print("   StackTrace: $stackTrace");
      
      String errorMessage;
      
      // Erreurs spécifiques iOS - Configuration manquante
      if (e.toString().contains('FacebookAppID') || 
          e.toString().contains('CFBundleURLSchemes') ||
          e.toString().contains('configuration') ||
          e.toString().contains('Info.plist')) {
        errorMessage = 'Erreur de configuration Facebook. Vérifiez que FacebookAppID est configuré dans Info.plist.';
        print('⚠️ Erreur de configuration Facebook détectée');
      } else if (e is DioException && e.response?.data is Map) {
        final errorData = e.response!.data as Map<String, dynamic>;
        errorMessage = errorData['message'] ?? 'Erreur de communication avec le serveur.';
      } else {
        errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring('Exception: '.length);
        }
        // Message plus user-friendly pour les erreurs génériques
        if (errorMessage.contains('PlatformException') || 
            errorMessage.contains('MissingPluginException')) {
          errorMessage = 'Erreur de configuration Facebook. Vérifiez la configuration iOS dans Info.plist.';
        }
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  // ✅ Fonction _openCodeModal supprimée - le modal d'affichage du code n'est plus utilisé

  void _handleBackNavigation(BuildContext context) {
    if (widget.fromAuthError == true) {
      context.go('/home');
      return;
    }

    if (kIsWeb) {
      try {
        WebUtils.navigateBack();
        return;
      } catch (e) {
        // Ignorer et fallback ci-dessous
      }
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/wishlist');
    }
  }

  @override
  Widget build(BuildContext context) {
    final translationService = Provider.of<TranslationService>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final welcomeTitle = translationService.translate('LOGIN_WELCOME_TITLE');
    final welcomeSubtitle =
        translationService.translate('LOGIN_WELCOME_SUBTITLE');
    final loginTitle = translationService.translate('LOGIN_TITLE');
    final loginSubtitle = translationService.translate('LOGINREQUIRED06');
    final emailLabel = translationService.translate('LOGIN_EMAIL');
    final emailPlaceholder =
        translationService.translate('LOGIN_EMAIL_PLACEHOLDER');
    final codeLabel = translationService.translate('LOGIN_CODE_LABEL');
    final codePlaceholder =
        translationService.translate('LOGIN_CODE_PLACEHOLDER');
    final sendCodeLabel =
        translationService.translate('LOGIN_SEND_LINK');
    final validateCodeLabel =
        translationService.translate('ONBOARDING_VALIDATE');
    // ✅ Nouveau label pour "Se connecter"
    final connectLabel =
        translationService.translate('LOGIN_CONNECT') ?? 'Se connecter';
    final sendingCodeLabel =
        translationService.translate('LOGIN_LOADING_SENDING_CODE');
    final connectingLabel =
        translationService.translate('APPHEADER_LOGIN...');
    final separatorText =
        translationService.translate('AUTH_Msg01');
    final continueWithGoogleText =
        translationService.translate('LOGIN_GOOGLE');
    final continueWithFacebookText =
        translationService.translate('LOGIN_FACEBOOK');
    final continueWithAppleText =
        translationService.translate('LOGIN_APPLE') ?? 'Continuer avec Apple';
    final termsPrefix = translationService.translate('AUTH_Msg02');
    final termsLink = translationService.translate('AUTH_Msg03');
    final privacyLink = translationService.translate('AUTH_Msg04');

    final Widget termsBlock = Column(
      children: [
        Text(
          termsPrefix,
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            GestureDetector(
              onTap: () {
                TermsOfUseModal.show(
                  context,
                  translationService: translationService,
                );
              },
              child: Text(
                termsLink,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFF0051BA),
                  // decoration: TextDecoration.underline, // ✅ Removed underline
                ),
              ),
            ),
            Text(
              ' et ',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey[600],
              ),
            ),
            GestureDetector(
              onTap: () {
                PrivacyPolicyModal.show(
                  context,
                  translationService: translationService,
                );
              },
              child: Text(
                privacyLink,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: const Color(0xFF0051BA),
                  // decoration: TextDecoration.underline, // ✅ Removed underline
                ),
              ),
            ),
          ],
        ),
      ],
    );

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
                  onPressed: () => _handleBackNavigation(context),
      ),
                ),
              )
          : AppBar(
              backgroundColor: const Color(0xFF0051BA), // Bleu Jirig principal
              elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => _handleBackNavigation(context),
                      ),
                    ),
                  ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading || _isSocialLoading)
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0051BA)),
                minHeight: 3,
              ),
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
                                        welcomeTitle,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 36 : 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: isDesktop ? 24 : 16),
                                      Text(
                                        welcomeSubtitle,
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
                                              loginTitle,
                                              style: TextStyle(
                                                fontSize: isMobile ? 20 : 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                            SizedBox(height: isMobile ? 6 : 8),
                                            Text(
                                              loginSubtitle,
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
                                          loginTitle,
                                          style: TextStyle(
                                            fontSize: isMobile ? 20 : 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[900],
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 6 : 8),
                                        Text(
                                          loginSubtitle,
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
                                                emailLabel,
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
                                                  hintText: emailPlaceholder,
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
                                          emailLabel,
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
                                            hintText: emailPlaceholder,
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
                                        // ✅ Message proéminent : Sortir de l'app pour vérifier l'email
                                        Container(
                                          padding: EdgeInsets.all(isMobile ? 16 : 18),
                                          margin: EdgeInsets.only(bottom: 16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFFE3F2FD),
                                                const Color(0xFFBBDEFB),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFF2196F3),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF2196F3).withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2196F3),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.info_outline_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      translationService.translate('LOGIN_EXIT_APP_TITLE'),
                                                      style: TextStyle(
                                                        fontSize: isMobile ? 15 : 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF1565C0),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      translationService.translate('LOGIN_EXIT_APP_MESSAGE'),
                                                      style: TextStyle(
                                                        fontSize: isMobile ? 13 : 14,
                                                        color: const Color(0xFF1976D2),
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          codeLabel,
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
                                            hintText: codePlaceholder,
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
                                  // ✅ Message informatif : Code envoyé (optionnel, car le message principal est au-dessus)
                                  if (_awaitingCode)
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      margin: EdgeInsets.only(top: 12, bottom: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF81C784)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.email_outlined, color: Color(0xFF4CAF50), size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              translationService.translate('LOGIN_CODE_SENT_MESSAGE'),
                                              style: const TextStyle(
                                                color: Color(0xFF2E7D32),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(height: isMobile ? 16 : 24),
                                  // Message d'erreur
                                  if (_errorMessage.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      margin: EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F4FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFB6DEFF)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, color: Color(0xFF1B73D1), size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage,
                                              style: const TextStyle(
                                                color: Color(0xFF1B73D1),
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
                                      onPressed: _isLoading
                                          ? null
                                          : (!_awaitingCode
                                              ? (_isEmailValid && _emailController.text.trim().isNotEmpty
                                                  ? _loginWithEmail
                                                  : null)
                                              : _loginWithEmail),
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
                                                  _awaitingCode
                                                      ? connectingLabel
                                                      : sendingCodeLabel,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                    Icon(Icons.check_circle, size: isMobile ? 20 : 22),
                                                SizedBox(width: 8),
                                                Text(
                                                  _awaitingCode
                                                      ? connectLabel
                                                      : validateCodeLabel,
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
                                          separatorText,
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
                                        onPressed: _isLoading || _isSocialLoading ? () => null : _loginWithGoogle,
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
                                                continueWithGoogleText,
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
                                        onPressed: _isLoading || _isSocialLoading ? () => null : _loginWithFacebook,
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
                                                continueWithFacebookText,
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
                                      // Apple avec animation (iOS uniquement)
                                      if (Platform.isIOS) ...[
                                        SizedBox(height: 12),
                                        _buildSocialButton(
                                          index: 2,
                                          isMobile: isMobile,
                                          onPressed: _isLoading || _isSocialLoading ? () => null : _loginWithApple,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Icône Apple
                                              Icon(
                                                Icons.apple,
                                                size: 20,
                                                color: Colors.grey[700],
                                              ),
                                              SizedBox(width: isMobile ? 8 : 12),
                                              Flexible(
                                                child: Text(
                                                  continueWithAppleText,
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
                                    ],
                                  ),
                                  SizedBox(height: isMobile ? 16 : 24),
                                  // Footer text avec animation
                                  if (_animationsInitialized)
                                    FadeTransition(
                                      opacity: _buttonsController,
                                      child: termsBlock,
                                    )
                                  else
                                    termsBlock,
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
  
  Widget _buildSocialButton({
    required int index,
    required bool isMobile,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    final Widget buttonContent = child;

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
          child: buttonContent,
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
          child: buttonContent,
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
    final translationService =
        Provider.of<TranslationService>(context, listen: false);
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Fermer automatiquement après 2 secondes
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
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
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Titre
                Text(
                  translationService.translate('LOGIN_SUCCESS_TITLE'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  translationService.translate('LOGIN_SUCCESS_MESSAGE'),
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