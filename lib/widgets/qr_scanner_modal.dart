import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../services/local_storage_service.dart';

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
  String _scanningMessage = '';
  String? _scannedCode;
  double _confidenceLevel = 0.0;
  bool _showTips = false;
  String _currentTip = '';
  bool _isFrontCamera = false; // État de la caméra (false = back, true = front)
  
  String _currentLanguage = 'FR';
  
  // ✅ Traductions locales pour le QR Scanner
  static const Map<String, Map<String, String>> _translations = {
    'FR': {
      'scanner_title': 'Scanner QR Code',
      'position_qr': 'Positionnez le QR code dans le cadre',
      'center_qr': 'Centrez le QR code dans le cadre',
      'ensure_clear': 'Assurez-vous que le QR code est net',
      'adjust_distance': 'Ajustez la distance (15-30cm idéal)',
      'avoid_reflections': 'Évitez les reflets et ombres',
      'camera_permission_required': 'Permission caméra requise',
      'camera_error': 'Erreur permissions caméra',
      'restart_error': 'Erreur redémarrage scanner',
      'invalid_qr': 'Code QR invalide',
      'invalid_qr_retry': 'Code QR invalide - Veuillez réessayer',
      'qr_validated': 'QR Code validé !',
      'qr_detected': 'QR CODE détecté',
      'redirecting': 'Redirection...',
      'capturing': 'Capture en cours...',
      'analyzing': 'Analyse...',
      'quality': 'Qualité',
      'navigation_error': 'Erreur lors de la navigation',
      'camera_error_unknown': 'Erreur caméra: {message}',
      'retry': 'Réessayer',
      'camera_front': 'Caméra avant',
      'camera_rear': 'Caméra arrière',
    },
    'DE': {
      'scanner_title': 'QR-Code scannen',
      'position_qr': 'Positionieren Sie den QR-Code im Rahmen',
      'center_qr': 'Zentrieren Sie den QR-Code im Rahmen',
      'ensure_clear': 'Stellen Sie sicher, dass der QR-Code scharf ist',
      'adjust_distance': 'Passen Sie den Abstand an (15-30 cm ideal)',
      'avoid_reflections': 'Vermeiden Sie Reflexionen und Schatten',
      'camera_permission_required': 'Kamera-Berechtigung erforderlich',
      'camera_error': 'Kamera-Berechtigungsfehler',
      'restart_error': 'Scanner-Neustart-Fehler',
      'invalid_qr': 'Ungültiger QR-Code',
      'invalid_qr_retry': 'Ungültiger QR-Code - Bitte versuchen Sie es erneut',
      'qr_validated': 'QR-Code validiert!',
      'qr_detected': 'QR-CODE erkannt',
      'redirecting': 'Weiterleitung...',
      'capturing': 'Erfassung läuft...',
      'analyzing': 'Analysiere...',
      'quality': 'Qualität',
      'navigation_error': 'Fehler bei der Navigation',
      'camera_error_unknown': 'Kamera-Fehler: {message}',
      'retry': 'Erneut versuchen',
      'camera_front': 'Frontkamera',
      'camera_rear': 'Rückkamera',
    },
    'NL': {
      'scanner_title': 'QR-code scannen',
      'position_qr': 'Plaats de QR-code in het kader',
      'center_qr': 'Centreer de QR-code in het kader',
      'ensure_clear': 'Zorg ervoor dat de QR-code scherp is',
      'adjust_distance': 'Pas de afstand aan (15-30 cm ideaal)',
      'avoid_reflections': 'Vermijd reflecties en schaduwen',
      'camera_permission_required': 'Cameratoestemming vereist',
      'camera_error': 'Cameratoestemmingsfout',
      'restart_error': 'Scanner herstartfout',
      'invalid_qr': 'Ongeldige QR-code',
      'invalid_qr_retry': 'Ongeldige QR-code - Probeer het opnieuw',
      'qr_validated': 'QR-code gevalideerd!',
      'qr_detected': 'QR-CODE gedetecteerd',
      'redirecting': 'Doorverwijzen...',
      'capturing': 'Vastleggen...',
      'analyzing': 'Analyseren...',
      'quality': 'Kwaliteit',
      'navigation_error': 'Fout bij navigatie',
      'camera_error_unknown': 'Camerafout: {message}',
      'retry': 'Opnieuw proberen',
      'camera_front': 'Frontcamera',
      'camera_rear': 'Achtercamera',
    },
    'ES': {
      'scanner_title': 'Escanear código QR',
      'position_qr': 'Posicione el código QR en el marco',
      'center_qr': 'Centre el código QR en el marco',
      'ensure_clear': 'Asegúrese de que el código QR esté nítido',
      'adjust_distance': 'Ajuste la distancia (15-30 cm ideal)',
      'avoid_reflections': 'Evite reflejos y sombras',
      'camera_permission_required': 'Permiso de cámara requerido',
      'camera_error': 'Error de permisos de cámara',
      'restart_error': 'Error al reiniciar el escáner',
      'invalid_qr': 'Código QR inválido',
      'invalid_qr_retry': 'Código QR inválido - Por favor, inténtelo de nuevo',
      'qr_validated': '¡Código QR validado!',
      'qr_detected': 'CÓDIGO QR detectado',
      'redirecting': 'Redirigiendo...',
      'capturing': 'Capturando...',
      'analyzing': 'Analizando...',
      'quality': 'Calidad',
      'navigation_error': 'Error en la navegación',
      'camera_error_unknown': 'Error de cámara: {message}',
      'retry': 'Reintentar',
      'camera_front': 'Cámara frontal',
      'camera_rear': 'Cámara trasera',
    },
    'IT': {
      'scanner_title': 'Scansiona codice QR',
      'position_qr': 'Posiziona il codice QR nel riquadro',
      'center_qr': 'Centra il codice QR nel riquadro',
      'ensure_clear': 'Assicurati che il codice QR sia nitido',
      'adjust_distance': 'Regola la distanza (15-30 cm ideale)',
      'avoid_reflections': 'Evita riflessi e ombre',
      'camera_permission_required': 'Autorizzazione fotocamera richiesta',
      'camera_error': 'Errore autorizzazione fotocamera',
      'restart_error': 'Errore riavvio scanner',
      'invalid_qr': 'Codice QR non valido',
      'invalid_qr_retry': 'Codice QR non valido - Riprova',
      'qr_validated': 'Codice QR convalidato!',
      'qr_detected': 'CODICE QR rilevato',
      'redirecting': 'Reindirizzamento...',
      'capturing': 'Acquisizione in corso...',
      'analyzing': 'Analisi...',
      'quality': 'Qualità',
      'navigation_error': 'Errore durante la navigazione',
      'camera_error_unknown': 'Errore fotocamera: {message}',
      'retry': 'Riprova',
      'camera_front': 'Fotocamera frontale',
      'camera_rear': 'Fotocamera posteriore',
    },
    'PT': {
      'scanner_title': 'Escanear código QR',
      'position_qr': 'Posicione o código QR no quadro',
      'center_qr': 'Centralize o código QR no quadro',
      'ensure_clear': 'Certifique-se de que o código QR está nítido',
      'adjust_distance': 'Ajuste a distância (15-30 cm ideal)',
      'avoid_reflections': 'Evite reflexos e sombras',
      'camera_permission_required': 'Permissão de câmera necessária',
      'camera_error': 'Erro de permissão de câmera',
      'restart_error': 'Erro ao reiniciar o scanner',
      'invalid_qr': 'Código QR inválido',
      'invalid_qr_retry': 'Código QR inválido - Por favor, tente novamente',
      'qr_validated': 'Código QR validado!',
      'qr_detected': 'CÓDIGO QR detectado',
      'redirecting': 'Redirecionando...',
      'capturing': 'Capturando...',
      'analyzing': 'Analisando...',
      'quality': 'Qualidade',
      'navigation_error': 'Erro na navegação',
      'camera_error_unknown': 'Erro de câmera: {message}',
      'retry': 'Tentar novamente',
      'camera_front': 'Câmera frontal',
      'camera_rear': 'Câmera traseira',
    },
    'EN': {
      'scanner_title': 'Scan QR Code',
      'position_qr': 'Position the QR code in the frame',
      'center_qr': 'Center the QR code in the frame',
      'ensure_clear': 'Make sure the QR code is sharp',
      'adjust_distance': 'Adjust the distance (15-30cm ideal)',
      'avoid_reflections': 'Avoid reflections and shadows',
      'camera_permission_required': 'Camera permission required',
      'camera_error': 'Camera permission error',
      'restart_error': 'Scanner restart error',
      'invalid_qr': 'Invalid QR code',
      'invalid_qr_retry': 'Invalid QR code - Please try again',
      'qr_validated': 'QR Code validated!',
      'qr_detected': 'QR CODE detected',
      'redirecting': 'Redirecting...',
      'capturing': 'Capturing...',
      'analyzing': 'Analyzing...',
      'quality': 'Quality',
      'navigation_error': 'Navigation error',
      'camera_error_unknown': 'Camera error: {message}',
      'retry': 'Retry',
      'camera_front': 'Front camera',
      'camera_rear': 'Rear camera',
    },
  };
  
  /// Récupérer la traduction pour une clé
  String _t(String key, {String? language}) {
    final lang = language ?? _currentLanguage;
    final translations = _translations[lang] ?? _translations['FR']!;
    return translations[key] ?? key;
  }
  
  /// Récupérer la langue actuelle depuis localStorage
  Future<void> _loadLanguage() async {
    try {
      final profile = await LocalStorageService.getProfile();
      if (profile != null && profile['sPaysLangue'] != null) {
        final sPaysLangue = profile['sPaysLangue'].toString();
        // Extraire la langue (ex: "FR/FR" -> "FR")
        final lang = sPaysLangue.split('/').first.toUpperCase();
        if (_translations.containsKey(lang)) {
          setState(() {
            _currentLanguage = lang;
            _scanningMessage = _t('position_qr');
            _currentTip = _t('center_qr');
          });
        }
      }
    } catch (e) {
      print('⚠️ Erreur lors du chargement de la langue: $e');
    }
  }
  
  List<String> get _qrTips => [
    _t('center_qr'),
    _t('ensure_clear'),
    _t('adjust_distance'),
    _t('avoid_reflections'),
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
    
    // Charger la langue et initialiser les messages
    _loadLanguage().then((_) {
      if (mounted) {
        setState(() {
          if (_scanningMessage.isEmpty) {
            _scanningMessage = _t('position_qr');
          }
          if (_currentTip.isEmpty) {
            _currentTip = _t('center_qr');
          }
        });
      }
    });
    
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
        _scanningMessage = _t('position_qr');
        _confidenceLevel = 0.0;
        _showTips = false;
      });
      
      print('✅ Scanner redémarré');
    } catch (e) {
      print('❌ Erreur redémarrage scanner: $e');
      setState(() {
        _scanningMessage = _t('restart_error');
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
          _scanningMessage = _t('camera_permission_required');
          _isScanning = false;
        });
        return;
      }
      
      print('✅ Permissions caméra OK');
    } catch (e) {
      print('❌ Erreur vérification permissions: $e');
      setState(() {
        _scanningMessage = _t('camera_error');
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
      _scanningMessage = _t('invalid_qr');
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
        _scanningMessage = _t('invalid_qr_retry');
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
      _scanningMessage = _t('qr_validated');
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
          _scanningMessage = _t('navigation_error');
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
                        _t('camera_error_unknown').replaceAll('{message}', error.errorDetails?.message ?? 'Inconnue'),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // ✅ CORRECTION: Redémarrer le scanner en cas d'erreur
                          _restartScanner();
                        },
                        child: Text(_t('retry')),
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
                    Text(
                      _t('scanner_title'),
                      style: const TextStyle(
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
                      tooltip: _isFrontCamera ? _t('camera_rear') : _t('camera_front'),
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
                Text(
                  _t('qr_detected'),
                  style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('redirecting'),
                  style: const TextStyle(
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
                Text(
                  _t('capturing'),
                  style: const TextStyle(
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
                Text(
                  _t('analyzing'),
                  style: const TextStyle(
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
                    '${_t('quality')}: ${(_confidenceLevel * 100).round()}%',
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

