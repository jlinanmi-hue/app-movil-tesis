import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// ============================================================================
/// ERP UI · Sistema de diseño propio (Comercial Valencia)
/// Estilo MATE y plano: solo CELESTE + BLANCO, sin degradados ni brillos.
///   · Cabecera de marca plana con franja de acento inferior
///   · Botones, pestañas y filtros rectangulares con borde capilar
///   · Relleno sólido solo en la acción primaria / selección
///   · Tarjetas, tablas y campos sin sombras de color
///   · Calendario tematizado celeste
/// ============================================================================

// ---------------------------------------------------------------------------
// CABECERA
// ---------------------------------------------------------------------------

/// Cabecera única de pantalla/hub: degradado celeste→blanco, título fuerte,
/// subtítulo y acciones. Sin AppBar genérico.
class ErpHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;
  final double hPad;

  const ErpHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.showBack = true,
    this.onBack,
    this.hPad = 16,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.celesteDeep, width: 3),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, bottom == null ? 14 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBack && canPop) ...[
                    ErpCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      tooltip: 'Regresar',
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .85),
                              letterSpacing: -0.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              if (bottom != null) ...[
                const SizedBox(height: 12),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular blanco con sombra suave (regresar, acciones de cabecera).
class ErpCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const ErpCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 38,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(icon,
          size: size * .46,
          color: AppColors.isDark ? AppColors.celeste : AppColors.celesteDeep),
    );
    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * .28),
        child: btn,
      ),
    );
    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip!, child: tappable);
  }
}

// ---------------------------------------------------------------------------
// PESTAÑAS SEGMENTADAS (píldora animada)
// ---------------------------------------------------------------------------

class ErpTabSpec {
  final String label;
  final IconData? icon;
  const ErpTabSpec(this.label, {this.icon});
}

/// Control segmentado para TabController (usa DefaultTabController si no se
/// pasa uno). Indicador tipo píldora con degradado celeste.
class ErpSegmentedTabs extends StatefulWidget {
  final List<ErpTabSpec> tabs;
  final TabController? controller;
  final EdgeInsetsGeometry margin;

