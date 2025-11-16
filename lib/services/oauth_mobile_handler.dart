import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'local_storage_service.dart';

/// Gère les callbacks OAuth mobiles renvoyés par SNAL via le deep link
/// `jirig://auth/callback`.
class OAuthMobileHandler {
  OAuthMobileHandler._internal();

  static final OAuthMobileHandler _instance = OAuthMobileHandler._internal();

  factory OAuthMobileHandler() => _instance;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;

  /// Initialise l'écoute des deep links. Sans effet sur Web.
  Future<void> init() async {
    if (_initialized || kIsWeb) {
      return;
    }

    _initialized = true;
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri, source: 'initial');
      }
    } catch (e) {
      print('⚠️ [OAuthMobileHandler] Impossible de récupérer le lien initial: $e');
    }

    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) => _handleUri(uri, source: 'stream'),
      onError: (error) =>
          print('⚠️ [OAuthMobileHandler] Erreur flux deep link: $error'),
    );
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    _appLinks = null;
    _initialized = false;
  }

  Future<void> _handleUri(Uri uri, {required String source}) async {
    try {
      print('🔗 [OAuthMobileHandler] Deep link reçu ($source): $uri');

      // on attend un schéma jirig://auth/callback
      final scheme = uri.scheme.toLowerCase();
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();

      if (scheme != 'jirig' || host != 'auth' || !path.startsWith('/callback')) {
        print(
            'ℹ️ [OAuthMobileHandler] Lien ignoré (schéma ou hôte inattendu): $uri');
        return;
      }

      final queryParams = uri.queryParameters;

      if (queryParams.isEmpty) {
        print(
            'ℹ️ [OAuthMobileHandler] Aucun paramètre dans le deep link, rien à traiter.');
        return;
      }

      // Gestion des erreurs éventuelles
      final error = queryParams['error'] ?? queryParams['oauth_error'];
      if (error != null && error.isNotEmpty) {
        final message = queryParams['message'] ?? '';
        print(
            '❌ [OAuthMobileHandler] Erreur OAuth détectée: $error (message: $message)');
        return;
      }

      final iProfile =
          queryParams['iProfile'] ?? queryParams['iprofile'] ?? '';
      final iBasket = queryParams['iBasket'] ?? queryParams['ibasket'] ?? '';

      if (iProfile.isEmpty) {
        print(
            '⚠️ [OAuthMobileHandler] iProfile manquant dans le deep link, impossible de poursuivre.');
      } else {
        await LocalStorageService.saveProfile({
          'iProfile': iProfile,
          if (iBasket.isNotEmpty) 'iBasket': iBasket,
        });
        print(
            '✅ [OAuthMobileHandler] Identifiants OAuth sauvegardés (iProfile=$iProfile, iBasket=$iBasket)');
      }

      final redirect =
          queryParams['redirect'] ??
          queryParams['callBackUrl'] ??
          queryParams['callback'] ??
          '';

      if (redirect.isNotEmpty) {
        // Certains liens peuvent être encodés (%2Fhome). On tente de décoder une fois.
        final decodedRedirect = Uri.decodeComponent(redirect);
        await LocalStorageService.saveCallBackUrl(decodedRedirect);
        print(
            '🔄 [OAuthMobileHandler] callBackUrl mis à jour depuis le deep link: $decodedRedirect');
      }
    } catch (e, stackTrace) {
      print('❌ [OAuthMobileHandler] Erreur lors du traitement du lien: $e');
      print(stackTrace);
    }
  }
}


