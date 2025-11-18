import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class QrScannerModal extends StatefulWidget {
  final VoidCallback? onClose;
  
  const QrScannerModal({
    Key? key,
    this.onClose,
  }) : super(key: key);

  @override
  State<QrScannerModal> createState() => _QrScannerModalState();
}

class _QrScannerModalState extends State<QrScannerModal> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // Changé de noDuplicates à normal pour permettre détections multiples
    facing: CameraFacing.back,
  );

  bool _isScanning = true;
  bool _detectionSuccess = false;
  bool _isDetecting = false;
  bool _isCapturing = false;
  String _scanningMessage = 'Positionnez le QR code dans le cadre';
  String? _scannedCode;
  double _confidenceLevel = 0.0;
  bool _showTips = false;
  String _currentTip = 'Centrez le QR code dans le cadre';
  bool _isFrontCamera = false; // État de la caméra (false = back, true = front)
  
  final List<String> _qrTips = [
    'Centrez le QR code dans le cadre',
    'Assurez-vous que le QR code est net',
    'Ajustez la distance (15-30cm idéal)',
    'Évitez les reflets et ombres',
  ];

  // Buffer de détection
  final List<Map<String, dynamic>> _scanHistory = [];
  static const double _confidenceThreshold = 0.6;
  static const int _minDetections = 2;
  static const int _maxHistory = 10;
  static const int _validationWindow = 1500; // ms

  late AnimationController _animationController;
  Timer? _cleanupTimer;
  Timer? _tipsTimer;

  @override
  void initState() {
    super.initState();
    print('🚀 QrScannerModal initState - _isScanning: $_isScanning');
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    // ✅ CORRECTION: Vérifier les permissions caméra au démarrage
    _checkCameraPermissions();

    // Cleanup timer
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldLength = _scanHistory.length;
      _scanHistory.removeWhere(
        (detection) => now - (detection['timestamp'] as int) > _validationWindow * 2,
      );
      if (oldLength != _scanHistory.length) {
        print('🧹 Cleanup: ${oldLength - _scanHistory.length} détections supprimées');
      }
    });

    // Tips timer
    _tipsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_detectionSuccess) {
        setState(() {
          _showTips = true;
        });
        print('💡 Tips affichés');
      }
    });
    
    print('✅ Scanner initialisé et prêt');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cleanupTimer?.cancel();
    _tipsTimer?.cancel();
    
    // ✅ CORRECTION: Gestion sécurisée du dispose
    try {
      _controller.dispose();
    } catch (e) {
      print('⚠️ Erreur lors du dispose du controller: $e');
    }
    
    super.dispose();
  }

  /// Basculer entre la caméra avant et arrière
  Future<void> _switchCamera() async {
    try {
      print('📷 Basculement de la caméra...');
      
      // Inverser l'état
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
      
      // Utiliser switchCamera() du contrôleur
      await _controller.switchCamera();
      
      print('✅ Caméra basculée vers: ${_isFrontCamera ? "avant" : "arrière"}');
      
      // Feedback haptique
      try {
        HapticFeedback.selectionClick();
      } catch (e) {
        print('⚠️ Vibration non supportée: $e');
      }
    } catch (e) {
      print('❌ Erreur lors du basculement de caméra: $e');
      // En cas d'erreur, réinitialiser l'état
      setState(() {
        _isFrontCamera = false;
      });
    }
  }

  /// Redémarrer le scanner en cas d'erreur
  Future<void> _restartScanner() async {
    try {
      print('🔄 Redémarrage du scanner...');
      
      // Arrêter le scanner actuel
      await _controller.stop();
      
      // Attendre un peu
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Redémarrer le scanner
      await _controller.start();
      
      // Réinitialiser l'état
      setState(() {
        _isScanning = true;
        _detectionSuccess = false;
        _isDetecting = false;
        _isCapturing = false;
        _scanningMessage = 'Positionnez le QR code dans le cadre';
        _confidenceLevel = 0.0;
        _showTips = false;
      });
      
      print('✅ Scanner redémarré');
    } catch (e) {
      print('❌ Erreur redémarrage scanner: $e');
      setState(() {
        _scanningMessage = 'Erreur redémarrage scanner';
      });
    }
  }

  /// Vérifier les permissions caméra
  Future<void> _checkCameraPermissions() async {
    try {
      print('🔍 Vérification des permissions caméra...');
      
      // Vérifier si la caméra est disponible
      // Dans mobile_scanner 5.x, on utilise start() pour vérifier la disponibilité
      print('📷 Vérification de la disponibilité de la caméra...');
      
      // La vérification de disponibilité se fait maintenant via start()
      
      // Vérifier les permissions via permission_handler
      final hasPermission = await Permission.camera.isGranted;
      print('🔐 Permission caméra: $hasPermission');
      
      if (!hasPermission) {
        print('❌ Permission caméra refusée');
        setState(() {
          _scanningMessage = 'Permission caméra requise';
          _isScanning = false;
        });
        return;
      }
      
      print('✅ Permissions caméra OK');
    } catch (e) {
      print('❌ Erreur vérification permissions: $e');
      setState(() {
        _scanningMessage = 'Erreur permissions caméra';
        _isScanning = false;
      });
    }
  }

  /// Extraire le code produit du QR code (logique SNAL)
  String? _extractQRCodeValue(String url) {
    try {
      print('🔍 Extraction du QR code URL: $url');
      
      // Pattern pour extraire 8 chiffres consécutifs
      final match = RegExp(r'(\d{8})').firstMatch(url);
      if (match != null && match.group(1) != null) {
        final code = match.group(1)!;
        print('✅ Code extrait: $code');
        return code;
      }
    } catch (err) {
      print('❌ Erreur extraction QR code: $err');
    }
    return null;
  }

  /// Valider si le code QR est valide (logique SNAL)
  // ✅ SNAL ne fait pas de validation stricte de plage (10000000-99999999)
  // SNAL valide seulement que le code contient au moins 8 chiffres
  bool _isValidQRCode(String code) {
    // Vérifier si le code contient au moins 8 chiffres (comme SNAL)
    if (code.length < 8) return false;
    
    // Vérifier si le code contient uniquement des chiffres (comme SNAL)
    if (!RegExp(r'^\d+$').hasMatch(code)) return false;
    
    // ✅ SNAL n'a pas de validation de plage stricte, donc on ne vérifie pas la plage
    // Le code est valide s'il contient au moins 8 chiffres
    return true;
  }

  /// Formater le code personnalisé (XXX.XXX.XX)
  String? _formatCustomCode(String code) {
    final digitsOnly = code.replaceAll(RegExp(r'\D'), '');
    final shortened = digitsOnly.substring(0, digitsOnly.length >= 8 ? 8 : digitsOnly.length);

    if (shortened.length < 8) return null;

    final part1 = shortened.substring(0, 3);
    final part2 = shortened.substring(3, 6);
    final part3 = shortened.substring(6, 8);

    return '$part1.$part2.$part3';
  }

  /// Calculer la confiance basée sur l'historique
  double _calculateConfidence(String code) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentDetections = _scanHistory.where(
      (detection) => now - (detection['timestamp'] as int) < _validationWindow,
    ).toList();

    if (recentDetections.isEmpty) return 0.0;

    final sameCodeDetections = recentDetections.where(
      (d) => d['code'] == code,
    ).length;
    
    final confidence = sameCodeDetections / recentDetections.length;
    return confidence > 1.0 ? 1.0 : confidence;
  }

  /// Mettre à jour les tips selon la confiance
  void _updateTips(double confidence) {
    if (!mounted) return;
    
    setState(() {
      if (confidence < 0.3) {
        _currentTip = _qrTips[0];
      } else if (confidence < 0.5) {
        _currentTip = _qrTips[1];
      } else if (confidence < 0.7) {
        _currentTip = _qrTips[2];
      } else {
        _showTips = false;
      }
    });
  }

  /// Traiter la détection du QR code
  void _processQRDetection(String qrCodeData) {
    if (_detectionSuccess || _isCapturing || !mounted) return;

    print('🔄 Traitement du code: $qrCodeData');

    // Extraction du code
    String? code = _extractQRCodeValue(qrCodeData);
    if (code == null) {
      print('⚠️ Impossible d\'extraire le code, utilisation du code brut');
      code = qrCodeData;
    } else {
      print('✅ Code extrait avec succès: $code');
    }

    // Validation du code
    if (!_isValidQRCode(code)) {
      print('❌ Code QR invalide: $code');
      _handleInvalidScan();
      return;
    }

    // Ajouter à l'historique
    final detection = {
      'code': code,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'quality': 1,
    };

    _scanHistory.add(detection);
    if (_scanHistory.length > _maxHistory) {
      _scanHistory.removeAt(0);
    }

    // Calculer la confiance
    final confidence = _calculateConfidence(code);
    setState(() {
      _confidenceLevel = confidence;
    });

    print('📊 Confiance: ${(confidence * 100).round()}%');

    // Vérifier la validation
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentSameCode = _scanHistory.where(
      (d) => d['code'] == code && now - (d['timestamp'] as int) < _validationWindow,
    ).length;

    print('🔢 Détections identiques récentes: $recentSameCode/$_minDetections');

    if (recentSameCode >= _minDetections && confidence >= _confidenceThreshold) {
      _handleValidScan(code);
    } else {
      setState(() {
        _isDetecting = true;
      });
      _updateTips(confidence);
    }
  }

  /// Gérer un scan invalide
  Future<void> _handleInvalidScan() async {
    if (_detectionSuccess || _isCapturing || !mounted) return;

    print('❌ Scan invalide détecté');

    // Animation d'erreur
    setState(() {
      _isCapturing = true;
      _scanningMessage = 'Code QR invalide';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Feedback haptique d'erreur
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('⚠️ Vibration non supportée: $e');
    }

    // Son d'erreur
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('⚠️ Son non supporté: $e');
    }

    // Arrêter le scanner
    try {
      await _controller.dispose();
    } catch (e) {
      print('❌ Erreur dispose controller: $e');
    }

    // Attendre un peu puis rediriger
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    // Afficher un message d'erreur au lieu de rediriger
    if (mounted) {
      setState(() {
        _scanningMessage = 'Code QR invalide - Veuillez réessayer';
        _isCapturing = false;
        _isDetecting = false;
      });
    }
    
    // Attendre un peu puis fermer le modal
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (mounted) {
      Navigator.of(context).pop();
      widget.onClose?.call();
    }
  }

  /// Gérer un scan validé (logique SNAL)
  Future<void> _handleValidScan(String code) async {
    if (_detectionSuccess || _isCapturing || !mounted) return;

    print('🎉 Scan validé: $code');

    // ✅ Transformation du code : _ → - (comme SNAL ligne 404)
    final formattedCode = code.replaceAll('_', '-');
    print('📝 Code formaté pour URL (après _ → -): $formattedCode');

    // Formatage du code (logique SNAL)
    final formatted = _formatCustomCode(formattedCode);
    final finalCode = formatted ?? formattedCode;
    print('📝 Code final formaté: $finalCode');

    // Animation de capture (300ms comme SNAL)
    setState(() {
      _isCapturing = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _detectionSuccess = true;
      _isDetecting = false;
      _isCapturing = false;
      _scannedCode = finalCode;
      _scanningMessage = 'QR Code validé !';
      _showTips = false;
    });

    // Feedback haptique (comme SNAL avec navigator.vibrate([100, 50, 100]))
    try {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) HapticFeedback.lightImpact();
    } catch (e) {
      print('⚠️ Vibration non supportée: $e');
    }

    // Son de succès (comme SNAL avec AudioContext)
    // Note: Flutter n'a pas d'équivalent direct pour générer des sons oscillateurs
    // On utilise SystemSound à la place (iOS/Android uniquement)
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('⚠️ Son non supporté: $e');
    }

    // Arrêter le scanner (comme SNAL avec stopScanner())
    try {
      await _controller.dispose();
    } catch (e) {
      print('❌ Erreur dispose controller: $e');
    }

    // Attendre 1.5s pour montrer le succès (comme SNAL)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Navigation vers podium (comme SNAL: router.push(`/podium/${finalCode}`))
    try {
      if (context.mounted) {
        // Fermer le modal d'abord (comme SNAL: emit("close"))
        Navigator.of(context).pop();
        widget.onClose?.call();
        
        // Puis naviguer (comme SNAL: await router.push(`/podium/${finalCode}`))
        context.push('/podium/$finalCode');
      }
    } catch (error) {
      print('❌ Erreur post-scan: $error');
      if (mounted) {
        setState(() {
          _scanningMessage = 'Erreur lors de la navigation';
        });
      }
    }
  }

  /// Gérer la détection du barcode
  void _onDetect(BarcodeCapture capture) {
    print('🔔 onDetect appelé - isScanning: $_isScanning, detectionSuccess: $_detectionSuccess, isCapturing: $_isCapturing');
    
    if (!_isScanning || _detectionSuccess || _isCapturing) {
      print('⚠️ Scan ignoré - État: isScanning=$_isScanning, detectionSuccess=$_detectionSuccess, isCapturing=$_isCapturing');
      return;
    }

    final barcodes = capture.barcodes;
    print('📱 Nombre de barcodes détectés: ${barcodes.length}');
    
    for (final barcode in barcodes) {
      print('🔍 Barcode type: ${barcode.type}, rawValue: ${barcode.rawValue}');
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        print('✅ QR Code détecté brut: ${barcode.rawValue}');
        _processQRDetection(barcode.rawValue!);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenir la hauteur de la barre de statut pour éviter la zone système
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Scanner caméra
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                print('❌ Erreur MobileScanner: ${error.errorDetails?.message}');
                print('❌ Type d\'erreur: ${error.errorDetails?.message}');
                
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur caméra: ${error.errorDetails?.message ?? 'Inconnue'}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // ✅ CORRECTION: Redémarrer le scanner en cas d'erreur
                          _restartScanner();
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Header avec bouton fermer
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: statusBarHeight + 8, // Padding pour éviter la zone système + espacement
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.7, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.9), // Plus opaque en haut pour bien couvrir
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () {
                        _controller.dispose();
                        Navigator.of(context).pop();
                        widget.onClose?.call();
                      },
                    ),
                    const Text(
                      'Scanner QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFrontCamera ? Icons.camera_rear : Icons.camera_front,
                        color: Colors.white,
                        size: 28,
                      ),
                      tooltip: _isFrontCamera ? 'Caméra arrière' : 'Caméra avant',
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),

            // Zone de scan avec overlay
            Center(
              child: _buildScanArea(),
            ),

            // Message de statut
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: _buildStatusMessage(),
            ),

            // Tips
            if (_showTips && !_detectionSuccess)
              Positioned(
                bottom: 160,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentTip,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Zone de scan avec animation
  Widget _buildScanArea() {
    Color borderColor = Colors.white.withOpacity(0.8);
    List<Color> gradientColors = [const Color(0xFFFF8C00), const Color(0xFFFFB347)];
    
    if (_detectionSuccess) {
      borderColor = const Color(0xFF4ade80); // Green
      gradientColors = [const Color(0xFF4ade80), const Color(0xFF34d399)];
    } else if (_isCapturing) {
      borderColor = const Color(0xFF60a5fa); // Blue
      gradientColors = [const Color(0xFF60a5fa), const Color(0xFF3b82f6)];
    } else if (_isDetecting) {
      borderColor = const Color(0xFFfbbf24); // Yellow
      gradientColors = [const Color(0xFFfbbf24), const Color(0xFFf59e0b)];
    }

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Coins
          ..._buildCorners(borderColor),
          
          // Animation de grille (si pas en succès ou capture)
          if (!_detectionSuccess && !_isCapturing)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.3 + (_animationController.value * 0.2),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradientColors.map((c) => c.withOpacity(0.1)).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Construire les coins de la zone de scan
  List<Widget> _buildCorners(Color color) {
    return [
      // Top Left
      Positioned(
        top: -6,
        left: -6,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 4),
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: -6,
        right: -6,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: 4),
              right: BorderSide(color: color, width: 4),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: -6,
        left: -6,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: 4),
              left: BorderSide(color: color, width: 4),
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: -6,
        right: -6,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: 4),
              right: BorderSide(color: color, width: 4),
            ),
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(8),
            ),
          ),
        ),
      ),
    ];
  }

  /// Message de statut
  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _scanningMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // État de détection
          if (_detectionSuccess)
            Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4ade80),
                  size: 32,
                ),
                const SizedBox(height: 4),
                const Text(
                  'QR CODE détecté',
                  style: TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Redirection...',
                  style: TextStyle(
                    color: Color(0xFF34d399),
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else if (_isCapturing)
            Column(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF60a5fa),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Capture en cours...',
                  style: TextStyle(
                    color: Color(0xFF60a5fa),
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else if (_isDetecting)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Color(0xFFfbbf24),
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Analyse...',
                  style: TextStyle(
                    color: Color(0xFFfbbf24),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          
          // Indicateur de confiance
          if (_confidenceLevel > 0 && !_detectionSuccess)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _confidenceLevel,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _confidenceLevel < 0.3
                            ? Colors.red
                            : _confidenceLevel < 0.6
                                ? Colors.yellow
                                : Colors.green,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qualité: ${(_confidenceLevel * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

