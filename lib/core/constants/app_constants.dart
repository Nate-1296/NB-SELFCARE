/// Constantes globales del sistema NB Selfcare.
abstract final class AppConstants {
  static const String appName = 'NB Selfcare';
  static const String appPackage = 'com.nb.selfcare';
  static const String appVersion = '0.1.0';
  static const int appBuildNumber = 1;

  // Persistencia
  static const String databaseFileName = 'nb_selfcare.sqlite';

  // Biometría y Fisiología
  static const double defaultEmaAlpha = 0.1;
  static const double waterRetentionWeightDeltaKg = 0.40;
  static const double highSodiumThresholdMg = 2500.0;
  static const double glycogenSupercompensationFactor = 1.30;
  static const double biaWaterShiftThresholdPercent = 0.40;

  // TDEE Adaptativo
  static const int adaptiveTdeeWindowDays = 14;
  static const int adaptiveTdeeMinFoodLogDays = 10;
  static const int adaptiveTdeeMinWeighInDays = 6;
  static const double kcalPerKgBodyFat = 7700.0;
  static const int maxWeeklyTdeeAdjustmentKcal = 150;

  // Gamificación y Mascota
  static const String defaultPetName = 'Nibi';
  static const int initialCoinsBalance = 50;
  static const int initialStreakShields = 1;
  static const double goodSleepMultiplier = 1.5;
  static const int localAiMemoryTtlSeconds = 120;

  // Monedas por acción
  static const int coinsWeighIn = 15;
  static const int coinsMealLog = 10;
  static const int maxDailyMealLogCoins = 30;
  static const int coinsWaterGoal = 15;
  static const int coinsFastDone = 20;
  static const int coinsJournalEntry = 10;

  // Costo tienda
  static const int costShield1Day = 40;
  static const int costShieldWeekend = 100;
}

