import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:page_transition/page_transition.dart';
import 'screens/splash_screen.dart';
import 'screens/country_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/product_search_screen.dart';
import 'screens/podium_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_detail_screen.dart';
import 'screens/login_screen.dart';
// Imports OAuth et magic login supprimés - plus utilisés
import 'services/settings_service.dart';
import 'services/api_service.dart';
import 'services/translation_service.dart';
import 'services/country_notifier.dart';
import 'services/auth_notifier.dart';
import 'services/local_storage_service.dart';
import 'services/route_persistence_service.dart';
// Import deep_link_service supprimé - plus utilisé

/// Application principale
class JirigApp extends StatefulWidget {
  const JirigApp({super.key});

  @override
  State<JirigApp> createState() => _JirigAppState();
}

class _JirigAppState extends State<JirigApp> {
  GoRouter? _router;
  bool _isLoading = true;
  final ApiService _apiService = ApiService(); // Instance singleton réutilisable
  // DeepLinkService supprimé - plus utilisé

  // ✅ Déterminer la route initiale depuis SharedPreferences (mobile-first)
  Future<String> _getInitialLocation() async {
    final startupRoute = await RoutePersistenceService.getStartupRoute();
    print('🔄 Route initiale: $startupRoute');
    return startupRoute;
  }

  // Helper pour créer des transitions de page personnalisées
  Page<dynamic> _buildPageWithTransition(
    BuildContext context,
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return PageTransition(
          type: PageTransitionType.fade,
          duration: const Duration(milliseconds: 300),
          child: child,
        ).buildTransitions(context, animation, secondaryAnimation, child);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      print('🚀 Initialisation de l\'application...');
      print('🔍 Plateforme: ${kIsWeb ? "Web" : "Mobile"}');
      
      // Initialiser le profil local (localStorage)
      print('📱 Initialisation du profil local...');
      await LocalStorageService.initializeProfile();
      
      // Vérifier le profil stocké
      final profile = await LocalStorageService.getProfile();
      print('📦 Profil stocké: ${profile?.keys.join(', ')}');
      print('📧 Email dans le profil: ${profile?['sEmail']}');
      print('👤 Nom dans le profil: ${profile?['sNom']}');
      print('👤 Prénom dans le profil: ${profile?['sPrenom']}');
      
      // Vérifier si l'utilisateur est connecté
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      print('🔍 Utilisateur connecté: $isLoggedIn');
      
      if (isLoggedIn) {
        final userInfo = await LocalStorageService.getUserInfo();
        print('👤 Informations utilisateur: $userInfo');
      } else {
        print('👤 Utilisateur non connecté - mode Guest');
      }
      
      // Initialiser l'API service (UNE SEULE FOIS)
      print('🌐 Initialisation de l\'API service...');
      await _apiService.initialize();
      
      // Configurer le router
      _router = GoRouter(
        initialLocation: await _getInitialLocation(),
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/country-selection',
            builder: (context, state) => const CountrySelectionScreen(),
          ),
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/product-search',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ProductSearchScreen(),
            ),
          ),
          GoRoute(
            path: '/product-code',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ProductSearchScreen(),
            ),
          ),
          // Note: /scanner route removed - QR scanner is now a modal via QrScannerModal
          GoRoute(
            path: '/podium/:code',
            pageBuilder: (context, state) {
              final code = state.pathParameters['code'] ?? '';
              final crypt = state.uri.queryParameters['crypt'];
              return _buildPageWithTransition(
                context,
                state,
                PodiumScreen(
                  productCode: code,
                  productCodeCrypt: crypt,
                ),
              );
            },
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (context, state) {
              // Récupérer le callBackUrl et fromAuthError depuis les query parameters
              final callBackUrl = state.uri.queryParameters['callBackUrl'];
              final fromAuthError = state.uri.queryParameters['fromAuthError'] == 'true';
              return _buildPageWithTransition(
                context,
                state,
                LoginScreen(
                  callBackUrl: callBackUrl,
                  fromAuthError: fromAuthError,
                ),
              );
            },
          ),
          // Route OAuth callback supprimée - gérée directement par SNAL
          GoRoute(
            path: '/profil',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ProfileDetailScreen(),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) => const Scaffold(
              body: Center(
                child: Text('Page d\'abonnement - À implémenter'),
              ),
            ),
          ),
          GoRoute(
            path: '/wishlist',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const WishlistScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ProfileScreen(),
            ),
          ),
          // Routes MagicLogin et OAuth supprimées - système basé sur les codes uniquement
        ],
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // DeepLinkService supprimé - plus de gestion des deep links
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation de l\'app: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    // DeepLinkService supprimé - plus de dispose nécessaire
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si l'application est en cours de chargement ou si le router n'est pas encore initialisé
    if (_isLoading || _router == null) {
      return MaterialApp(
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3A8A),
                  Color(0xFF3B82F6),
                  Color(0xFFF59E0B),
                ],
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService), // Utiliser l'instance déjà initialisée
        Provider<SettingsService>(create: (_) => SettingsService()),
        ChangeNotifierProvider<TranslationService>(
          create: (context) => TranslationService(_apiService), // Utiliser directement l'instance
        ),
        ChangeNotifierProvider<CountryNotifier>(
          create: (_) => CountryNotifier(),
        ),
        ChangeNotifierProvider<AuthNotifier>(
          create: (_) => AuthNotifier()..initialize(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Jirig',
        debugShowCheckedModeBanner: false,
        
        // Configuration des langues
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'EN'),
          Locale('de', 'DE'),
          Locale('es', 'ES'),
          Locale('it', 'IT'),
          Locale('pt', 'PT'),
          Locale('nl', 'NL'),
        ],
      
      // Thème
            theme: ThemeData(
              primarySwatch: Colors.blue,
              primaryColor: const Color(0xFF3B82F6),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF3B82F6),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              // ✅ Police système mobile-first (comme SNAL-Project)
              // Utilise la police système par défaut (Roboto sur Android, SF Pro sur iOS, Arial sur Web)
              textTheme: ThemeData.light().textTheme,
        
        // Configuration des boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        // Configuration des cartes
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        
        // Configuration de l'AppBar
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF3B82F6),
          foregroundColor: Colors.white,
        ),
      ),
      
        // Router - maintenant sécurisé
        routerConfig: _router,
      ),
    );
  }
}
