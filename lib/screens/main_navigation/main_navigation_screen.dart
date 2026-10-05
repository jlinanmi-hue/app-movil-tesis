import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../account/account_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/indicators_screen.dart';
import '../erp/operaciones_hub_screen.dart';

/// Navegación principal integrada (Comercial Valencia)
/// Flujo optimizado: Inicio • Operaciones ERP • Valencia AI • Métricas • Cuenta
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      DashboardScreen(onNavigate: _onTabTapped),
      const OperacionesHubScreen(),
      const IndicatorsScreen(),
      const AccountScreen(),
    ];
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),

          // Barra flotante integrada moderna
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  8 + bottomInset * 0.2,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Base blanca de la barra flotante con sombra suave
                    Container(
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.celesteBg,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.celesteDark
                                .withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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
                          const SizedBox(width: 68),
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

                    // Botón central prominente de Valencia AI con Isotipo Oficial
                    Positioned(
                      top: -22,
                      child: GestureDetector(
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
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.celeste,
                                        AppColors.celesteDark,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.celesteDark
                                            .withValues(alpha: 0.38),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
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
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
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
                      ),
                    ),
                  ],
                ),
              ),
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
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.celesteTint
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected
                  ? AppColors.celesteDark
                  : AppColors.textSubtle,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.celesteDark
                    : AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
