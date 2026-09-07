import 'package:flutter/material.dart';

import '../game/audio_controller.dart';

/// Oyun stiline uygun geri butonu: menü kutularıyla aynı koyu yeşil
/// panel + kenarlık. Tüm ekranların AppBar'ında kullanılır.
class GameBackButton extends StatelessWidget {
  const GameBackButton({super.key, this.onTap});

  /// Varsayılan davranış yerine özel çıkış (örn. lobiden ayrılırken
  /// önce ağ bağlantısını kapatmak) gerekiyorsa verilir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap ??
            () {
              AudioController.uiClick();
              Navigator.maybePop(context);
            },
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            color: const Color(0xE6223019),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A6130)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded,
              size: 20, color: Color(0xFFD8C9A3)),
        ),
      ),
    );
  }
}
