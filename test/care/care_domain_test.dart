import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/core/domain/care_enums.dart';
import 'package:nb_selfcare/core/domain/enums.dart';
import 'package:nb_selfcare/features/care/domain/active_break_catalog.dart';
import 'package:nb_selfcare/features/care/domain/checkup_catalog.dart';
import 'package:nb_selfcare/features/care/domain/guided_sequence.dart';
import 'package:nb_selfcare/features/care/domain/pelvic_floor_program.dart';
import 'package:nb_selfcare/features/care/domain/substance_catalog.dart';
import 'package:nb_selfcare/features/care/domain/symptom_catalog.dart';
import 'package:nb_selfcare/features/care/domain/treatment_schedule.dart';
import 'package:nb_selfcare/features/care/domain/vital_ranges.dart';
import 'package:nb_selfcare/features/care/domain/wellbeing_index.dart';
import 'package:nb_selfcare/features/today/domain/sleep_regularity.dart';

void main() {
  group('Secuencia guiada', () {
    test('avanza paso a paso y termina sin pasarse', () {
      final GuidedSequence<String> s = GuidedSequence<String>(const <GuidedStep<String>>[
        GuidedStep<String>('a', 3),
        GuidedStep<String>('vacío', 0),
        GuidedStep<String>('b', 2),
      ]);
      expect(s.steps.length, 2, reason: 'Los pasos de 0 s se descartan');
      expect(s.totalSeconds, 5);
      expect(s.at(0).step.cue, 'a');
      expect(s.at(0).secondsLeftInStep, 3);
      expect(s.at(2.9).step.cue, 'a');
      expect(s.at(3.1).step.cue, 'b');
      expect(s.at(3.1).index, 1);
      expect(s.at(99).done, isTrue);
      expect(s.at(99).progress, 1);
      expect(s.at(double.nan).index, 0);
      expect(s.at(-4).remainingSeconds, 5);
    });

    test('una secuencia vacía no se puede crear', () {
      expect(() => GuidedSequence<String>(const <GuidedStep<String>>[]), throwsArgumentError);
    });
  });

  group('Suelo pélvico', () {
    test('cada nivel descansa al menos lo que aprieta y termina relajando', () {
      for (final PelvicLevel l in PelvicLevel.all) {
        final GuidedSequence<PelvicCue> s =
            PelvicFloorProgram.session(variant: PelvicVariant.program, level: l.level);
        final List<GuidedStep<PelvicCue>> steps = s.steps;
        for (int i = 0; i < steps.length - 1; i++) {
          if (steps[i].cue == PelvicCue.squeeze) {
            expect(steps[i + 1].cue, PelvicCue.release);
            expect(steps[i + 1].seconds, greaterThanOrEqualTo(steps[i].seconds));
          }
        }
        expect(steps.last.cue, PelvicCue.lengthenExhale);
        expect(steps.where((GuidedStep<PelvicCue> s) => s.cue == PelvicCue.squeeze).length, l.slowReps);
        expect(s.totalSeconds, lessThan(7 * 60), reason: 'Sesión corta (nivel ${l.level})');
      }
    });

    test('"Solo relajar" no tiene contracciones', () {
      final GuidedSequence<PelvicCue> s = PelvicFloorProgram.session(variant: PelvicVariant.relaxOnly, level: 3);
      expect(s.steps.any((GuidedStep<PelvicCue> st) => PelvicFloorProgram.isEffort(st.cue)), isFalse);
    });

    test('propone subir de nivel tras seis sesiones y nunca pasa del 5', () {
      expect(PelvicFloorProgram.suggestedNextLevel(current: 1, sessionsAtLevel: 5), isNull);
      expect(PelvicFloorProgram.suggestedNextLevel(current: 1, sessionsAtLevel: 6), 2);
      expect(PelvicFloorProgram.suggestedNextLevel(current: 5, sessionsAtLevel: 40), isNull);
      expect(PelvicLevel.of(0).level, 1);
      expect(PelvicLevel.of(9).level, 5);
    });
  });

  group('Pausas activas', () {
    test('cada rutina dura de 1 a 3 minutos y tiene identificador único', () {
      final Set<String> ids = <String>{};
      for (final ActiveBreakRoutine r in ActiveBreakRoutine.all) {
        expect(r.totalSeconds, inInclusiveRange(60, 180), reason: r.id);
        expect(ids.add(r.id), isTrue);
        expect(r.sequence().totalSeconds, r.totalSeconds);
      }
      expect(ActiveBreakRoutine.byId('no-existe').id, ActiveBreakRoutine.neckShoulders.id);
    });
  });

  group('Chequeos preventivos', () {
    test('se proponen según edad y sexo', () {
      final List<String> woman30 =
          CheckupCatalog.suggestedFor(BiologicalSex.female, 30).map((CheckupSpec s) => s.key).toList();
      expect(woman30, containsAll(<String>['dental', 'cervical', 'blood_pressure']));
      expect(woman30, isNot(contains('mammography')));
      expect(woman30, isNot(contains('prostate')));

      final List<String> man55 =
          CheckupCatalog.suggestedFor(BiologicalSex.male, 55).map((CheckupSpec s) => s.key).toList();
      expect(man55, containsAll(<String>['prostate', 'colorectal']));
      expect(man55, isNot(contains('cervical')));
    });

    test('la citología es cada 3 años antes de los 30 y cada 5 después', () {
      final CheckupSpec cervical = CheckupCatalog.byKey('cervical')!;
      expect(cervical.intervalFor(27), 36);
      expect(cervical.intervalFor(35), 60);
    });

    test('estado: sin registrar, al día, pronto y ya toca', () {
      final DateTime today = DateTime(2026, 10, 28);
      expect(
        CheckupDue.evaluate(lastDone: null, intervalMonths: 12, today: today).status,
        CheckupStatus.neverDone,
      );
      expect(
        CheckupDue.evaluate(lastDone: DateTime(2026, 3, 1), intervalMonths: 12, today: today).status,
        CheckupStatus.upToDate,
      );
      final CheckupDue soon = CheckupDue.evaluate(lastDone: DateTime(2025, 11, 10), intervalMonths: 12, today: today);
      expect(soon.status, CheckupStatus.dueSoon);
      expect(soon.daysUntil, 13);
      expect(
        CheckupDue.evaluate(lastDone: DateTime(2024, 1, 1), intervalMonths: 12, today: today).status,
        CheckupStatus.due,
      );
    });
  });

  group('Tratamientos', () {
    test('horas: ordenadas, sin repetir y tolerantes a JSON roto', () {
      expect(TreatmentSchedule.decodeTimes('[1200, 480, 480, -5, 9999]'), <int>[480, 1200]);
      expect(TreatmentSchedule.decodeTimes('no es json'), isEmpty);
      expect(TreatmentSchedule.decodeTimes('{"a":1}'), isEmpty);
      expect(TreatmentSchedule.encodeTimes(<int>[600, 480, 600]), '[480,600]');
    });

    test('tomas del día con su estado (la última marca manda)', () {
      final List<DoseSlot> slots = TreatmentSchedule.slotsFor(
        treatmentId: 1,
        times: <int>[480, 1200],
        daysMask: 127,
        weekday: DateTime.wednesday,
        records: const <DoseRecord>[
          DoseRecord(treatmentId: 1, slotMinutes: 480, taken: true),
          DoseRecord(treatmentId: 2, slotMinutes: 1200, taken: true),
        ],
      );
      expect(slots.map((DoseSlot s) => s.status), <DoseStatus>[DoseStatus.taken, DoseStatus.pending]);

      final List<DoseSlot> anytime = TreatmentSchedule.slotsFor(
        treatmentId: 3,
        times: const <int>[],
        daysMask: 127,
        weekday: 1,
        records: const <DoseRecord>[DoseRecord(treatmentId: 3, slotMinutes: null, taken: false)],
      );
      expect(anytime.single.slotMinutes, isNull);
      expect(anytime.single.status, DoseStatus.skipped);
    });

    test('solo los días marcados', () {
      // Lunes, miércoles y viernes.
      const int mask = 1 | 4 | 16;
      expect(TreatmentSchedule.appliesOn(mask, DateTime.monday), isTrue);
      expect(TreatmentSchedule.appliesOn(mask, DateTime.tuesday), isFalse);
      expect(
        TreatmentSchedule.slotsFor(
          treatmentId: 1,
          times: <int>[480],
          daysMask: mask,
          weekday: DateTime.sunday,
          records: const <DoseRecord>[],
        ),
        isEmpty,
      );
    });

    test('días de reserva según tomas y días activos', () {
      expect(
        TreatmentSchedule.daysOfStockLeft(stockUnits: 30, unitsPerDose: 1, dosesPerDay: 2, daysMask: 127),
        15,
      );
      // Tres días por semana: rinde más.
      expect(
        TreatmentSchedule.daysOfStockLeft(stockUnits: 6, unitsPerDose: 1, dosesPerDay: 1, daysMask: 1 | 4 | 16),
        14,
      );
      expect(
        TreatmentSchedule.daysOfStockLeft(stockUnits: null, unitsPerDose: 1, dosesPerDay: 1, daysMask: 127),
        isNull,
      );
    });
  });

  group('Signos vitales', () {
    test('tensión arterial (AHA 2017)', () {
      expect(VitalRanges.bloodPressure(115, 75), VitalBand.normal);
      expect(VitalRanges.bloodPressure(125, 78), VitalBand.elevated);
      expect(VitalRanges.bloodPressure(135, 85), VitalBand.high);
      expect(VitalRanges.bloodPressure(185, 100), VitalBand.consultSoon);
      expect(VitalRanges.bloodPressure(85, 55), VitalBand.low);
    });

    test('glucosa según el momento', () {
      expect(VitalRanges.glucose(92, GlucoseContext.fasting), VitalBand.normal);
      expect(VitalRanges.glucose(110, GlucoseContext.fasting), VitalBand.elevated);
      expect(VitalRanges.glucose(130, GlucoseContext.fasting), VitalBand.high);
      expect(VitalRanges.glucose(130, GlucoseContext.afterMeal), VitalBand.normal);
      expect(VitalRanges.glucose(62, GlucoseContext.random), VitalBand.low);
      expect(VitalRanges.glucose(40, GlucoseContext.random), VitalBand.consultSoon);
      expect(GlucoseContext.fromKey(null), GlucoseContext.random);
    });

    test('oxígeno y temperatura', () {
      expect(VitalRanges.oxygen(97), VitalBand.normal);
      expect(VitalRanges.oxygen(93), VitalBand.elevated);
      expect(VitalRanges.oxygen(88), VitalBand.consultSoon);
      expect(VitalRanges.temperature(36.6), VitalBand.normal);
      expect(VitalRanges.temperature(37.6), VitalBand.elevated);
      expect(VitalRanges.temperature(38.4), VitalBand.high);
      expect(VitalRanges.temperature(40), VitalBand.consultSoon);
    });

    test('rechaza valores imposibles', () {
      expect(VitalRanges.isPlausible(VitalKind.bloodPressure, 120, 80), isTrue);
      expect(VitalRanges.isPlausible(VitalKind.bloodPressure, 80, 120), isFalse);
      expect(VitalRanges.isPlausible(VitalKind.bloodPressure, 120, null), isFalse);
      expect(VitalRanges.isPlausible(VitalKind.oxygen, 101, null), isFalse);
      expect(VitalRanges.isPlausible(VitalKind.temperature, 98.6, null), isFalse, reason: 'Fahrenheit');
      expect(VitalRanges.isPlausible(VitalKind.glucose, 5.5, null), isFalse, reason: 'mmol/L');
    });
  });

  group('OMS-5', () {
    test('puntuación 0–100 y bandas', () {
      expect(WellbeingIndex.percent(<int>[5, 5, 5, 5, 5]), 100);
      expect(WellbeingIndex.percent(<int>[0, 0, 0, 0, 0]), 0);
      expect(WellbeingIndex.percent(<int>[3, 3, 3, 3, 3]), 60);
      expect(WellbeingIndex.band(80), WellbeingBand.flourishing);
      expect(WellbeingIndex.band(60), WellbeingBand.good);
      expect(WellbeingIndex.band(40), WellbeingBand.low);
      expect(WellbeingIndex.band(20), WellbeingBand.veryLow);
      expect(WellbeingIndex.suggestsSupport(28), isTrue);
      expect(WellbeingIndex.suggestsSupport(32), isFalse);
      expect(() => WellbeingIndex.percent(<int>[1, 2]), throwsArgumentError);
    });
  });

  group('Alcohol y tabaco', () {
    test('bebidas estándar de 10 g', () {
      final SubstancePreset beer = SubstancePreset.byKey('beer')!;
      expect(beer.standardDrinks, closeTo(1.17, 0.01));
      expect(SubstancePreset.byKey('spirit')!.standardDrinks, closeTo(0.83, 0.01));
      expect(SubstancePreset.byKey('cigarette')!.standardDrinks, 0);
      expect(SubstancePreset.byKey('nada'), isNull);
    });

    test('la tendencia solo celebra bajar', () {
      expect(const WeeklyTrend(thisWeek: 4, lastWeek: 8).reductionPercent, 50);
      expect(const WeeklyTrend(thisWeek: 9, lastWeek: 8).isLower, isFalse);
      expect(const WeeklyTrend(thisWeek: 0, lastWeek: 0).isLower, isFalse);
    });
  });

  group('Síntomas', () {
    test('el catálogo se adapta a la persona', () {
      final List<String> man = SymptomCatalog.forPerson(sex: BiologicalSex.male, age: 50, cycleTracking: false);
      expect(man, isNot(contains('hot_flashes')));
      expect(man, isNot(contains('cramps')));
      final List<String> woman =
          SymptomCatalog.forPerson(sex: BiologicalSex.female, age: 47, cycleTracking: true);
      expect(woman, containsAll(<String>['cramps', 'hot_flashes']));
      expect(SymptomCatalog.isCatalog('migraine'), isTrue);
      expect(SymptomCatalog.isCatalog('Me duele el codo'), isFalse);
    });
  });

  group('Regularidad del sueño', () {
    SleepNight night(int wake) => SleepNight(durationMinutes: 480, wakeMinutes: wake);

    test('necesita cinco noches', () {
      expect(SleepRegularity.from(<SleepNight>[night(420), night(420)]), isNull);
    });

    test('horario estable = muy regular; cruza medianoche sin romperse', () {
      final SleepRegularity r = SleepRegularity.from(<SleepNight>[for (int i = 0; i < 7; i++) night(420 + i)])!;
      expect(r.band, SleepRegularityBand.veryRegular);
      // Puntos medios alrededor de medianoche (dormir 20:00–04:00 ± 20 min).
      final SleepRegularity midnight = SleepRegularity.from(<SleepNight>[
        night(230),
        night(250),
        night(240),
        night(225),
        night(255),
      ])!;
      expect(midnight.spreadMinutes, lessThan(30));
    });

    test('fines de semana muy distintos = variable', () {
      final SleepRegularity r = SleepRegularity.from(<SleepNight>[
        night(390),
        night(390),
        night(390),
        night(390),
        night(390),
        night(660),
        night(690),
      ])!;
      expect(r.band, SleepRegularityBand.variable);
    });
  });

  group('Listas del perfil', () {
    test('JSON roto o claves desconocidas no rompen nada', () {
      expect(ProfileSets.careModules('esto no es json'), isEmpty);
      expect(ProfileSets.careModules('["treatments","marciano"]'), <CareModule>{CareModule.treatments});
      expect(ProfileSets.vitalDevices('["glucose"]'), <VitalKind>{VitalKind.glucose});
      expect(
        ProfileSets.encodeModules(<CareModule>{CareModule.habits, CareModule.treatments}),
        '["treatments","habits"]',
      );
    });
  });
}
