import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'ants_wars_game.dart';
import 'unit_component.dart';

/// Hedefe uçan mermi (kule taşı / formik asit damlası).
/// Hedefe ulaşınca hasarını uygular; hedef ölmüşse yol ortasında kaybolur.
class Projectile extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  Projectile({
    required Vector2 position,
    required this.target,
    required this.damage,
    this.speed = 260,
    this.color = const Color(0xFFB8D44A), // asit yeşili
  }) : super(position: position, anchor: Anchor.center, priority: 30);

  final UnitComponent target;
  final double damage;
  final double speed;
  final Color color;

  final Vector2 _velocity = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);
    if (target.dead || target.isRemoved) {
      removeFromParent();
      return;
    }
    final delta = target.position - position;
    final dist = delta.length;
    if (dist < 7) {
      target.takeDamage(damage);
      removeFromParent();
      return;
    }
    _velocity.setFrom(delta / dist * speed);
    position += _velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    if (!game.fog.isVisible(position)) return; // sis altında görünmez
    // Küçük iz + damla.
    // Sıfır hız vektörünü normalize etme (NaN çizim koruması).
    final back = _velocity.length2 < 1e-9
        ? Vector2.zero()
        : _velocity.normalized() * -5;
    canvas.drawLine(
      Offset(back.x, back.y),
      Offset.zero,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset.zero, 2.6, Paint()..color = color);
  }
}
