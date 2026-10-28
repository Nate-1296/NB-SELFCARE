import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/sc_tokens.dart';

/// Respuesta táctil: el contenido se hunde levemente mientras se mantiene
/// pulsado y vuelve con un pequeño rebote al soltar.
///
/// No intercepta el gesto (lo sigue recibiendo el [InkWell] o botón interior),
/// solo escucha el puntero. En Modo Papel y con movimiento reducido no hace
/// nada, para no provocar refrescos intermedios de tinta.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});

  final Widget child;
  final bool enabled;

  /// Escala mínima durante la pulsación.
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _origin;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && ScMotion.enabled(context);
    // Misma estructura activa o no: así el botón interior conserva su estado.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: active
          ? (PointerDownEvent e) {
              _origin = e.position;
              _set(true);
            }
          : null,
      // Si el dedo se desplaza (scroll), deja de ser una pulsación.
      onPointerMove: (PointerMoveEvent e) {
        final Offset? o = _origin;
        if (_down && o != null && (e.position - o).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: active && _down ? widget.scale : 1,
        duration: _down ? ScMotion.press : ScMotion.quick,
        curve: _down ? Curves.easeOut : ScMotion.spring,
        child: widget.child,
      ),
    );
  }
}
