import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  /// Inicia la grabacion de audio en formato .m4a (AAC LC)
  Future<bool> startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('[VoiceRecorder] Permiso de microfono no otorgado');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final voiceDir = Directory('${tempDir.path}/voice_notes');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }

      final path = '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path;
      _recordingStartTime = DateTime.now();

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('[VoiceRecorder] Error al iniciar grabacion: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Detiene la grabacion y retorna la ruta del archivo generado
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('[VoiceRecorder] Error al detener grabacion: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancela y descarta la grabacion actual
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.cancel();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('[VoiceRecorder] Error al cancelar grabacion: $e');
    } finally {
      _isRecording = false;
      _currentRecordingPath = null;
    }
  }

  Duration get currentDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
