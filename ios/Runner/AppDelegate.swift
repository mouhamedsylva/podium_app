import Flutter
import UIKit
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ✅ Gérer les URL callbacks de Google Sign-In et Facebook
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Gérer les callbacks Google Sign-In
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    
    // Gérer les callbacks Facebook (le SDK flutter_facebook_auth gère automatiquement via GeneratedPluginRegistrant)
    // Mais on peut aussi le gérer explicitement si nécessaire
    
    // Gérer les autres URL schemes si nécessaire
    return super.application(app, open: url, options: options)
  }
}
