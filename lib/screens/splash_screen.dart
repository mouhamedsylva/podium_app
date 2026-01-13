import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/route_persistence_service.dart';
import '../services/translation_service.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _blueRingController;
  late AnimationController _yellowRingController;
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _blueRingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _yellowRingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
    _progressController.forward();

    // Démarrer le processus de chargement et de navigation
    _initializeAndNavigate();
  }

  @override
  void dispose() {
    _blueRingController.dispose();
    _yellowRingController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndNavigate() async {
    if (_hasNavigated || !mounted) {
      return;
    }

    // Attendre que les traductions soient chargées
    print('🔄 SPLASH_SCREEN: Attente du chargement des traductions...');
    final translationService = Provider.of<TranslationService>(context, listen: false);
    await translationService.initializationComplete;
    print('✅ SPLASH_SCREEN: Traductions chargées.');

    if (!mounted) return;

    // ✅ NOUVEAU: Vérifier les mises à jour
    final shouldBlockNavigation = await _checkForAppUpdate();

    if (!mounted) return;

    // Si une mise à jour obligatoire est détectée, bloquer la navigation
    if (shouldBlockNavigation) {
      print('⚠️ SPLASH_SCREEN: Navigation bloquée - mise à jour obligatoire');
      return;
    }

    _hasNavigated = true;

    try {
      final savedRoute = await RoutePersistenceService.getStartupRoute();
      final targetRoute = (savedRoute.isEmpty ||
              savedRoute == '/' ||
              savedRoute == '/splash')
          ? '/country-selection'
          : savedRoute;

      if (mounted) {
        // Arrêter les animations juste avant de naviguer
        _blueRingController.stop();
        _yellowRingController.stop();
        _progressController.stop();
        context.go(targetRoute);
      }
    } catch (e) {
      if (mounted) {
        // Arrêter les animations juste avant de naviguer
        _blueRingController.stop();
        _yellowRingController.stop();
        _progressController.stop();
        context.go('/country-selection');
      }
    }
  }

  /// Vérifier si une mise à jour est disponible
  /// 
  /// Retourne `true` si une mise à jour obligatoire est détectée (bloque la navigation)
  /// Retourne `false` sinon (navigation autorisée)
  Future<bool> _checkForAppUpdate() async {
    try {
      print('🔍 SPLASH_SCREEN: Vérification des mises à jour...');
      
      final appUpdateService = AppUpdateService();
      final versionInfo = await appUpdateService.checkForUpdate();

      if (!mounted) return false;

      // Si une mise à jour est disponible/requise, afficher le dialogue
      if (versionInfo != null) {
        print('📱 SPLASH_SCREEN: Mise à jour détectée, affichage du dialogue...');
        print('   Update Available: ${versionInfo.updateAvailable}');
        print('   Update Required: ${versionInfo.updateRequired}');
        print('   Force Update: ${versionInfo.forceUpdate}');
        print('   Needs Update: ${versionInfo.needsUpdate}');
        
        // Attendre un court délai pour que le SplashScreen soit complètement rendu
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return false;

        // Afficher le dialogue de mise à jour
        await AppUpdateDialog.show(
          context: context,
          versionInfo: versionInfo,
        );

        // Si la mise à jour est obligatoire, bloquer la navigation
        if (versionInfo.needsUpdate) {
          print('⚠️ SPLASH_SCREEN: Mise à jour obligatoire détectée - navigation bloquée');
          return true; // Bloque la navigation
        } else {
          print('✅ SPLASH_SCREEN: Mise à jour optionnelle - navigation autorisée');
          return false; // Autorise la navigation
        }
      } else {
        print('✅ SPLASH_SCREEN: Application à jour - navigation autorisée');
        return false; // Pas de mise à jour, navigation autorisée
      }
    } catch (e) {
      print('❌ SPLASH_SCREEN: Erreur lors de la vérification de mise à jour: $e');
      // En cas d'erreur, continuer normalement (ne pas bloquer l'application)
      return false; // En cas d'erreur, autoriser la navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF21252F),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D3E5C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(140, 140),
                          painter: CirclePathPainter(
                            color: const Color(0xFF3D4D6C),
                            strokeWidth: 5,
                            radiusOffset: 10,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(140, 140),
                          painter: CirclePathPainter(
                            color: const Color(0xFF3D4D6C),
                            strokeWidth: 5,
                            radiusOffset: 22,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _yellowRingController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(140, 140),
                              painter: MovingArcPainter(
                                color: const Color(0xFFFDD835),
                                progress: _yellowRingController.value,
                                arcLength: 3.14159 * 0.5,
                                strokeWidth: 5,
                                clockwise: false,
                                radiusOffset: 10,
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _blueRingController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(140, 140),
                              painter: MovingArcPainter(
                                color: const Color(0xFF0066FF),
                                progress: _blueRingController.value,
                                arcLength: 3.14159 * 1.5,
                                strokeWidth: 5,
                                clockwise: true,
                                radiusOffset: 22,
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'JIRIG',
                              style: TextStyle(
                                color: Color(0xFF0066FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Builder(
                    builder: (context) {
                      final translationService = Provider.of<TranslationService>(context, listen: true);
                      final translatedText = translationService.translate('LOADING_IN_PROGRESS');
                      // Fallback en français si la clé n'est pas trouvée
                      final displayText = translatedText == 'LOADING_IN_PROGRESS' 
                          ? 'Chargement en cours...' 
                          : translatedText;
                      return Text(
                        displayText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding > 0 ? bottomPadding : 0,
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  height: 6,
                  color: const Color(0xFF1A2842),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066FF),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0066FF).withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CirclePathPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radiusOffset;

  CirclePathPainter({
    required this.color,
    required this.strokeWidth,
    required this.radiusOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - strokeWidth / 2 - radiusOffset;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class MovingArcPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double arcLength;
  final double strokeWidth;
  final bool clockwise;
  final double radiusOffset;

  MovingArcPainter({
    required this.color,
    required this.progress,
    required this.arcLength,
    required this.strokeWidth,
    required this.clockwise,
    required this.radiusOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - strokeWidth / 2 - radiusOffset;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final double rotationAngle = clockwise
        ? progress * 2 * 3.14159
        : -progress * 2 * 3.14159;
    final double startAngle = -3.14159 / 2 + rotationAngle;

    canvas.drawArc(rect, startAngle, arcLength, false, paint);
  }

  @override
  bool shouldRepaint(covariant MovingArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

