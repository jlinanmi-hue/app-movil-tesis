import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/notification_service.dart';
import '../../../models/chat_message_model.dart';
import '../../notifications/notifications_sheet.dart';

const Color _ink = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const Color _teal = Color(0xFF008F9D);
const Color _tealDark = Color(0xFF007785);
const Color _hairline = Color(0xFFD6E8ED);

final RegExp _entityCodeRegex = RegExp(
  r'^(?:PED|OC|AJU|NOT|PROD|CLI|PRV|MOV)-\d+(?:-\d+)?$',
  caseSensitive: false,
);

/// Renderizador visual de las respuestas de Valencia AI.
///
/// Convierte el markdown sencillo que devuelve el bot en bloques legibles:
/// títulos, subsecciones, tarjetas de resumen con viñetas, listas numeradas,
/// códigos de entidad (OC, PED, AJU...), montos y cantidades.
/// Si la respuesta habla de notificaciones, muestra un acceso directo a la
/// bandeja real de la app.
class AiMessageContentWidget extends StatelessWidget {
  final ChatMessageModel message;
  final bool isStreaming;

  const AiMessageContentWidget({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = message.text.trim();
    if (text.isEmpty) {
      return isStreaming
          ? _buildStreamingPlaceholder()
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!message.isUser && _mentionsNotifications(text)) ...[
          const _NotificationShortcut(),
          const SizedBox(height: 10),
        ],
        _buildParsedContent(text),
        if (!message.isUser && !isStreaming) ...[
          const SizedBox(height: 8),
          _buildFooter(context, text),
        ],
      ],
    );
  }

  // =========================================================================
  // BLOQUES DE CONTENIDO
  // =========================================================================

  Widget _buildParsedContent(String text) {
    final lines = text.split('\n');
    final blocks = <Widget>[];

    void add(Widget block, {double gap = 7}) {
      if (blocks.isNotEmpty) blocks.add(SizedBox(height: gap));
      blocks.add(block);
    }

    var i = 0;
    while (i < lines.length) {
      final raw = lines[i];
      final trimmed = raw.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      if (_isHorizontalRule(trimmed)) {
        add(Container(height: 1, color: _hairline), gap: 9);
        i++;
        continue;
      }

      if (trimmed.startsWith('#')) {
        final title = _cleanHeading(trimmed);
        if (title.isNotEmpty) add(_buildHeading(title));
        i++;
        continue;
      }

      if (_isSectionStart(lines, i)) {
        final title = _cleanMarkers(_stripBullet(trimmed));
        final subLines = <String>[];
        i++;

        while (i < lines.length) {
          final next = lines[i];
          if (next.trim().isEmpty) {
            i++;
            continue;
          }
          if (!_isIndented(next)) break;
          subLines.add(next.trimRight());
          i++;
        }

        if (subLines.isEmpty) {
          add(_buildBulletRow(title), gap: 5);
        } else {
          add(_buildSectionCard(title, subLines), gap: 10);
        }
        continue;
      }

      if (_isSubheading(trimmed)) {
        add(_buildSubheading(trimmed));
        i++;
        continue;
      }

      if (_isBullet(trimmed)) {
        add(
          _buildBulletRow(
            _stripBullet(trimmed),
            leftInset: _isIndented(raw) ? 14 : 0,
          ),
          gap: 5,
        );
        i++;
        continue;
      }

      final numbered = RegExp(r'^(\d{1,3})[\.\)]\s+(.+)$').firstMatch(trimmed);
      if (numbered != null) {
        add(
          _buildNumberedRow(
            numbered.group(1)!,
            numbered.group(2)!.trim(),
          ),
          gap: 5,
        );
        i++;
        continue;
      }

      add(_buildHighlightedText(trimmed, fontSize: 13), gap: 6);
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  Widget _buildHeading(String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 15,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.25,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubheading(String raw) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: _teal,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _cleanMarkers(raw),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _tealDark,
              height: 1.3,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<String> subLines) {
    final style = _sectionStyle(title);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              border: Border(
                bottom: BorderSide(
                  color: style.color.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(style.icon, size: 15, color: style.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.2,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    style.label,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: _buildSubItems(subLines, style.color),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItems(List<String> lines, Color accent) {
    final items = <Widget>[];
    var i = 0;

    while (i < lines.length) {
      if (_isCodeOnly(lines[i])) {
        final codes = <String>[];
        final leftInset = _leftInsetFor(lines[i]);
        while (i < lines.length && _isCodeOnly(lines[i])) {
          codes.add(_cleanCode(lines[i]));
          i++;
        }
        items.add(
          Padding(
            padding: EdgeInsets.only(left: leftInset),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final code in codes) _buildCodePill(code),
              ],
            ),
          ),
        );
      } else {
        items.add(_buildSubItemRow(lines[i], accent));
        i++;
      }

      if (i < lines.length) items.add(const SizedBox(height: 6));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildSubItemRow(String rawLine, Color accent) {
    final clean = _stripBullet(rawLine);
    if (clean.isEmpty) return const SizedBox.shrink();

    final isLabel = clean.endsWith(':') && clean.length <= 90;

    return Padding(
      padding: EdgeInsets.only(left: _leftInsetFor(rawLine)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5, right: 7),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: isLabel
                ? Text(
                    _cleanMarkers(clean),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.4,
                    ),
                  )
                : _buildHighlightedText(clean, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletRow(String text, {double leftInset = 0}) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: 7),
            decoration: const BoxDecoration(
              color: _teal,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: _buildHighlightedText(text, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedRow(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 17),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7FA),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFC9EEF4)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: _tealDark,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _buildHighlightedText(text, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildStreamingPlaceholder() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _teal,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'Valencia AI está respondiendo...',
          style: TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: _tealDark,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TEXTO ENRIQUECIDO (negritas, código, montos y cantidades)
  // =========================================================================

  Widget _buildHighlightedText(String text, {double fontSize = 13}) {
    final regex = RegExp(
      r'(\*\*[^*]+\*\*|`[^`]+`|\b(?:PED|OC|AJU|NOT|PROD|CLI|PRV|MOV)-\d+(?:-\d+)?\b|S\/\s*[\d,]+(?:\.\d{2})?|[+-]?\d+\s*UND\b)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: _bodyStyle(fontSize),
        ));
      }

      final matched = match.group(0)!;

      if (matched.startsWith('**') &&
          matched.endsWith('**') &&
          matched.length > 4) {
        spans.add(TextSpan(
          text: matched.substring(2, matched.length - 2),
          style: _bodyStyle(fontSize, weight: FontWeight.w800),
        ));
      } else if (matched.startsWith('`') && matched.endsWith('`')) {
        final inner = matched.substring(1, matched.length - 1).trim();
        spans.add(
          inner.isEmpty
              ? TextSpan(text: matched, style: _bodyStyle(fontSize))
              : WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _buildCodePill(inner),
                ),
        );
      } else if (_entityCodeRegex.hasMatch(matched)) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildCodePill(matched),
        ));
      } else if (matched.toLowerCase().startsWith('s/')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildCurrencyPill(matched),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _buildQuantityPill(matched),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: _bodyStyle(fontSize),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: _bodyStyle(fontSize)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: _bodyStyle(fontSize),
    );
  }

  TextStyle _bodyStyle(
    double fontSize, {
    FontWeight? weight,
    Color color = _ink,
  }) {
    return TextStyle(
      fontSize: fontSize,
      color: color,
      height: 1.45,
      fontWeight: weight ?? FontWeight.w400,
    );
  }

  Widget _buildCodePill(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFD8E3E8)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.1,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildCurrencyPill(String currency) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFB7EFE5)),
      ),
      child: Text(
        currency,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F766E),
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildQuantityPill(String quantity) {
    final negative = quantity.trim().startsWith('-');
    final background =
        negative ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA);
    final border =
        negative ? const Color(0xFFFECACA) : const Color(0xFFB7EFE5);
    final foreground =
        negative ? const Color(0xFFB91C1C) : const Color(0xFF0F766E);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(
        quantity,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: foreground,
          height: 1.2,
        ),
      ),
    );
  }

  // =========================================================================
  // PIE DE MENSAJE
  // =========================================================================

  Widget _buildFooter(BuildContext context, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Respuesta copiada al portapapeles.'),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.copy_rounded, size: 12, color: _muted),
                SizedBox(width: 4),
                Text(
                  'Copiar',
                  style: TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// ACCESO DIRECTO A NOTIFICACIONES
// ===========================================================================

class _NotificationShortcut extends StatelessWidget {
  const _NotificationShortcut();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCountNotifier,
      builder: (context, unread, _) {
        final title = unread > 0
            ? '$unread ${unread == 1 ? 'notificación sin leer' : 'notificaciones sin leer'}'
            : 'Notificaciones de la app';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            NotificationsSheet.show(context);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FEFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9EEF4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F8FB),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: _teal,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Toca para abrir la bandeja',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _teal,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===========================================================================
// HELPERS DE PARSEO
// ===========================================================================

bool _mentionsNotifications(String text) {
  final lower = text.toLowerCase();
  return lower.contains('notificacion') ||
      lower.contains('notificación') ||
      lower.contains('alertas pendientes') ||
      lower.contains('alertas del sistema');
}

bool _isHorizontalRule(String line) {
  return RegExp(r'^[-*_]{3,}$').hasMatch(line.trim());
}

bool _isBullet(String line) {
  return RegExp(r'^[-*•]\s+').hasMatch(line.trim());
}

bool _isIndented(String line) {
  return line.startsWith(' ') || line.startsWith('\t');
}

bool _isSectionStart(List<String> lines, int index) {
  final raw = lines[index];
  if (_isIndented(raw)) return false;
  if (!_isBullet(raw.trim())) return false;

  for (var j = index + 1; j < lines.length; j++) {
    final next = lines[j];
    if (next.trim().isEmpty) continue;
    return _isIndented(next);
  }
  return false;
}

bool _isSubheading(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('#') ||
      _isBullet(trimmed) ||
      RegExp(r'^\d{1,3}[\.\)]\s+').hasMatch(trimmed)) {
    return false;
  }
  if (trimmed.endsWith(':') && trimmed.length <= 90) return true;
  return RegExp(r'^\*\*[^*]+\*\*$').hasMatch(trimmed) ||
      RegExp(r'^__[^_]+__$').hasMatch(trimmed);
}

bool _isCodeOnly(String line) {
  return _entityCodeRegex.hasMatch(_cleanCode(line));
}

String _cleanCode(String line) {
  return _stripBullet(line).replaceFirst(RegExp(r'[,.;:]$'), '').trim();
}

String _stripBullet(String line) {
  return line.trim().replaceFirst(RegExp(r'^[-*•]\s+'), '').trim();
}

String _cleanHeading(String line) {
  return _cleanMarkers(line.replaceFirst(RegExp(r'^#+\s*'), ''));
}

String _cleanMarkers(String text) {
  var value = text.trim();
  value = value.replaceAll('**', '').replaceAll('__', '');
  value = value.replaceAll(RegExp(r'^[*_]+|[*_]+$'), '');
  return value.trim();
}

double _leftInsetFor(String line) {
  final indent = line.length - line.trimLeft().length;
  return indent >= 4 ? 14 : 0;
}

// ===========================================================================
// ESTILO DE CADA TARJETA DE SECCIÓN
// ===========================================================================

class _SectionStyle {
  final Color color;
  final IconData icon;
  final String label;

  const _SectionStyle(this.color, this.icon, this.label);
}

_SectionStyle _sectionStyle(String title) {
  final lower = title.toLowerCase();

  if (lower.contains('error') ||
      lower.contains('fall') ||
      lower.contains('rechaz') ||
      lower.contains('urgente')) {
    return const _SectionStyle(
      Color(0xFFB91C1C),
      Icons.error_outline_rounded,
      'Urgente',
    );
  }

  if (lower.contains('alerta') ||
      lower.contains('advert') ||
      lower.contains('anulad') ||
      lower.contains('revertid') ||
      lower.contains('expir') ||
      lower.contains('quiebre') ||
      lower.contains('merma')) {
    return const _SectionStyle(
      Color(0xFFB45309),
      Icons.warning_amber_rounded,
      'Alerta',
    );
  }

  if (lower.contains('ingreso') ||
      lower.contains('stock') ||
      lower.contains('inventario') ||
      lower.contains('kardex') ||
      lower.contains('mercader')) {
    return const _SectionStyle(
      Color(0xFF007785),
      Icons.inventory_2_rounded,
      'Stock',
    );
  }

  if (lower.contains('orden') ||
      lower.contains('pedido') ||
      lower.contains('despach') ||
      lower.contains('venta') ||
      lower.contains('cliente')) {
    return const _SectionStyle(
      Color(0xFF0077B6),
      Icons.local_shipping_rounded,
      'Órdenes',
    );
  }

  if (lower.contains('compra') ||
      lower.contains('proveedor') ||
      lower.contains('recepción') ||
      lower.contains('recepcion')) {
    return const _SectionStyle(
      Color(0xFF0077B6),
      Icons.shopping_bag_rounded,
      'Compras',
    );
  }

  if (lower.contains('resumen')) {
    return const _SectionStyle(_teal, Icons.summarize_rounded, 'Resumen');
  }

  return const _SectionStyle(_teal, Icons.segment_rounded, 'Detalle');
}
