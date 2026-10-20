import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../account/account_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/indicators_screen.dart';
import '../erp/operaciones_hub_screen.dart';

/// Navegación principal integrada (Comercial Valencia)
/// Barra inferior SÓLIDA (blanca, a todo el ancho, anclada al borde):
/// Inicio • Operaciones • Valencia AI (botón central) • Métricas • Cuenta.
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late final List<Widget> _screens;
  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _screens = [
      DashboardScreen(onNavigate: _onTabTapped),
      const OperacionesHubScreen(),
      Theme(
        data: AppTheme.fixedLightTheme,
        child: const IndicatorsScreen(),
      ),
      const AccountScreen(),
    ];
    ThemeService.darkNotifier.addListener(_onThemeChanged);

    // Heartbeat de sesión única activa (cada 15 segundos)
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (SessionService.isLoggedIn) {
        ApiService().verifySession();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && SessionService.isLoggedIn) {
      ApiService().verifySession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    ThemeService.darkNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  void _onCenterActionTapped() {
    HapticFeedback.mediumImpact();
    AiChatScreen.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // La clave fuerza a reconstruir las pestañas al cambiar de
          // apariencia; la pestaña activa se conserva en este State.
          IndexedStack(
            key: ValueKey(AppColors.isDark),
            index: _currentIndex,
            children: _screens,
          ),

          // Barra sólida integrada (ya no flota)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(context),
          ),
        ],
      ),
    );
  }

  /// Barra de navegación sólida y mate: blanca, a todo el ancho, pegada al
  /// borde inferior, con borde capilar y sin sombras de color.
  /// Los ítems se centran con ancho máximo para tabletas y el botón central
  /// de IA se integra elevado sobre el centro.
  Widget _bottomBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(
                    index: 0,
                    iconOutlined: Icons.home_outlined,
                    iconFilled: Icons.home_rounded,
                    label: 'Inicio',
                  ),
                  _buildNavItem(
                    index: 1,
                    iconOutlined: Icons.storefront_outlined,
                    iconFilled: Icons.storefront_rounded,
                    label: 'Operaciones',
                  ),
                  // Espacio para el botón central de IA
                  const SizedBox(width: 72),
                  _buildNavItem(
                    index: 2,
                    iconOutlined: Icons.insights_outlined,
                    iconFilled: Icons.insights_rounded,
                    label: 'Métricas',
                  ),
                  _buildNavItem(
                    index: 3,
                    iconOutlined: Icons.person_outline_rounded,
                    iconFilled: Icons.person_rounded,
                    label: 'Cuenta',
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: -24, child: _aiButton()),
        ],
      ),
    );
  }

  /// Botón central prominente de Valencia AI con el isotipo oficial.
  Widget _aiButton() {
    return GestureDetector(
      onTap: _onCenterActionTapped,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.celesteDeep,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.isDark ? AppColors.hairline : Colors.white,
                    width: 3.5,
                  ),
                ),
                alignment: Alignment.center,
                child: const ValenciaBotIcon(
                  size: 27,
                  headColor: Colors.white,
                  visorColor: Color(0xFF0F172A),
                  eyeColor: Color(0xFF38BDF8),
                ),
              ),
              // Baliza pulsante online
              Container(
                margin: const EdgeInsets.only(top: 2, right: 2),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.navSurface,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Valencia AI',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: AppColors.celesteDark,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData iconOutlined,
    required IconData iconFilled,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 13 : 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.celesteDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? Colors.white : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
