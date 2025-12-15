# 🎬 Animations Login Screen

## 🎨 Style : **"Elegant Entry"**

---

## ✨ Vue d'ensemble

La page Login utilise des animations **élégantes et accueillantes** pour créer une **première impression premium**.

| Élément | Animation | Durée | Courbe |
|---------|-----------|-------|--------|
| 📱 **AppBar** | Slide from top + Fade | 600ms | `easeOutCubic` |
| 🎯 Logo | Scale + Rotation | 1200ms | `elasticOut` + `easeOutBack` |
| 📝 Titres + Formulaire | Slide + Fade | 800ms | `easeOutCubic` + `easeIn` |
| 🔘 Boutons sociaux | Staggered slide | 800-950ms | `easeOutCubic` |
| 📄 Footer | Fade | 600ms | `easeOut` |

**Durée totale** : ~1.5 secondes

---

## 🎨 Nouveauté : AppBar bleue animée

**Couleur** : `Color(0xFF0051BA)` - Bleu Jirig principal  
**Animation** : Descend depuis le haut (20px) avec fade  
**Effet** : L'AppBar "glisse" dans l'écran ⬇️

```dart
TweenAnimationBuilder<double>(
  duration: const Duration(milliseconds: 600),
  offset: Offset(0, -20) → Offset.zero, // Descend de 20px
  opacity: 0 → 1,
)
```

---

## 🎯 Animations détaillées

### 1. Logo (Scale + Rotation twist)

```dart
ScaleTransition(
  scale: _logoScaleAnimation, // 0.0 → 1.0, elasticOut
  child: Transform.rotate(
    angle: _logoRotationAnimation.value, // -0.1 → 0.0 rad (~-6° → 0°)
  ),
)
```

**Effet** : Le logo "explose" avec un bounce élastique et fait un petit twist ! 💫

---

### 2. Titres + Formulaire (Slide from bottom)

```dart
FadeTransition(
  opacity: _formFadeAnimation, // 0 → 1
  child: SlideTransition(
    position: Offset(0, 0.3) → Offset.zero, // Monte de 30%
  ),
)
```

**Effet** : Monte doucement avec fade 🌊

---

### 3. Boutons sociaux (Cascade)

```dart
// Google: 800ms
// Facebook: 950ms (+150ms)
TweenAnimationBuilder(
  duration: 800 + (index * 150)ms,
  offset: Offset(0, 15) → Offset.zero, // Slide 15px
)
```

**Effet** : Cascade fluide depuis le bas ⬆️

---

## 🎭 Séquence

```
   0ms → 🎯 Logo commence (bounce + twist)
 400ms → 📝 Formulaire commence
 800ms → 🔘 Boutons + Footer commencent
1450ms → ✅ Terminé
```

**Total : ~1.5s**

---

## 🏆 Effet signature

**Logo twist** 🎯 - Seule rotation 2D de l'app !

---

**Créé le** : 18 octobre 2025  
**Package** : `animations: ^2.0.11`  
**Développeur** : Jirig Team

