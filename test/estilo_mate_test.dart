import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/core/constants/app_colors.dart';
import 'package:app_tesis/core/widgets/erp_ui.dart';

/// Regresión del lenguaje visual MATE: superficies planas, sin degradados
/// ni sombras de color. Si algún widget vuelve a "brillar", esta prueba
/// debe fallar.
void main() {
  BoxDecoration decoracionDe(WidgetTester tester, Type tipo) {
    final contenedor = tester.widget<Container>(
      find
          .descendant(of: find.byType(tipo), matching: find.byType(Container))
          .first,
    );
    return contenedor.decoration! as BoxDecoration;
  }

  testWidgets('Botones del sistema: planos, sin gradiente ni sombra',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ErpPrimaryButton(label: 'Guardar', onTap: () {}),
              ErpPillButton(label: 'Eliminar', danger: true, onTap: () {}),
              ErpSoftButton(label: 'Cancelar', onTap: () {}),
            ],
          ),
        ),
      ),
    );

    final primario = decoracionDe(tester, ErpPrimaryButton);
    expect(primario.gradient, isNull);
    expect(primario.color, AppColors.celesteDeep);
    expect(primario.boxShadow ?? const [], isEmpty);

    final peligro = decoracionDe(tester, ErpPillButton);
    expect(peligro.gradient, isNull);
    expect(peligro.color, Colors.white);
    expect(peligro.border, isNotNull);

    final suave = decoracionDe(tester, ErpSoftButton);
    expect(suave.gradient, isNull);
    expect(suave.color, Colors.white);
    expect(suave.border, isNotNull);
  });

  testWidgets('Tarjetas y azulejos: borde capilar y cero sombra',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ErpSoftCard(child: Text('hola')),
              ErpIconTile(icon: Icons.inventory_2_outlined),
            ],
          ),
        ),
      ),
    );

    final tarjeta = decoracionDe(tester, ErpSoftCard);
    expect(tarjeta.gradient, isNull);
    expect(tarjeta.border, isNotNull);
    expect(tarjeta.boxShadow ?? const [], isEmpty);

    final azulejo = decoracionDe(tester, ErpIconTile);
    expect(azulejo.gradient, isNull);
    expect(azulejo.color, AppColors.celesteTint);
  });

  testWidgets('Cabecera: plana con franja de acento inferior', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErpHeader(title: 'Prueba')),
      ),
    );

    final cabecera = decoracionDe(tester, ErpHeader);
    expect(cabecera.gradient, isNull);
    expect(cabecera.color, AppColors.celesteDark);
    expect(cabecera.border, isNotNull);
  });
}
