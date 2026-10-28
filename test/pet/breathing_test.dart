import 'package:flutter_test/flutter_test.dart';
import 'package:nb_selfcare/features/pet_gamification/domain/breathing.dart';

void main() {
  group('Respiración guiada', () {
    test('la duración se redondea a respiraciones enteras', () {
      expect(BreathingSession(pattern: BreathingPattern.box, minutes: 1).cycles, 4); // 64 s
      expect(BreathingSession(pattern: BreathingPattern.coherence, minutes: 1).totalSeconds, 60);
      expect(BreathingSession(pattern: BreathingPattern.relax, minutes: 1).cycles, 3); // 57 s
      expect(BreathingSession(pattern: BreathingPattern.triangle, minutes: 5).cycles, 25);
      expect(BreathingSession(pattern: BreathingPattern.box, minutes: 0).cycles, 1);
    });

    test('caja 4-4-4-4: fases, cuenta atrás y pulmones', () {
      final BreathingSession s = BreathingSession(pattern: BreathingPattern.box, minutes: 1);
      final BreathingMoment start = s.at(0);
      expect(start.phase, BreathPhase.inhale);
      expect(start.secondsLeftInPhase, 4);
      expect(start.lung, 0);
      expect(start.cycle, 1);

      expect(s.at(3.5).secondsLeftInPhase, 1);
      expect(s.at(4.2).phase, BreathPhase.holdIn);
      expect(s.at(4.2).lung, 1);
      expect(s.at(10).phase, BreathPhase.exhale);
      expect(s.at(10).lung, inExclusiveRange(0, 1));
      expect(s.at(13).phase, BreathPhase.holdOut);
      expect(s.at(13).lung, 0);
      expect(s.at(16.5).cycle, 2);
      expect(s.at(16.5).phase, BreathPhase.inhale);
    });

    test('los pulmones suben y bajan sin saltos', () {
      for (final BreathingPattern p in BreathingPattern.all) {
        final BreathingSession s = BreathingSession(pattern: p, minutes: 1);
        double prev = s.at(0).lung;
        for (int i = 1; i <= s.totalSeconds * 30; i++) {
          final double lung = s.at(i / 30).lung;
          expect(lung, inInclusiveRange(0, 1), reason: '${p.id} ${i / 30}');
          expect((lung - prev).abs(), lessThan(0.15), reason: '${p.id} ${i / 30}');
          prev = lung;
        }
      }
    });

    test('termina al completar la última exhalación', () {
      final BreathingSession s = BreathingSession(pattern: BreathingPattern.relax, minutes: 1);
      expect(s.at(s.totalSeconds - 0.1).done, isFalse);
      final BreathingMoment end = s.at(s.totalSeconds.toDouble());
      expect(end.done, isTrue);
      expect(end.remainingSeconds, 0);
      expect(end.progress, 1);
      expect(end.cycle, s.cycles);
    });

    test('tiempos absurdos no rompen nada', () {
      final BreathingSession s = BreathingSession(pattern: BreathingPattern.box, minutes: 3);
      for (final double t in <double>[-5, double.nan, double.infinity, 1e9]) {
        final BreathingMoment m = s.at(t);
        expect(m.lung.isFinite, isTrue, reason: '$t');
        expect(m.progress, inInclusiveRange(0, 1), reason: '$t');
      }
    });

    test('ritmos legibles', () {
      expect(BreathingPattern.box.rhythm, '4-4-4-4');
      expect(BreathingPattern.relax.rhythm, '4-7-8');
      expect(BreathingPattern.triangle.rhythm, '4-4-4');
    });
  });
}
