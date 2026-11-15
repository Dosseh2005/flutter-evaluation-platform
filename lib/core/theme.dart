import 'package:flutter/material.dart';

/// Couleurs de l'application (« salle d'examen » : encre sur papier).
abstract final class Couleurs {
  /// Encre : titres, boutons principaux, barre de navigation admin.
  static const encre = Color(0xFF1B2A4A);

  /// Encre plus claire : survol, éléments actifs sur fond encre.
  static const encreClaire = Color(0xFF2E4372);

  /// Papier : fond général des pages.
  static const papier = Color(0xFFF6F7F9);

  /// Surface : fond des panneaux, champs et tableaux.
  static const surface = Color(0xFFFFFFFF);

  /// Ligne : bordures fines et séparateurs.
  static const ligne = Color(0xFFDDE1E8);

  /// Texte secondaire : explications, dates, aides.
  static const texteSecondaire = Color(0xFF5B6476);

  /// Réussite : test réussi, bonne réponse (côté admin).
  static const reussite = Color(0xFF0F7B6C);

  /// Fond doux associé à la réussite.
  static const reussiteFond = Color(0xFFE3F2EF);

  /// Échec et urgence : test échoué, chrono presque fini, erreurs.
  static const alerte = Color(0xFFB42318);

  /// Fond doux associé à l'échec.
  static const alerteFond = Color(0xFFFBE9E7);

  /// Sélection d'une réponse pendant le test.
  static const selection = Color(0xFFE8EDF7);
}

/// Nom de la police (déclarée dans pubspec.yaml).
const policeApp = 'IBM Plex Sans';

/// Rayon des coins des champs, boutons et lignes de réponse.
const rayonPetit = 8.0;

/// Rayon des coins des panneaux.
const rayonPanneau = 12.0;

/// Style des chiffres alignés (chrono, scores) : tous les chiffres ont la
/// même largeur, le chrono ne « bouge » donc pas à chaque seconde.
const chiffresAlignes = [FontFeature.tabularFigures()];

/// Thème commun à toute l'application (Material 3).
ThemeData construireTheme() {
  const schema = ColorScheme(
    brightness: Brightness.light,
    primary: Couleurs.encre,
    onPrimary: Colors.white,
    primaryContainer: Couleurs.selection,
    onPrimaryContainer: Couleurs.encre,
    secondary: Couleurs.reussite,
    onSecondary: Colors.white,
    secondaryContainer: Couleurs.reussiteFond,
    onSecondaryContainer: Couleurs.reussite,
    error: Couleurs.alerte,
    onError: Colors.white,
    errorContainer: Couleurs.alerteFond,
    onErrorContainer: Couleurs.alerte,
    surface: Couleurs.surface,
    onSurface: Couleurs.encre,
    onSurfaceVariant: Couleurs.texteSecondaire,
    surfaceContainerLowest: Couleurs.surface,
    surfaceContainerLow: Couleurs.papier,
    surfaceContainer: Couleurs.papier,
    surfaceContainerHigh: Color(0xFFEEF0F4),
    surfaceContainerHighest: Color(0xFFE6E9EF),
    outline: Couleurs.ligne,
    outlineVariant: Couleurs.ligne,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    fontFamily: policeApp,
    scaffoldBackgroundColor: Couleurs.papier,
    visualDensity: VisualDensity.standard,
  );

  // Échelle typographique : peu de tailles, des graisses franches.
  final texte = base.textTheme
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
        ),
        headlineMedium: const TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        headlineSmall: const TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.55),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Couleurs.texteSecondaire,
        ),
        labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      )
      .apply(
        fontFamily: policeApp,
        bodyColor: Couleurs.encre,
        displayColor: Couleurs.encre,
      );

  final bordure = OutlineInputBorder(
    borderRadius: BorderRadius.circular(rayonPetit),
    borderSide: const BorderSide(color: Couleurs.ligne),
  );

  return base.copyWith(
    textTheme: texte,
    appBarTheme: const AppBarTheme(
      backgroundColor: Couleurs.surface,
      foregroundColor: Couleurs.encre,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: policeApp,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Couleurs.encre,
      ),
      shape: Border(bottom: BorderSide(color: Couleurs.ligne)),
    ),
    cardTheme: CardThemeData(
      color: Couleurs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonPanneau),
        side: const BorderSide(color: Couleurs.ligne),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Couleurs.ligne, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Couleurs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: bordure,
      enabledBorder: bordure,
      focusedBorder: bordure.copyWith(
        borderSide: const BorderSide(color: Couleurs.encre, width: 2),
      ),
      errorBorder: bordure.copyWith(
        borderSide: const BorderSide(color: Couleurs.alerte),
      ),
      focusedErrorBorder: bordure.copyWith(
        borderSide: const BorderSide(color: Couleurs.alerte, width: 2),
      ),
      labelStyle: const TextStyle(color: Couleurs.texteSecondaire),
      floatingLabelStyle: const TextStyle(color: Couleurs.encre),
      helperStyle: const TextStyle(color: Couleurs.texteSecondaire),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
        textStyle: const TextStyle(
          fontFamily: policeApp,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        disabledBackgroundColor: const Color(0xFFE6E9EF),
        disabledForegroundColor: const Color(0xFF9AA2B1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: Couleurs.encre,
        side: const BorderSide(color: Couleurs.ligne),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
        textStyle: const TextStyle(
          fontFamily: policeApp,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Couleurs.encre,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
        textStyle: const TextStyle(
          fontFamily: policeApp,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Couleurs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonPanneau),
      ),
      titleTextStyle: texte.titleLarge,
      contentTextStyle: texte.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Couleurs.encre,
      contentTextStyle: const TextStyle(
        fontFamily: policeApp,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      width: 440,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Couleurs.encre,
      unselectedLabelColor: Couleurs.texteSecondaire,
      indicatorColor: Couleurs.encre,
      dividerColor: Couleurs.ligne,
      labelStyle: TextStyle(fontFamily: policeApp, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontFamily: policeApp,
        fontWeight: FontWeight.w500,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Couleurs.encre,
      indicatorColor: Couleurs.encreClaire,
      selectedIconTheme: IconThemeData(color: Colors.white),
      unselectedIconTheme: IconThemeData(color: Color(0xFFAEB8CC)),
      selectedLabelTextStyle: TextStyle(
        fontFamily: policeApp,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: policeApp,
        color: Color(0xFFAEB8CC),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: texte.titleSmall?.copyWith(
        color: Couleurs.texteSecondaire,
      ),
      dataTextStyle: texte.bodyMedium,
      headingRowColor: const WidgetStatePropertyAll(Couleurs.papier),
      dividerThickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Couleurs.encre,
      linearTrackColor: Couleurs.ligne,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}
