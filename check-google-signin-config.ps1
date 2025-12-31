# Script de vérification complète de la configuration Google Sign-In
# Usage: .\check-google-signin-config.ps1

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔍 VÉRIFICATION COMPLÈTE GOOGLE SIGN-IN" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier le SHA-1
Write-Host "1️⃣ Vérification du SHA-1..." -ForegroundColor Yellow
$sha1Output = keytool -list -v -keystore android/app/monapp-release.jks -alias monapp -storepass 123456 -keypass 123456 2>&1
$sha1Match = $sha1Output | Select-String -Pattern "SHA\s*1\s*:\s*([0-9A-F:]+)" | ForEach-Object { $_.Matches.Groups[1].Value }

if ($sha1Match) {
    Write-Host "   ✅ SHA-1 trouvé: $sha1Match" -ForegroundColor Green
} else {
    Write-Host "   ❌ SHA-1 non trouvé" -ForegroundColor Red
}
Write-Host ""

# 2. Vérifier le package name
Write-Host "2️⃣ Vérification du package name..." -ForegroundColor Yellow
$buildGradle = Get-Content android/app/build.gradle.kts -Raw
$packageMatch = $buildGradle | Select-String -Pattern 'applicationId\s*=\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }

if ($packageMatch) {
    Write-Host "   ✅ Package name: $packageMatch" -ForegroundColor Green
    if ($packageMatch -ne "be.jirig.app") {
        Write-Host "   ⚠️ ATTENTION: Package name différent de 'be.jirig.app'" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Package name non trouvé" -ForegroundColor Red
}
Write-Host ""

# 3. Vérifier le Web Client ID
Write-Host "3️⃣ Vérification du Web Client ID..." -ForegroundColor Yellow
$loginScreen = Get-Content lib/screens/login_screen.dart -Raw
$clientIdMatch = $loginScreen | Select-String -Pattern "const webClientId = '([^']+)'" | ForEach-Object { $_.Matches.Groups[1].Value }

if ($clientIdMatch) {
    Write-Host "   ✅ Web Client ID trouvé: $clientIdMatch" -ForegroundColor Green
    if ($clientIdMatch -like "*YOUR_WEB_CLIENT_ID*" -or $clientIdMatch -like "*example*") {
        Write-Host "   ❌ ERREUR: Web Client ID non configuré (valeur par défaut)" -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ Web Client ID non trouvé" -ForegroundColor Red
}
Write-Host ""

# 4. Vérifier si l'APK existe
Write-Host "4️⃣ Vérification de l'APK..." -ForegroundColor Yellow
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (Test-Path $apkPath) {
    $apkInfo = Get-Item $apkPath
    Write-Host "   ✅ APK trouvé: $apkPath" -ForegroundColor Green
    Write-Host "   📅 Date de création: $($apkInfo.LastWriteTime)" -ForegroundColor Cyan
    Write-Host "   📦 Taille: $([math]::Round($apkInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "   ⚠️ APK non trouvé (normal si pas encore buildé)" -ForegroundColor Yellow
}
Write-Host ""

# Résumé
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📋 RÉSUMÉ" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "SHA-1 Release:     $sha1Match" -ForegroundColor White
Write-Host "Package Name:      $packageMatch" -ForegroundColor White
Write-Host "Web Client ID:     $clientIdMatch" -ForegroundColor White
Write-Host ""

# Checklist
Write-Host "✅ CHECKLIST GOOGLE CLOUD CONSOLE:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Dans Google Cloud Console (https://console.cloud.google.com/):" -ForegroundColor White
Write-Host ""
Write-Host "1. Client OAuth Android:" -ForegroundColor Cyan
Write-Host "   [ ] Package name: be.jirig.app" -ForegroundColor White
Write-Host "   [ ] SHA-1: $sha1Match" -ForegroundColor White
Write-Host ""
Write-Host "2. Client OAuth Web:" -ForegroundColor Cyan
Write-Host "   [ ] Client ID: $clientIdMatch" -ForegroundColor White
Write-Host "   [ ] Redirect URI: https://jirig.be/api/auth/google-mobile" -ForegroundColor White
Write-Host ""
Write-Host "3. Google Play App Signing (si activé):" -ForegroundColor Cyan
Write-Host "   [ ] SHA-1 App Signing Key ajouté dans Google Cloud Console" -ForegroundColor White
Write-Host ""
Write-Host "4. OAuth Consent Screen:" -ForegroundColor Cyan
Write-Host "   [ ] Configuré avec scopes: email, profile, openid" -ForegroundColor White
Write-Host ""
Write-Host "5. Google Sign-In API:" -ForegroundColor Cyan
Write-Host "   [ ] Activée dans Library" -ForegroundColor White
Write-Host ""

# Actions recommandées
Write-Host "🔧 ACTIONS RECOMMANDÉES:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Vérifier Google Play App Signing:" -ForegroundColor White
Write-Host "   → https://play.google.com/console" -ForegroundColor Cyan
Write-Host "   → Release → Setup → App signing" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Si App Signing activé, récupérer le SHA-1 App Signing Key" -ForegroundColor White
Write-Host ""
Write-Host "3. Attendre 30 minutes après dernière modification" -ForegroundColor White
Write-Host ""
Write-Host "4. Rebuilder l'APK:" -ForegroundColor White
Write-Host "   flutter clean" -ForegroundColor Cyan
Write-Host "   flutter build apk --release" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. Désinstaller l'ancien APK:" -ForegroundColor White
Write-Host "   adb uninstall be.jirig.app" -ForegroundColor Cyan
Write-Host ""
Write-Host "6. Installer le nouveau APK et tester" -ForegroundColor White
Write-Host ""

