import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'erp_ui.dart';

/// Fundamento responsive exigido:
/// SafeArea (notch/barras) + LayoutBuilder (espacio real) + MediaQuery (ventana).
/// Estilo propio celeste + blanco (Comercial Valencia).

class Responsive {
  static bool isTablet(BoxConstraints c) => c.maxWidth >= 600;
  static bool isDesktop(BoxConstraints c) => c.maxWidth >= 1000;

  static int gridCount(BoxConstraints c, {int phone = 1, int tablet = 2, int desktop = 3}) {
    if (c.maxWidth >= 1000) return desktop;
    if (c.maxWidth >= 600) return tablet;
    return phone;
  }

  static double hPad(BuildContext context, BoxConstraints c) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1000) return 32;
    if (c.maxWidth >= 600) return 24;
    return 16;
  }
}

/// Scaffold responsive estándar: cabecera de marca con degradado celeste + scroll adaptativo.
class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? fab;
  final bool showBack;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.fab,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: fab,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Decisiones por espacio real, no por tipo de dispositivo.
          final pad = Responsive.hPad(context, constraints);
          return Column(
            children: [
              ErpHeader(
                title: title,
                subtitle: subtitle,
                actions: actions ?? const [],
                showBack: showBack,
                hPad: pad,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
                  child: body,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
