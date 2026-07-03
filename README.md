# EchoRead (Novel Reader)

Application Flutter Android-first pour extraire et lire le texte de pages web de type novel.

Design importé depuis le projet Google Stitch **Audio Web Reader** (EchoRead).

## Prérequis

- Flutter 3.44.4+ / Dart 3.12+
- Android SDK (priorité) ou Xcode pour iOS
- Connexion Internet

## Installation

```bash
cd /Users/taissirmohamed/Documents/Projets/novel_reader
flutter pub get
```

## Lancement Android

```bash
flutter devices
flutter run -d android
```

## Lancement iOS (simulateur)

```bash
flutter run -d "iPhone 16"
```

> Flutter 3.44+ utilise **Swift Package Manager** pour les plugins iOS (plus de CocoaPods). Si vous voyez encore des avertissements CocoaPods, exécutez `cd ios && pod deintegrate` puis supprimez `Podfile` et le dossier `Pods`.

## Utilisation

1. Ouvrir l’application **EchoRead**
2. Coller l’URL d’un chapitre novel
3. Appuyer sur **Charger**
4. Lire le texte extrait avec réglage de taille et mode sombre

## Limites connues (MVP)

- Extraction via HTTP + parsing HTML (pas de rendu JavaScript)
- Les sites 100 % dynamiques peuvent renvoyer une erreur « contenu introuvable »
- Pas de bibliothèque locale, historique ni navigation chapitre suivant/précédent

## Design

- Tokens : [`DESIGN.md`](DESIGN.md)
- Source Stitch : `projects/8324331772808102895` (Audio Web Reader)
- Fichiers cache : `.stitch-*.json`, `.stitch-source.html`

## Structure

```
lib/
├── app.dart
├── main.dart
├── core/theme/app_theme.dart
├── features/home/home_screen.dart
├── features/reader/reader_screen.dart
└── services/novel_extractor.dart
```
