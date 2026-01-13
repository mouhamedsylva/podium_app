/// Modèle représentant les informations de version de l'application
/// Basé sur la structure réelle de l'API SNAL-Project
class AppVersionInfo {
  final String minVersion;
  final String latestVersion;
  final String currentVersion;
  final bool updateAvailable;
  final bool updateRequired;
  final String updateUrl;
  final bool forceUpdate;
  final String title;
  final String message;
  final String releaseNotes;
  final bool active;
  final String? createdAt;

  AppVersionInfo({
    required this.minVersion,
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    required this.updateRequired,
    required this.updateUrl,
    required this.forceUpdate,
    required this.title,
    required this.message,
    required this.releaseNotes,
    required this.active,
    this.createdAt,
  });

  /// Créer une instance depuis une Map (réponse JSON)
  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      minVersion: json['minVersion']?.toString() ?? '1.0.0',
      latestVersion: json['latestVersion']?.toString() ?? '1.0.0',
      currentVersion: json['currentVersion']?.toString() ?? '1.0.0',
      updateAvailable: json['updateAvailable'] == true,
      updateRequired: json['updateRequired'] == true,
      updateUrl: json['updateUrl']?.toString() ?? '',
      forceUpdate: json['forceUpdate'] == true,
      title: json['title']?.toString() ?? 'Mise à jour disponible',
      message: json['message']?.toString() ?? 'Une nouvelle version est disponible.',
      releaseNotes: json['releaseNotes']?.toString() ?? json['message']?.toString() ?? '',
      active: json['active'] == true,
      createdAt: json['CreatedAt']?.toString(),
    );
  }

  /// Convertir en Map (pour debug)
  Map<String, dynamic> toJson() {
    return {
      'minVersion': minVersion,
      'latestVersion': latestVersion,
      'currentVersion': currentVersion,
      'updateAvailable': updateAvailable,
      'updateRequired': updateRequired,
      'updateUrl': updateUrl,
      'forceUpdate': forceUpdate,
      'title': title,
      'message': message,
      'releaseNotes': releaseNotes,
      'active': active,
      'CreatedAt': createdAt,
    };
  }

  /// Vérifier si une mise à jour est nécessaire (mise à jour obligatoire)
  bool get needsUpdate => updateRequired || (forceUpdate && updateAvailable);

  /// Vérifier si une mise à jour est disponible (mise à jour optionnelle)
  bool get hasUpdate => updateAvailable && !updateRequired;

  @override
  String toString() {
    return 'AppVersionInfo(minVersion: $minVersion, latestVersion: $latestVersion, currentVersion: $currentVersion, updateAvailable: $updateAvailable, updateRequired: $updateRequired)';
  }
}
