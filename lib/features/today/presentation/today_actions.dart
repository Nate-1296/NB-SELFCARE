import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../nutrition_hydration/application/food_logging_service.dart';
import '../../nutrition_hydration/application/hydration_service.dart';
import '../application/daily_activity_service.dart';

/// Acciones de un toque de la pantalla Hoy, con confirmación y Deshacer.
class TodayActions {
  const TodayActions(this._ref, this._context);

  final WidgetRef _ref;
  final BuildContext _context;

  Future<void> logWater({required String dateKey, required int volumeMl}) async {
    unawaited(HapticFeedback.lightImpact());
    final HydrationService service = _ref.read(hydrationServiceProvider);
    final WaterLogResult result = await service.logGlass(dateKey: dateKey, volumeMl: volumeMl);
    if (!_context.mounted) return;
    final AppLocalizations l10n = _context.l10n;
    showUndoSnackBar(
      _context,
      message: result.coins > 0
          ? l10n.todayWaterLoggedGoal(volumeMl, result.coins)
          : l10n.todayWaterLogged(volumeMl),
      onUndo: () => unawaited(service.deleteGlass(result.logId)),
    );
  }

  Future<void> undoGlass(HydrationLog glass) async {
    unawaited(HapticFeedback.selectionClick());
    final HydrationService service = _ref.read(hydrationServiceProvider);
    await service.deleteGlass(glass.id);
    if (!_context.mounted) return;
    showUndoSnackBar(
      _context,
      message: _context.l10n.todayWaterRemoved(glass.volumeMl),
      onUndo: () => unawaited(service.restoreGlass(glass)),
    );
  }

  Future<void> addSteps({required String dateKey, required int currentSteps, int amount = 1000}) async {
    unawaited(HapticFeedback.lightImpact());
    final DailyActivityService activity = _ref.read(dailyActivityServiceProvider);
    final int updated = currentSteps + amount;
    await activity.setSteps(dateKey: dateKey, steps: updated);
    if (!_context.mounted) return;
    showUndoSnackBar(
      _context,
      message: _context.l10n.todayStepsAdded(amount, updated),
      onUndo: () => unawaited(activity.setSteps(dateKey: dateKey, steps: currentSteps)),
    );
  }

  Future<void> repeatYesterday(String dateKey) async {
    unawaited(HapticFeedback.lightImpact());
    final FoodLoggingService service = _ref.read(foodLoggingServiceProvider);
    final FoodLogResult result = await service.repeatYesterday(toDateKey: dateKey);
    if (!_context.mounted) return;
    final AppLocalizations l10n = _context.l10n;
    showUndoSnackBar(
      _context,
      message: result.isEmpty
          ? l10n.todayRepeatNothing
          : l10n.todayRepeatDone(result.logIds.length),
      onUndo: result.isEmpty ? null : () => unawaited(service.deleteLogs(result.logIds)),
    );
  }
}
