import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/translation_service.dart';

class PremiumBanner extends StatefulWidget {
  const PremiumBanner({super.key});

  @override
  State<PremiumBanner> createState() => _PremiumBannerState();
}

class _PremiumBannerState extends State<PremiumBanner> with TickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _borderAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    ));
    _borderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.linear,
    ));
    _pulseController!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
    final isMobile = screenWidth < 768;

        return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 32.0),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/img/banner-free.png',
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF5B6FC7),
            Color(0xFF9B4FB7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
                  child: Center(
                    child: Text(
                      'Banner Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Overlay "C'est Cadeau !" dans le coin supérieur droit
          Positioned(
            top: isMobile ? 12 : 16,
            right: isMobile ? 12 : 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Cercle orange clair avec pulsation et bordures animées contenant l'image cadeau
                _pulseAnimation != null && _borderAnimation != null
                    ? AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnimation!, _borderAnimation!]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation!.value,
                            child: Container(
                              width: screenWidth < 400 ? 36 : 
                                     screenWidth < 600 ? 40 : 
                                     screenWidth < 900 ? 44 : 48,
                              height: screenWidth < 400 ? 36 : 
                                      screenWidth < 600 ? 40 : 
                                      screenWidth < 900 ? 44 : 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFFFB366), // Orange clair
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _borderAnimation!.value > 0.7 ? 
                                    Color(0xFFFF8C42).withOpacity(1.0) : 
                                    Color(0xFFFF8C42).withOpacity(0.0),
                                  width: _borderAnimation!.value > 0.7 ? 3 : 0,
                                ),
                                boxShadow: _borderAnimation!.value > 0.7 ? [
                                  BoxShadow(
                                    color: Color(0xFFFF8C42).withOpacity(0.8),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Color(0xFFFFB366).withOpacity(0.6),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ] : [],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/cadeau.png',
                                  width: screenWidth < 400 ? 24 : 
                                         screenWidth < 600 ? 28 : 
                                         screenWidth < 900 ? 30 : 32,
                                  height: screenWidth < 400 ? 24 : 
                                          screenWidth < 600 ? 28 : 
                                          screenWidth < 900 ? 30 : 32,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.card_giftcard,
                                      color: Colors.white,
                                      size: screenWidth < 400 ? 24 : 
                                             screenWidth < 600 ? 28 : 
                                             screenWidth < 900 ? 30 : 32,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: screenWidth < 400 ? 36 : 
                               screenWidth < 600 ? 40 : 
                               screenWidth < 900 ? 44 : 48,
                        height: screenWidth < 400 ? 36 : 
                                screenWidth < 600 ? 40 : 
                                screenWidth < 900 ? 44 : 48,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFB366),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/cadeau.png',
                            width: screenWidth < 400 ? 24 : 
                                   screenWidth < 600 ? 28 : 
                                   screenWidth < 900 ? 30 : 32,
                            height: screenWidth < 400 ? 24 : 
                                    screenWidth < 600 ? 28 : 
                                    screenWidth < 900 ? 30 : 32,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.card_giftcard,
                    color: Colors.white,
                                size: screenWidth < 400 ? 24 : 
                                       screenWidth < 600 ? 28 : 
                                       screenWidth < 900 ? 30 : 32,
                              );
                            },
                          ),
                  ),
                ),
                SizedBox(width: screenWidth < 400 ? 8 : 
                               screenWidth < 600 ? 12 : 
                               screenWidth < 900 ? 14 : 16),
                Text(
                  // 100% gratuite
                  context.read<TranslationService>().translate('BANNER_FREE_100'),
                  style: TextStyle(
                    fontSize: screenWidth < 400 ? 14 : 
                             screenWidth < 600 ? 16 : 
                             screenWidth < 900 ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Texte descriptif centré
          Positioned.fill(
            child: Align(
              alignment: Alignment(0, screenWidth < 600 ? 0.7 : 0.6), // Encore plus bas sur mobile
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 400 ? 20.0 : 
                             screenWidth < 600 ? 28.0 : 
                             screenWidth < 900 ? 32.0 : 48.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Intro banner
                      context.read<TranslationService>().translate('BANNER_FREE_INTRO'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth < 400 ? 9 : 
                                 screenWidth < 600 ? 11 : 
                                 screenWidth < 900 ? 14 : 16,
                        color: Colors.white,
                        height: screenWidth < 600 ? 1.2 : 1.4,
                      ),
                    ),
                    SizedBox(height: screenWidth < 400 ? 4 : 
                                   screenWidth < 600 ? 6 : 
                                   screenWidth < 900 ? 10 : 12),
                    Text(
                      // Description banner
                      context.read<TranslationService>().translate('BANNER_FREE_DESC'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth < 400 ? 9 : 
                                 screenWidth < 600 ? 11 : 
                                 screenWidth < 900 ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFDB00), // Jaune IKEA
                        height: screenWidth < 600 ? 1.2 : 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}