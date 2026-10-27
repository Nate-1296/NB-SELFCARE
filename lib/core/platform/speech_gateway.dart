import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado de voz **solo en el dispositivo** (docs/01 §4, flujo 2). Si el
/// teléfono no ofrece reconocimiento sin conexión, el dictado no se activa:
/// nunca se envía audio a un servicio en la nube.
abstract interface class SpeechGateway {
  Future<bool> isOnDeviceAvailable();

  /// Empieza a escuchar en español. [onText] recibe el texto parcial y final.
  Future<bool> start({required void Function(String text, bool isFinal) onText});

  Future<void> stop();
}

class OnDeviceSpeechGateway implements SpeechGateway {
  OnDeviceSpeechGateway();

  static const MethodChannel _system = MethodChannel('com.nb.selfcare/system');
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  @override
  Future<bool> isOnDeviceAvailable() async {
    try {
      return await _system.invokeMethod<bool>('isOnDeviceSpeechAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> start({required void Function(String text, bool isFinal) onText}) async {
    if (!await isOnDeviceAvailable()) return false;
    try {
      _initialized = _initialized || await _speech.initialize();
      if (!_initialized) return false;
      final String? spanish = (await _speech.locales())
          .map((LocaleName l) => l.localeId)
          .where((String id) => id.toLowerCase().startsWith('es'))
          .firstOrNull;
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
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_initialized) await _speech.stop();
  }
}

final speechGatewayProvider = Provider<SpeechGateway>((Ref ref) => OnDeviceSpeechGateway());
