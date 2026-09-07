import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flame/components.dart' show Vector2;

import '../data/abilities.dart';
import '../data/i18n.dart';
import '../game/ants_wars_game.dart';
import 'tutorial_keys.dart';
import '../game/audio_controller.dart';
import 'ability_art.dart';

/// Sağ altta 3 yetenek slotu: KARE kartlar; şarj alttan dolan bar gibi
/// görünür (sayı yok — dolum yeterli), ikonun altında yetenek ADI yazar.
/// Hazır olunca kart parlar. İçerik tam ortalıdır.
/// Alan yeteneği: butona BAS ve hedefe SÜRÜKLEYİP BIRAK (sise de atılır).
/// Global yetenek (Yağmur): butona basınca anında kullanılır.
class AbilityHud extends StatefulWidget {
  const AbilityHud({super.key, required this.game});

  final AntsWarsGame game;

  @override
  State<AbilityHud> createState() => _AbilityHudState();
}

class _AbilityHudState extends State<AbilityHud> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onSlotTap(int i, AbilitySpec spec) {
    final game = widget.game;
    if (game.abilityCooldowns[i] > 0) return;
    AudioController.uiClick();
    if (spec.global) {
      game.useHumanAbility(i, null);
      return;
    }
    // Yedek yol: dokun-kur, haritaya dokun-at.
    final ic = game.inputController;
    ic.pendingAbilitySlot = ic.pendingAbilitySlot == i ? null : i;
  }

  /// Asıl kullanım: butona BAS, haritada hedefe SÜRÜKLE, BIRAK → orada patlar.
  Vector2 _toWorld(Offset global) =>
      widget.game.camera.globalToLocal(Vector2(global.dx, global.dy));

  void _onSlotPanStart(int i, AbilitySpec spec, Offset global) {
    final game = widget.game;
    if (game.abilityCooldowns[i] > 0 || spec.global) return;
    AudioController.uiClick();
    final ic = game.inputController;
    ic.pendingAbilitySlot = null;
    ic.abilityDragSlot = i;
    ic.abilityDragPoint = _toWorld(global);
    setState(() {});
  }

  void _onSlotPanUpdate(Offset global) {
    final ic = widget.game.inputController;
    if (ic.abilityDragSlot == null) return;
    ic.abilityDragPoint = _toWorld(global);
  }

  void _onSlotPanEnd() {
    final game = widget.game;
    final ic = game.inputController;
    final slot = ic.abilityDragSlot;
    final point = ic.abilityDragPoint;
    ic.abilityDragSlot = null;
    ic.abilityDragPoint = null;
    if (slot != null && point != null) {
      game.useHumanAbility(slot, point);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final human = game.gameState.humanPlayer;
    if (!game.isLoaded || human == null || human.eliminated) {
      return const SizedBox.shrink();
    }
    final pending = game.inputController.pendingAbilitySlot;

    return Positioned(
      right: 10,
      bottom: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (pending != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  loc(
                      '${abilitySpecs[game.humanAbilities[pending]]!.name}: '
                      'hedefe dokun (veya butondan sürükleyip bırak)',
                      '${abilitySpecs[game.humanAbilities[pending]]!.name}: '
                      'tap a target (or drag from the button)'),
                  style: const TextStyle(
                      color: Color(0xFFF2E8D5), fontSize: 11),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < game.humanAbilities.length; i++) ...[
                KeyedSubtree(
                  key: i == 0 ? TutorialKeys.abilitySlot0 : null,
                  child: _slotButton(i, human.color, pending == i),
                ),
                if (i < game.humanAbilities.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotButton(int i, Color teamColor, bool armed) {
    final game = widget.game;
    final type = game.humanAbilities[i];
    final spec = abilitySpecs[type]!;
    final remaining = game.abilityCooldowns[i].clamp(0, spec.cooldown);
    final ready = remaining <= 0;

    final charge = (1 - remaining / spec.cooldown).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _onSlotTap(i, spec),
      onPanStart: (d) => _onSlotPanStart(i, spec, d.globalPosition),
      onPanUpdate: (d) => _onSlotPanUpdate(d.globalPosition),
      onPanEnd: (_) => _onSlotPanEnd(),
      onPanCancel: _onSlotPanEnd,
      child: Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        // Dış çizgi yok: kare boyutlu yumuşak kart; hazırken parlar,
        // sürükleme kurulduğunda beyaz hale alır.
        decoration: BoxDecoration(
          color: const Color(0xD91F2A16),
          borderRadius: BorderRadius.circular(9),
          boxShadow: armed
              ? const [BoxShadow(color: Colors.white54, blurRadius: 7)]
              : ready
                  ? [
                      BoxShadow(
                          color: teamColor.withValues(alpha: 0.45),
                          blurRadius: 7)
                    ]
                  : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Şarj: alttan yükselen dolum (loading bar gibi).
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ready ? 1 : charge,
                widthFactor: 1,
                child: Container(
                  color: teamColor.withValues(alpha: ready ? 0.22 : 0.3),
                ),
              ),
            ),
            // İçerik tam ortalı: ikon + altında yetenek adı.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: ready ? 1 : 0.45,
                    child: AbilityArt(type: type, size: 22),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spec.name,
                      maxLines: 1,
                      style: TextStyle(
                        color: ready
                            ? const Color(0xFFF2E8D5)
                            : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
