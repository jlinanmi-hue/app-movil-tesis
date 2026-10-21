import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Barra de grabación de voz en tiempo real con animación de onda idéntica a la versión Web.
///
/// Componentes:
/// - Botón descartar (ícono papelera slate-500)
/// - Punto rojo pulsante y temporizador (formato MM:SS, urgente en >= 100s)
/// - Ecualizador / Waveform con barras redondeadas (slate-700 activas, slate-300 inactivas)
/// - Indicador de límite "/ 2:00"
/// - Botón circular esmeralda (#10B981) para enviar nota de voz
class VoiceRecordingBar extends StatefulWidget {
  final int recordingSeconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final Stream<Amplitude>? amplitudeStream;

  const VoiceRecordingBar({
    super.key,
    required this.recordingSeconds,
    required this.onCancel,
    required this.onSend,
    this.amplitudeStream,
  });

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  double _latestAmp = 0.0;
  double _smoothAmp = 0.15; // Nivel sutil inicial para que tenga vida al comenzar

  @override
  void initState() {
    super.initState();

    // Animación del punto rojo pulsante
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    // Animación fluida de la onda sonora a 60fps
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        if (!mounted) return;
        // Suavizado exponencial del volumen recibido
        _smoothAmp = _smoothAmp * 0.72 + _latestAmp * 0.28;
        setState(() {});
      })
      ..repeat();

    // Escuchar el stream de amplitud del micrófono si está disponible
    _amplitudeSubscription = widget.amplitudeStream?.listen(
      (amp) {
        if (!mounted) return;
        final current = amp.current;
        if (current.isInfinite || current.isNaN || current < -52.0) {
          _latestAmp = 0.0;
        } else {
          // Normalizar decibeles (-52 dB a 0 dB) al rango 0.0 .. 1.0
          final normalized = ((current + 52.0) / 52.0).clamp(0.0, 1.0);
          _latestAmp = normalized;
        }
      },
      onError: (_) {
        _latestAmp = 0.0;
      },
    );
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.recordingSeconds >= 100;
    final timerColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFF334155);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // slate-50
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Botón Descartar (Papelera)
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onCancel,
              splashColor: const Color(0xFFE2E8F0),
              highlightColor: const Color(0xFFE2E8F0),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Color(0xFF64748B), // slate-500
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // 2. Timer estilo WhatsApp con punto rojo pulsante
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 0.82 + (_pulseController.value * 0.36);
                    final opacity = 0.4 + (_pulseController.value * 0.6);
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444), // red-500
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimer(widget.recordingSeconds),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: timerColor,
                  ),
                ),
              ],
            ),
          ),

          // 3. Waveform con barras reactivas animadas (ajuste dinámico de ancho)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cálculo de cuántas barras de 3px + 2.5px gap caben exactamente
                const barWidth = 3.0;
                const barGap = 2.5;
                const step = barWidth + barGap;
                final availableWidth = constraints.maxWidth;
                final count = (availableWidth / step).floor().clamp(12, 28);

                final bars = <Widget>[];
                final wavePhase = _waveController.value * 2 * math.pi;

                for (int i = 0; i < count; i++) {
                  // Curva de envolvente centrada (mayor amplitud hacia el centro)
                  final envelope = math.sin(((i + 1) / (count + 1)) * math.pi);

                  // Armónicos ondulantes superpuestos
                  final h1 = math.sin(wavePhase + (i / count) * 3.2 * math.pi);
                  final h2 = math.cos(wavePhase * 1.4 - (i / count) * 4.0 * math.pi);
                  final waveNormalized = ((h1 * 0.55 + h2 * 0.45) + 1.0) / 2.0;

                  // Amplitud base: si hay sonido real se amplifica, sino se usa el latido sutil
                  final activeAmp = _smoothAmp > 0.04
                      ? (_smoothAmp * 0.65 + waveNormalized * _smoothAmp * 0.45)
                      : (0.10 * waveNormalized);

                  final barLevel = (activeAmp * (0.35 + 0.65 * envelope)).clamp(0.0, 1.0);
                  final isActive = barLevel > 0.035;

                  // Altura calculada idéntica a la fórmula Web: 5 + lv * 22 (min 4, max 30)
                  final double height = isActive
                      ? (5.0 + barLevel * 22.0).clamp(4.0, 28.0)
                      : 4.0;

                  final color = isActive
                      ? const Color(0xFF334155) // slate-700
                      : const Color(0xFFCBD5E1); // slate-300

                  bars.add(
                    Container(
                      key: ValueKey('wave_bar_$i'),
                      width: barWidth,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 1.25),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(barWidth),
                      ),
                    ),
                  );
                }

                return ClipRect(
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: bars,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 4),

          // 4. Límite máximo / 2:00
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '/ 2:00',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8), // slate-400
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),

          const SizedBox(width: 4),

          // 5. Botón Enviar circular verde esmeralda con avión de papel
          GestureDetector(
            onTap: widget.onSend,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981), // emerald-500
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.only(left: 2.0),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