  const ErpSegmentedTabs({
    super.key,
    required this.tabs,
    this.controller,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<ErpSegmentedTabs> createState() => _ErpSegmentedTabsState();
}

class _ErpSegmentedTabsState extends State<ErpSegmentedTabs> {
  TabController? _c;

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = widget.controller ?? DefaultTabController.of(context);
    if (!identical(c, _c)) {
      _c?.removeListener(_sync);
      _c = c;
      _c!.addListener(_sync);
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final index = c?.index ?? 0;
    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.celesteBg.withValues(alpha: .9)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < widget.tabs.length; i++)
              _pill(
                i,
                selected: i == index,
                onTap: () {
                  HapticFeedback.selectionClick();
                  c?.animateTo(i);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(int i, {required bool selected, required VoidCallback onTap}) {
    final t = widget.tabs[i];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(right: i == widget.tabs.length - 1 ? 0 : 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.celesteDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.icon != null) ...[
              Icon(
                t.icon,
                size: 15,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              t.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMuted,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Píldora de selección simple (tabs internos de listas, filtros rápidos).
class ErpChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const ErpChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.celesteDeep : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.celesteDeep : AppColors.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de píldoras de selección (wrapper de [ErpChoicePill]).
class ErpFilterPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const ErpFilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ErpChoicePill(
                label: o,
                selected: o == selected,
                onTap: () => onSelect(o),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CAMPOS: BUSCADOR · COMBO · FECHA
// ---------------------------------------------------------------------------

/// Buscador tipo píldora: relleno celeste suave, se ilumina al enfocar.
class ErpSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onClear;
  final bool loading;

  const ErpSearchField({
    super.key,
    required this.controller,
    this.hint = 'Buscar...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.loading = false,
  });

  @override
  State<ErpSearchField> createState() => _ErpSearchFieldState();
}

class _ErpSearchFieldState extends State<ErpSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? AppColors.celesteDark : AppColors.hairline,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 19, color: AppColors.celesteDark),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              onFocusChange: (f) => setState(() => _focused = f),
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSubmitted?.call(),
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (widget.loading)
            Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.celesteDark),
              ),
            ),
          if (hasText)
            GestureDetector(
              onTap: () {
                if (widget.onClear != null) {
                  widget.onClear!();
                } else {
                  widget.controller.clear();
                  widget.onChanged?.call('');
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.celesteTint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.celesteBg),
                ),
                child: Icon(Icons.close_rounded,
                    size: 14, color: AppColors.celesteDeep),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class ErpDropdownOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  const ErpDropdownOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// Combo: campo plano que abre una hoja inferior con las opciones.
class ErpDropdownField<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<ErpDropdownOption<T>> options;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final bool enabled;

  const ErpDropdownField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint,
    this.icon = Icons.expand_more_rounded,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    ErpDropdownOption<T>? sel;
    for (final o in options) {
      if (o.value == value) {
        sel = o;
        break;
      }
    }
    final activo = sel != null;
    final field = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activo ? AppColors.celesteDark : AppColors.hairline,
          width: activo ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.celesteDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: activo ? AppColors.celesteDeep : AppColors.textMuted,
                    letterSpacing: .2,
                  ),
                ),
                Text(
                  sel?.label ?? hint ?? 'Elegir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                    color: activo ? AppColors.textDark : AppColors.textSubtle,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more_rounded,
              size: 18, color: AppColors.celesteDark),
        ],
      ),
    );
    if (!enabled) {
      return Opacity(opacity: .55, child: field);
    }
    return GestureDetector(onTap: () => _open(context), child: field);
  }

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      barrierColor: AppColors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * .62,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const ErpDragHandle(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 18),
                    children: [
                      for (final o in options)
                        _opcion(ctx, o, o.value == value),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _opcion(BuildContext ctx, ErpDropdownOption<T> o, bool selected) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        onChanged(o.value);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.celesteTint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.celesteBg : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.celesteDeep : AppColors.textDark,
                    ),
                  ),
                  if (o.subtitle != null && o.subtitle!.isNotEmpty)
                    Text(
                      o.subtitle!,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  size: 18, color: AppColors.celesteDeep),
          ],
        ),
      ),
    );
  }
}

/// Campo de fecha plano; abre el calendario del sistema tematizado.
class ErpDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  /// Texto que se muestra cuando aún no hay fecha (ej. "Sin fecha").
  final String emptyLabel;

  /// Rango permitido del calendario.
  final DateTime? minima;
  final DateTime? maxima;

  const ErpDateField({
    super.key,
    required this.label,
    required this.onPick,
    this.value,
    this.emptyLabel = 'Todas',
    this.minima,
    this.maxima,
  });

  @override
  Widget build(BuildContext context) {
    final activo = value != null;
    return GestureDetector(
      onTap: () async {
        final d = await erpCalendario(context,
            inicial: value, minima: minima, maxima: maxima);
        if (d != null) onPick(d);
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo ? AppColors.celesteDark : AppColors.hairline,
            width: activo ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 16,
                color: activo ? AppColors.celesteDeep : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color:
                          activo ? AppColors.celesteDeep : AppColors.textMuted,
                      letterSpacing: .2,
                    ),
                  ),
                  Text(
                    value == null
                        ? emptyLabel
                        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year % 100}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                      color:
                          activo ? AppColors.textDark : AppColors.textSubtle,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (activo)
              GestureDetector(
                onTap: () => onPick(null),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.celesteTint,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.celesteBg),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 13, color: AppColors.celesteDeep),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Calendario tematizado (celeste + blanco, esquinas redondeadas).
