import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'erp_ui.dart';

/// UI Kit propio (CELESTE + BLANCO): cards suaves, filas tipo lista.

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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? AppColors.celesteDark : AppColors.hairline,
          width: highlighted ? 1.5 : 1,
        ),
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
        color: AppColors.celesteDeep,
        borderRadius: BorderRadius.all(Radius.circular(12)),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.celesteDark)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
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
              borderRadius: BorderRadius.circular(12),
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
  final VoidCallback? onTap;

  const CampusListRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.badge,
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
      badgeBg = AppColors.successBg;
      badgeFg = AppColors.successDark;
      badgeBorder = AppColors.successBorder;
    } else if (b.contains('pend') ||
        b.contains('proceso') ||
        b.contains('valid') ||
        b.contains('prep')) {
      badgeBg = AppColors.warningBg;
      badgeFg = AppColors.warningDark;
      badgeBorder = AppColors.warningBorder;
    } else if (b.contains('inactiv') ||
        b.contains('anul') ||
        b.contains('cancel') ||
        b.contains('elimin') ||
        b.contains('riesg')) {
      badgeBg = AppColors.errorBg;
      badgeFg = AppColors.error;
      badgeBorder = AppColors.errorBorder;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: LayoutBuilder(
          builder: (context, c) {
            // La columna derecha se limita a ~45% de la fila (máx. 220 px):
            // textos largos (p. ej. el giro del proveedor) se recortan con
            // "…" en lugar de desbordar el layout.
            final maxTrailing =
                (c.maxWidth * .45).clamp(0.0, 220.0).toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ErpIconTile(icon: icon, size: 40, radius: 13),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTrailing),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trailing.isNotEmpty)
                        Text(
                          trailing,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      if (badge != null && badge!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(5),
                            border:
                                Border.all(color: badgeBorder, width: 0.8),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: badgeFg,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSubtle,
                ),
              ],
            );
          },
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
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                  Text(k.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
