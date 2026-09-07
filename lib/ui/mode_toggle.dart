import 'package:flutter/material.dart';

import '../data/i18n.dart';

/// Tekli / Eşli (2v2) dikey seçim kutusu — menüde ve Savaş Kur'da ortak.
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    super.key,
    required this.teamMode,
    required this.onChanged,
    this.width = 128,
  });

  final bool teamMode;
  final ValueChanged<bool> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, IconData icon, bool value) {
      final selected = teamMode == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5C7A2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 13, color: selected ? Colors.white : Colors.white38),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    // Seçenekler YAN YANA (tek satır).
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xE6223019),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A6130)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          option(loc('Tekli', 'Solo'), Icons.person, false),
          const SizedBox(width: 4),
          option(loc('Eşli 2v2', '2v2 Teams'), Icons.group, true),
        ],
      ),
    );
  }
}
