import 'package:flutter/material.dart';

import '../theme/sc_tokens.dart';

/// Aparición escalonada de los bloques de una pantalla: cada uno sube 12 px y
/// se funde, con un pequeño retraso según su [index].
///
/// Solo ocurre la primera vez que se monta el bloque; en Modo Papel y con
/// movimiento reducido el contenido aparece tal cual.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _curve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !ScMotion.enabled(context)) return;
    final int step = widget.index.clamp(0, 6);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 420 + step * 45),
    );
    _curve = CurvedAnimation(
      parent: _controller!,
      curve: Interval(step * 45 / (420 + step * 45), 1, curve: ScMotion.ease),
    );
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnimationController? controller = _controller;
    if (controller == null) return widget.child;
    // La estructura no cambia al terminar (cambiarla recrearía el estado de
    // los hijos); con opacidad 1 FadeTransition pinta sin capa intermedia.
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (BuildContext context, Widget? child) =>
            Transform.translate(offset: Offset(0, (1 - _curve.value) * 12), child: child),
      ),
    );
  }
}
