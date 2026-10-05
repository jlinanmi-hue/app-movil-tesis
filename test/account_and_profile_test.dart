import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tesis/core/services/session_service.dart';
import 'package:app_tesis/models/user_model.dart';
import 'package:app_tesis/screens/account/account_screen.dart';
import 'package:app_tesis/screens/account/personal_data_screen.dart';
import 'package:app_tesis/screens/account/account_security_screen.dart';
import 'package:app_tesis/screens/account/user_role_info_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.init();

    final mockUser = UserModel(
      usuarioId: 'usr-999',
      userName: 'jvalencia',
      rol: 'Administrador General',
      token: 'jwt-test-token',
      empleado: EmpleadoModel(
        id: 'EMP-042',
        nombres: 'Jhonatan',
        apellidos: 'Valencia',
        correo: 'jhonatan@valencia.com',
        dni: '72819283',
        telefono: '987654321',
        sexo: 'M',
        cargo: 'Gerente Comercial',
        fechaIngreso: '2024-01-15',
      ),
    );
    await SessionService.saveSession(mockUser);
  });

  testWidgets('AccountScreen muestra perfil limpio sin KPIs y opciones separadas', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verificación de cabecera y datos de usuario
    expect(find.text('Mi Cuenta'), findsOneWidget);
    expect(find.text('Jhonatan Valencia'), findsOneWidget);
    expect(find.text('Gerente Comercial • Comercial Valencia'), findsOneWidget);
    expect(find.text('EMP-042'), findsOneWidget);
    expect(find.text('@jvalencia'), findsOneWidget);

    // Verificación estricta: NO deben existir banners de KPIs en la pantalla de Cuenta
    expect(find.text('Indicador PODE'), findsNothing);
    expect(find.text('≥ 95.0%'), findsNothing);
    expect(find.text('Órdenes Hoy'), findsNothing);
    expect(find.text('14 Flujo'), findsNothing);
    expect(find.text('Sistema IA'), findsNothing);

    // Verificación de las opciones del menú independientes
    expect(find.text('Datos del Colaborador'), findsOneWidget);
    expect(find.text('Seguridad & Contraseña'), findsOneWidget);
    expect(find.text('Información del Usuario'), findsOneWidget);
    expect(find.text('Infraestructura y Red'), findsOneWidget);
    expect(find.text('Valencia AI & Preferencias'), findsOneWidget);
    expect(find.text('Acerca del Sistema'), findsOneWidget);
    expect(find.text('Cerrar Sesión'), findsOneWidget);
  });

  testWidgets('PersonalDataScreen muestra exclusivamente los datos personales y ningún rol ni contraseña', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersonalDataScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Título y datos de cabecera
    expect(find.text('Datos del Colaborador'), findsOneWidget);
    expect(find.text('Jhonatan Valencia'), findsOneWidget);
    expect(find.text('EMP-042'), findsOneWidget);
    expect(find.text('@jvalencia'), findsOneWidget);

    // Campos exclusivos de formulario personal
    expect(find.text('Mis Datos Personales'), findsOneWidget);
    expect(find.text('Jhonatan'), findsOneWidget);
    expect(find.text('Valencia'), findsOneWidget);
    expect(find.text('72819283'), findsOneWidget);
    expect(find.text('987654321'), findsOneWidget);
    expect(find.text('jhonatan@valencia.com'), findsOneWidget);
    expect(find.text('Masculino'), findsOneWidget);
    expect(find.text('Femenino'), findsOneWidget);
    expect(find.text('Guardar Mis Datos'), findsOneWidget);

    // Verificación estricta: NO debe contener roles ni contraseñas
    expect(find.text('Rol y Cargo Asignados'), findsNothing);
    expect(find.text('Seguridad de la Cuenta'), findsNothing);
    expect(find.text('Actualizar Contraseña'), findsNothing);
  });

  testWidgets('AccountSecurityScreen muestra exclusivamente actualización de correo y contraseña', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountSecurityScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seguridad & Contraseña'), findsOneWidget);
    expect(find.text('Seguridad de la Cuenta'), findsOneWidget);
    expect(find.text('Correo Electrónico de la Cuenta *'), findsOneWidget);
    expect(find.text('jhonatan@valencia.com'), findsOneWidget);
    expect(find.text('Nueva Contraseña'), findsOneWidget);
    expect(find.text('Confirmar Nueva Contraseña'), findsOneWidget);
    expect(find.text('Actualizar Credenciales'), findsOneWidget);

    // Verificación estricta: NO debe contener nombres, DNI ni roles
    expect(find.text('Mis Datos Personales'), findsNothing);
    expect(find.text('DNI / Documento *'), findsNothing);
    expect(find.text('Rol y Cargo Asignados'), findsNothing);
  });

  testWidgets('UserRoleInfoScreen muestra exclusivamente rol, cargo y fecha de ingreso institucional', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserRoleInfoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Información del Usuario'), findsOneWidget);
    expect(find.text('Jhonatan Valencia'), findsOneWidget);
    expect(find.text('Rol y Cargo Asignados'), findsOneWidget);
    expect(find.text('Cargo Institucional'), findsOneWidget);
    expect(find.text('Gerente Comercial'), findsOneWidget);
    expect(find.text('Rol de Acceso / Permiso'), findsOneWidget);
    expect(find.text('Administrador General'), findsOneWidget);
    expect(find.text('Fecha de Ingreso Oficial'), findsOneWidget);
    expect(find.text('2024-01-15'), findsOneWidget);

    // Verificación estricta: NO debe contener formularios ni botones de guardado
    expect(find.text('Mis Datos Personales'), findsNothing);
    expect(find.text('Guardar Mis Datos'), findsNothing);
    expect(find.text('Actualizar Contraseña'), findsNothing);
  });

  testWidgets('Navegación independiente desde AccountScreen a cada una de las 3 vistas', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Navegar a Datos del Colaborador
    await tester.tap(find.text('Datos del Colaborador'));
    await tester.pumpAndSettle();
    expect(find.text('Mis Datos Personales'), findsOneWidget);
    expect(find.text('Rol y Cargo Asignados'), findsNothing);

    // Regresar
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // 2. Navegar a Seguridad & Contraseña
    await tester.tap(find.text('Seguridad & Contraseña'));
    await tester.pumpAndSettle();
    expect(find.text('Seguridad de la Cuenta'), findsOneWidget);
    expect(find.text('Mis Datos Personales'), findsNothing);

    // Regresar
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // 3. Navegar a Información del Usuario
    await tester.tap(find.text('Información del Usuario'));
    await tester.pumpAndSettle();
    expect(find.text('Rol y Cargo Asignados'), findsOneWidget);
    expect(find.text('Mis Datos Personales'), findsNothing);
  });
}

