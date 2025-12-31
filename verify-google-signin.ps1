# Script de vérification Google Sign-In Configuration
# Usage: .\verify-google-signin.ps1

Write-Host "🔍 Vérification de la configuration Google Sign-In..." -ForegroundColor Cyan
Write-Host ""

# 1. Vérifier le SHA-1 du keystore
Write-Host "1️⃣ Vérification du SHA-1 du keystore release..." -ForegroundColor Yellow
$sha1Output = keytool -list -v -keystore android/app/monapp-release.jks -alias monapp -storepass 123456 -keypass 123456 2>&1
$sha1Match = $sha1Output | Select-String -Pattern "SHA 1: (.+)" | ForEach-Object { $_.Matches.Groups[1].Value }

if ($sha1Match) {
    Write-Host "   ✅ SHA-1 trouvé: $sha1Match" -ForegroundColor Green
    Write-Host "   📋 SHA-1 à configurer dans Google Cloud Console: $sha1Match" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ SHA-1 non trouvé" -ForegroundColor Red
}
Write-Host ""

# 2. Vérifier le package name
Write-Host "2️⃣ Vérification du package name..." -ForegroundColor Yellow
$buildGradle = Get-Content android/app/build.gradle.kts -Raw
$packageMatch = $buildGradle | Select-String -Pattern 'applicationId\s*=\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }

if ($packageMatch) {
    Write-Host "   ✅ Package name trouvé: $packageMatch" -ForegroundColor Green
    if ($packageMatch -eq "be.jirig.app") {
        Write-Host "   ✅ Package name correct: be.jirig.app" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Package name: $packageMatch (attendu: be.jirig.app)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ❌ Package name non trouvé" -ForegroundColor Red
}
Write-Host ""

# 3. Vérifier le Web Client ID dans le code
Write-Host "3️⃣ Vérification du Web Client ID dans le code..." -ForegroundColor Yellow
$loginScreen = Get-Content lib/screens/login_screen.dart -Raw
$clientIdMatch = $loginScreen | Select-String -Pattern 'const webClientId = ''([^'']+)''' | ForEach-Object { $_.Matches.Groups[1].Value }

if ($clientIdMatch) {
    Write-Host "   ✅ Web Client ID trouvé: $clientIdMatch" -ForegroundColor Green
    Write-Host "   📋 À vérifier dans Google Cloud Console (client OAuth Web)" -ForegroundColor Cyan
} else {
    Write-Host "   ❌ Web Client ID non trouvé dans login_screen.dart" -ForegroundColor Red
}
Write-Host ""

# Résumé
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📋 RÉSUMÉ DE LA CONFIGURATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "SHA-1 Release: $sha1Match" -ForegroundColor White
Write-Host "Package Name:  $packageMatch" -ForegroundColor White
Write-Host "Web Client ID: $clientIdMatch" -ForegroundColor White
Write-Host ""
Write-Host "✅ VÉRIFICATIONS À FAIRE DANS GOOGLE CLOUD CONSOLE:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Créer un client OAuth Android avec:" -ForegroundColor White
Write-Host "   - Package name: be.jirig.app" -ForegroundColor Cyan
Write-Host "   - SHA-1: $sha1Match" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Vérifier le client OAuth Web:" -ForegroundColor White
Write-Host "   - Client ID: $clientIdMatch" -ForegroundColor Cyan
Write-Host "   - Redirect URI: https://jirig.be/api/auth/google-mobile" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Attendre 5-10 minutes après modification" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Rebuilder l'APK:" -ForegroundColor White
Write-Host "   flutter clean" -ForegroundColor Cyan
Write-Host "   flutter build apk --release" -ForegroundColor Cyan
Write-Host ""

