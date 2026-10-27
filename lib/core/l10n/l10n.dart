import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  /// Textos localizados de la app (plantilla: `lib/core/l10n/arb/app_es.arb`).
  AppLocalizations get l10n => AppLocalizations.of(this);
}