Future<DateTime?> erpCalendario(
  BuildContext context, {
  DateTime? inicial,
  DateTime? minima,
  DateTime? maxima,
}) {
  final hoy = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: inicial ?? hoy,
    firstDate: minima ?? DateTime(2020),
    lastDate: maxima ?? DateTime(hoy.year + 1, 12, 31),
    helpText: 'Selecciona una fecha',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        datePickerTheme: DatePickerThemeData(
          backgroundColor: AppColors.surfaceLight,
          surfaceTintColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          headerBackgroundColor: AppColors.celesteDark,
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
          headerHelpStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .85),
          ),
          weekdayStyle: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
          dayStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          dayShape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          dayBackgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return AppColors.celesteDark;
            return Colors.transparent;
          }),
          dayForegroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return Colors.white;
            return AppColors.textDark;
          }),
          dayOverlayColor:
              WidgetStatePropertyAll(AppColors.celesteTint),
          todayBorder:
              BorderSide(color: AppColors.celesteDark, width: 1.4),
          yearStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          yearShape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          yearBackgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return AppColors.celesteTint;
            return Colors.transparent;
          }),
          yearForegroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return AppColors.celesteDeep;
            return AppColors.textDark;
          }),
          dividerColor: Colors.transparent,
          cancelButtonStyle: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(AppColors.textMuted),
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          confirmButtonStyle: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(AppColors.celesteDeep),
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      child: child!,
    ),
  );
}

// ---------------------------------------------------------------------------
// BOTONES
// ---------------------------------------------------------------------------

/// Botón principal: plano, relleno celeste sólido y esquinas rectas.
class ErpPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool expand;

  const ErpPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;
    final content = GestureDetector(
      onTap: disabled
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap!.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.celesteBg.withValues(alpha: .55)
              : AppColors.celesteDeep,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            else if (icon != null)
              Icon(icon, size: 19, color: Colors.white),
            if (loading || icon != null) const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: disabled ? AppColors.textSubtle : Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: content) : content;
  }
}

/// Botón secundario: plano, fondo blanco con borde capilar.
class ErpSoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expand;

  const ErpSoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!.call();
            },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: AppColors.celesteDeep),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.celesteDeep,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: content) : content;
  }
}

/// Botón compacto para acciones de modales: plano, esquinas rectas y sin
/// sombra. Con [primary] se rellena de celeste sólido (texto blanco); sin
/// él queda "outline" (fondo blanco + borde capilar). Usa [danger] para
/// acciones destructivas (rojo).
class ErpPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool expand;
  final double height;

  const ErpPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.primary = false,
    this.danger = false,
    this.expand = true,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? Colors.white
        : danger
            ? AppColors.errorDark
            : AppColors.celesteDeep;
    final content = GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!.call();
            },
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: primary ? AppColors.celesteDeep : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: primary
              ? null
              : Border.all(
                  color: danger ? AppColors.errorBorder : AppColors.hairline,
                ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: content) : content;
  }
}

// ---------------------------------------------------------------------------
// SUPERFICIES
// ---------------------------------------------------------------------------

/// Tarjeta plana: blanca, esquinas rectas y borde capilar (sin sombra).
class ErpSoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const ErpSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Marco de tabla: borde capilar, esquinas rectas y cabecera celeste.
class ErpTableFrame extends StatelessWidget {
  final Widget child;

  const ErpTableFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Icono en azulejo celeste plano (filas, detalles).
class ErpIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double radius;

  const ErpIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.radius = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.celesteBg.withValues(alpha: .8)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.celesteDeep, size: size * .46),
    );
  }
}

/// Check propio: cuadro plano con relleno celeste y animación.
class ErpCheck extends StatelessWidget {
  final bool value;
  final VoidCallback? onChanged;
  final double size;

  const ErpCheck({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged!.call();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? AppColors.celesteDeep : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(
            color: value ? AppColors.celesteDeep : AppColors.hairline,
            width: 1.4,
          ),
        ),
        child: value
            ? Icon(Icons.check_rounded,
                size: size * .68, color: Colors.white)
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Estado vacío consistente: icono en azulejo plano + textos.
class ErpEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final EdgeInsetsGeometry padding;

  const ErpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.padding = const EdgeInsets.only(top: 70),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.celesteTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.celesteBg),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 32, color: AppColors.celesteDeep),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asa de hojas inferiores (bottom sheets).
class ErpDragHandle extends StatelessWidget {
  const ErpDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.celesteBg,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
