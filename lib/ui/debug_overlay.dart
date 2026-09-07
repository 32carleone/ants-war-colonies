import 'dart:async';

import 'package:flutter/material.dart';

import '../game/ants_wars_game.dart';

/// Geliştirme overlay'i: FPS ve birim sayısı gösterir.
/// GameScreen'deki böcek butonuyla açılıp kapanır.
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key, required this.game});

  final AntsWarsGame game;

  static const overlayKey = 'debug';

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Positioned(
      left: 8,
      top: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'FPS: ${game.fps.toStringAsFixed(0)}\n'
            'Birim: ${game.unitCount}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
