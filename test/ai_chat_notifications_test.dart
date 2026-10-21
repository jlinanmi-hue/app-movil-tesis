import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tesis/core/services/notification_service.dart';
import 'package:app_tesis/core/theme/app_theme.dart';
import 'package:app_tesis/core/widgets/notification_bell_widget.dart';
import 'package:app_tesis/screens/ai_chat/ai_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.unreadCountNotifier.value = 4;
  });

  tearDown(() {
    NotificationService.instance.unreadCountNotifier.value = 0;
  });

  testWidgets('el chat muestra la campana conectada a las notificaciones reales',
      (tester) async {
    const recorderChannel = MethodChannel('com.llfbandit.record/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, (call) async => null);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, null);
    });

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Theme(
            data: AppTheme.fixedLightTheme,
            child: const AiChatScreen(isModal: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chat = find.byType(AiChatScreen);
    expect(chat, findsOneWidget);
    expect(find.text('En línea • IA generativa'), findsOneWidget);

    final bell = find.descendant(
      of: chat,
      matching: find.byType(NotificationBellWidget),
    );
    expect(bell, findsOneWidget);
    expect(find.descendant(of: bell, matching: find.text('4')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
