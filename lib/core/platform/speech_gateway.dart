import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'native_call.dart';

/// Dictado de voz **solo en el dispositivo** (docs/05 §5). Si el
/// teléfono no ofrece reconocimiento sin conexión, el dictado no se activa:
/// nunca se envía audio a un servicio en la nube.
abstract interface class SpeechGateway {
  Future<bool> isOnDeviceAvailable();

  /// Empieza a escuchar en español. [onText] recibe el texto parcial y final;
  /// [onDone] avisa cuando el micrófono se cierra por cualquier motivo
  /// (silencio, error, fin del dictado), haya habido texto o no.
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required void Function() onDone,
  });

  Future<void> stop();
}

class OnDeviceSpeechGateway implements SpeechGateway {
  OnDeviceSpeechGateway();

  static const MethodChannel _system = MethodChannel('com.nb.selfcare/system');
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  void Function()? _onDone;

  void _finish() {
    final void Function()? done = _onDone;
    _onDone = null;
    done?.call();
  }

  @override
  Future<bool> isOnDeviceAvailable() async {
    return await callNative<bool>(_system, 'isOnDeviceSpeechAvailable') ?? false;
  }

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onText,
    required void Function() onDone,
  }) async {
    if (!await isOnDeviceAvailable()) return false;
    try {
      _initialized = _initialized ||
          await _speech.initialize(
            // "done"/"notListening" llegan también cuando no se dijo nada.
            onStatus: (String status) {
              if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) _finish();
            },
            onError: (_) => _finish(),
          );
      if (!_initialized) return false;
      final String? spanish = (await _speech.locales())
          .map((LocaleName l) => l.localeId)
          .where((String id) => id.toLowerCase().startsWith('es'))
          .firstOrNull;
      _onDone = onDone;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: spanish,
          onDevice: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
        onResult: (SpeechRecognitionResult r) => onText(r.recognizedWords, r.finalResult),
      );
      return true;
    } on PlatformException {
      _onDone = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_initialized) await _speech.stop();
  }
}

final speechGatewayProvider = Provider<SpeechGateway>((Ref ref) => OnDeviceSpeechGateway());
