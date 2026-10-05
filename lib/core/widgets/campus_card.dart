import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// UI Kit estilo Campus Cash pero solo CELESTE + BLANCO.
/// Cards rounded 20-24, sombras suaves, progress bars, filas tipo lista.

class CampusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  const CampusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted ? AppColors.celeste : AppColors.celesteBg,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.celesteDark.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CampusHeroCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final VoidCallback? onAction;
  final String actionLabel;

  const CampusHeroCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.onAction,
    this.actionLabel = 'Ver detalle',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3642), AppColors.celesteDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.celesteDark.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.75)),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.celesteDark)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 13, color: AppColors.celesteDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

class CampusProgress extends StatelessWidget {
  final double value; // 0..1
  const CampusProgress({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: AppColors.celesteBg,
        valueColor:
            const AlwaysStoppedAnimation<Color>(AppColors.celeste),
      ),
    );
  }
}

class CampusListRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final String? badge;
  final double? progress;
  final VoidCallback? onTap;

  const CampusListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.badge,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final b = badge?.toLowerCase().trim() ?? '';
    Color badgeBg = AppColors.celesteTint;
    Color badgeFg = AppColors.celesteDark;
    Color badgeBorder = AppColors.celesteBg;

    if (b.contains('activo') ||
        b.contains('complet') ||
        b.contains('aprob') ||
        b.contains('despach') ||
        b.contains('entreg')) {
      badgeBg = const Color(0xFFECFDF5);
      badgeFg = const Color(0xFF059669);
      badgeBorder = const Color(0xFFA7F3D0);
    } else if (b.contains('pend') ||
        b.contains('proceso') ||
        b.contains('valid') ||
        b.contains('prep')) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFFD97706);
      badgeBorder = const Color(0xFFFDE68A);
    } else if (b.contains('inactiv') ||
        b.contains('anul') ||
        b.contains('cancel') ||
        b.contains('elimin') ||
        b.contains('riesg')) {
      badgeBg = const Color(0xFFFEF2F2);
      badgeFg = const Color(0xFFDC2626);
      badgeBorder = const Color(0xFFFECACA);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.celesteTint, Color(0xFFE0F7FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.celesteBg, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.celesteDark, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (progress != null && progress! > 0) ...[
                    const SizedBox(height: 6),
                    CampusProgress(value: progress!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing.isNotEmpty)
                  Text(
                    trailing,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                if (badge != null && badge!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: badgeBorder, width: 0.8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}

class CampusKpiRow extends StatelessWidget {
  final List<CampusKpi> kpis;
  const CampusKpiRow({super.key, required this.kpis});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: cols == 2 ? 1.6 : 1.4,
          ),
          itemCount: kpis.length,
          itemBuilder: (_, i) {
            final k = kpis[i];
            return CampusCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(k.icon,
                      size: 18, color: AppColors.celesteDark),
                  const SizedBox(height: 6),
                  Text(k.value,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  Text(k.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CampusKpi {
  final IconData icon;
  final String value;
  final String label;
  CampusKpi({required this.icon, required this.value, required this.label});
}
