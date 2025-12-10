# Jayantslist

A professional marketplace Flutter application with an elegant splash screen.

## Features

- Professional splash screen with animated fade-in effect
- Custom-drawn elephant logo using Flutter CustomPainter
- Gradient background matching the design mockup
- Classic typography using Google Fonts (Playfair Display & Lato)
- Smooth navigation transitions
- Material Design 3 implementation

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- iOS Simulator / Android Emulator / Physical Device

### Installation

1. Navigate to the project directory:
```bash
cd "/Users/shivam/Documents/CDIS_App_Projects/Connector's"
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   ├── splash_screen.dart   # Splash screen with branding
│   └── home_screen.dart     # Main home screen
└── widgets/
    └── elephant_logo.dart   # Custom elephant logo painter
```

## Design Features

- **Colors**: 
  - Background: Deep blue gradient (#2B5876 → #1e3c72 → #0f2027)
  - Accent: Gold (#D4AF37)
  
- **Typography**:
  - App name: Playfair Display (42px, semi-bold)
  - Tagline: Lato (14px, regular)
  - Launch text: Lato (16px, light)

- **Animations**:
  - Fade-in animation on splash screen
  - Smooth page transitions

## License

This project is private and confidential.
