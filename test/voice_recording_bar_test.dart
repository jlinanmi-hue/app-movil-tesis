import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:app_tesis/screens/ai_chat/widgets/voice_recording_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VoiceRecordingBar muestra todos los elementos visuales estilo Web', (tester) async {
    bool cancelTapped = false;
    bool sendTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: VoiceRecordingBar(
                recordingSeconds: 5,
                onCancel: () => cancelTapped = true,
                onSend: () => sendTapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // 1. Botón descartar con ícono de papelera
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    // 2. Temporizador "00:05" y límite "/ 2:00"
    expect(find.text('00:05'), findsOneWidget);
    expect(find.text('/ 2:00'), findsOneWidget);

    // 3. Botón de envío circular con avión de papel
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // 4. Barras del waveform generadas
    expect(find.byKey(const ValueKey('wave_bar_0')), findsOneWidget);

    // 5. Interacción: Tocar descartar
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    expect(cancelTapped, isTrue);

    // 6. Interacción: Tocar enviar
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sendTapped, isTrue);
  });

  testWidgets('VoiceRecordingBar reacciona a tiempo urgente (>= 100s) y stream de amplitud', (tester) async {
    final amplitudeController = StreamController<Amplitude>.broadcast();
    addTearDown(amplitudeController.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 380,
              child: VoiceRecordingBar(
                recordingSeconds: 105,
                onCancel: () {},
                onSend: () {},
                amplitudeStream: amplitudeController.stream,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Formato de 105 segundos: 01:45
    expect(find.text('01:45'), findsOneWidget);

    // Verificar estilo de color urgente (rojo 0xFFDC2626)
    final timerText = tester.widget<Text>(find.text('01:45'));
    expect(timerText.style?.color, const Color(0xFFDC2626));

    // Emitir amplitud de voz
    amplitudeController.add(Amplitude(current: -15.0, max: -2.0));
    await tester.pump(const Duration(milliseconds: 60));

    // Verificar que la barra 0 existe y está renderizada correctamente
    expect(find.byKey(const ValueKey('wave_bar_0')), findsOneWidget);
  });
}
