import 'package:flutter/material.dart';

/// Fundamento responsive exigido:
/// SafeArea (notch/barras) + LayoutBuilder (espacio real) + MediaQuery (ventana).
/// Estilo Campus Cash adaptado a CELESTE + BLANCO.

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

/// Scaffold responsive estándar: SafeArea + scroll adaptativo.
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
      backgroundColor: Colors.white,
      floatingActionButton: fab,
      body: SafeArea(
        // Protege de notch, cámara y barras del sistema. No duplica padding.
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Decisiones por espacio real, no por tipo de dispositivo.
            final pad = Responsive.hPad(context, constraints);
            return Column(
              children: [
                _Header(
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                  showBack: showBack,
                  pad: pad,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
                    child: body,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final double pad;

  const _Header({
    required this.title,
    this.subtitle,
    this.actions,
    required this.showBack,
    required this.pad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
      child: Row(
        children: [
          if (showBack && Navigator.canPop(context))
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCAF0F8)),
              ),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF0096C7), size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A3642),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF4A7C8E)),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
