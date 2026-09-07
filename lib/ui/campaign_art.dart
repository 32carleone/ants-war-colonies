import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/campaigns.dart';

/// SEFER çizimleri:
/// - [CampaignTriptychPainter]: seçim ekranı — üç sefer TEK KESİNTİSİZ
///   panorama olarak (soldan sağa volkan → buzul → takımadalar) akar,
///   aralarında çerçeve/çizgi yoktur; geçişler gökyüzü ve zeminde harmanlanır.
/// - [CampaignPagePainter]: görev haritası fonu — rota ve 5 görev PLATFORMU
///   fonun PARÇASI olarak çizilir (lav yolu üstünde obsidyen adacıklar,
///   donmuş gölde buz kütleleri, denizde kalas köprülü adalar).

// ═══════════════════════════════════════════════ SEÇİM PANORAMASI

class CampaignTriptychPainter extends CustomPainter {
  /// GRID panorama: ÜSTTE solda volkan ülkesi, sağda buzul ülkesi;
  /// EN ALTTA boydan boya takımada denizi. Çerçeve yok — volkan ve buzul
  /// etekleri dalgalı kıyıdan DENİZE iner, üç dünya tek sahnede birleşir.
  static const double seaTop = 0.60; // denizin başladığı oran

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sea = h * seaTop;

    // Üst gökyüzü: volkan kızılı soldan buz gecesine akar.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, sea),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF5E1F12),
            Color(0xFF7A2C15),
            Color(0xFF463A50),
            Color(0xFF1E3A50),
            Color(0xFF10202E),
          ],
          stops: [0.0, 0.28, 0.5, 0.72, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, sea)),
    );

    // ── SOL ÜST: VOLKAN ÜLKESİ ──
    final sun = Offset(w * 0.09, h * 0.14);
    canvas.drawCircle(sun, w * 0.040,
        Paint()..color = const Color(0xFFF6C044).withValues(alpha: 0.22));
    canvas.drawCircle(
      sun,
      w * 0.030,
      Paint()
        ..color = const Color(0xFFE8683C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Arka silsile + ana volkan (etekleri DENİZE iner).
    final backVol = Path()
      ..moveTo(-4, sea + 8)
      ..lineTo(w * 0.06, h * 0.34)
      ..lineTo(w * 0.13, h * 0.42)
      ..lineTo(w * 0.20, h * 0.26)
      ..lineTo(w * 0.30, h * 0.44)
      ..lineTo(w * 0.40, h * 0.36)
      ..lineTo(w * 0.47, sea + 8)
      ..close();
    canvas.drawPath(backVol, Paint()..color = const Color(0xFF3A1B12));
    final volcano = Path()
      ..moveTo(w * 0.05, sea + 8)
      ..lineTo(w * 0.155, h * 0.16)
      ..lineTo(w * 0.20, h * 0.19)
      ..lineTo(w * 0.33, sea + 8)
      ..close();
    canvas.drawPath(volcano, Paint()..color = const Color(0xFF241210));
    canvas.drawLine(
      Offset(w * 0.155, h * 0.16),
      Offset(w * 0.20, h * 0.19),
      Paint()
        ..color = const Color(0xFFF6C044)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    for (final (dx, bend) in const [(0.168, -0.012), (0.185, 0.016)]) {
      final lava = Path()
        ..moveTo(w * dx, h * 0.19)
        ..quadraticBezierTo(
            w * (dx + bend), h * 0.40, w * (dx + bend * 2.2), sea + 4);
      canvas.drawPath(
        lava,
        Paint()
          ..color = const Color(0xFFE8683C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(w * (0.175 + i * 0.012), h * (0.11 - i * 0.032)),
        w * (0.010 + i * 0.005),
        Paint()
          ..color = const Color(0xFF6E5648).withValues(alpha: 0.5 - i * 0.12),
      );
    }
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(w * ((i * 0.05) % 0.42 + 0.03), h * ((i * 0.13) % 0.42 + 0.06)),
        1.5 + (i % 3) * 0.8,
        Paint()
          ..color =
              const Color(0xFFF6C044).withValues(alpha: 0.35 + (i % 3) * 0.18),
      );
    }

    // ── SAĞ ÜST: BUZUL ÜLKESİ ──
    final aurora = Path()
      ..moveTo(w * 0.60, h * 0.10)
      ..quadraticBezierTo(w * 0.74, h * 0.02, w * 0.90, h * 0.09)
      ..quadraticBezierTo(w * 0.80, h * 0.14, w * 0.66, h * 0.17)
      ..close();
    canvas.drawPath(aurora,
        Paint()..color = const Color(0xFF7FD6C8).withValues(alpha: 0.16));
    canvas.drawCircle(Offset(w * 0.86, h * 0.10), w * 0.018,
        Paint()..color = const Color(0xFFE8F6FC).withValues(alpha: 0.85));
    final backIce = Path()
      ..moveTo(w * 0.50, sea + 8)
      ..lineTo(w * 0.58, h * 0.24)
      ..lineTo(w * 0.66, h * 0.40)
      ..lineTo(w * 0.745, h * 0.16)
      ..lineTo(w * 0.83, h * 0.38)
      ..lineTo(w * 0.91, h * 0.28)
      ..lineTo(w + 4, sea + 8)
      ..close();
    canvas.drawPath(backIce, Paint()..color = const Color(0xFF6E93AC));
    final frontIce = Path()
      ..moveTo(w * 0.56, sea + 8)
      ..lineTo(w * 0.655, h * 0.34)
      ..lineTo(w * 0.73, h * 0.52)
      ..lineTo(w * 0.80, h * 0.32)
      ..lineTo(w * 0.90, sea + 8)
      ..close();
    canvas.drawPath(frontIce, Paint()..color = const Color(0xFF9CBDD2));
    for (final (px, py) in const [(0.58, 0.24), (0.745, 0.16), (0.80, 0.32)]) {
      final p = Offset(w * px, h * py);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - w * 0.012, p.dy + h * 0.05)
          ..lineTo(p.dx, p.dy)
          ..lineTo(p.dx + w * 0.012, p.dy + h * 0.05)
          ..close(),
        Paint()..color = const Color(0xFFF3F3EA),
      );
    }
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(w * (0.52 + (i * 0.035) % 0.45), h * ((i * 0.13) % 0.5 + 0.04)),
        1.2 + (i % 2) * 0.8,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }

    // ── ALT: BOYDAN BOYA TAKIMADA DENİZİ ──
    // Dalgalı kıyı çizgisiyle deniz; volkan/buzul etekleri suya girer.
    final seaPath = Path()..moveTo(-4, sea);
    for (var x = 0.0; x <= w; x += w / 14) {
      seaPath.quadraticBezierTo(
          x + w / 28, sea - 7, x + w / 14, sea + (x % (w / 7) == 0 ? 4 : -2));
    }
    seaPath
      ..lineTo(w + 4, h + 4)
      ..lineTo(-4, h + 4)
      ..close();
    canvas.drawPath(
      seaPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A6A6E), Color(0xFF1E4A50)],
        ).createShader(Rect.fromLTWH(0, sea - 10, w, h - sea + 10)),
    );
    // Kıyı köpüğü.
    canvas.drawPath(
      seaPath,
      Paint()
        ..color = const Color(0xFF7FD6C8).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Dalga ışıltıları + güneş yansıması.
    final wave = Paint()
      ..color = const Color(0xFF7FD6C8).withValues(alpha: 0.30)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i++) {
      final y = sea + (h - sea) * ((i * 0.19) % 0.9) + 8;
      final x = w * ((i * 0.157) % 0.95);
      canvas.drawLine(Offset(x, y), Offset(x + w * 0.018, y), wave);
    }
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, sea + (h - sea) * 0.3),
          width: w * 0.16,
          height: h * 0.03),
      Paint()..color = const Color(0xFFF6D879).withValues(alpha: 0.14),
    );
    // Adalar: boydan boya serpili, ortadaki büyük (odak).
    // Tam daire DEĞİL — kum ve çimen kenarları girintili çıkıntılı (organik);
    // aralarında çizgi/köprü yok, sadece açık deniz.
    Path blob(Offset at, double r, double seed, {double squish = 0.9}) {
      final path = Path();
      for (var k = 0; k <= 12; k++) {
        final a = k / 12 * 2 * math.pi;
        final wob = 1 +
            math.sin(a * 3 + seed) * 0.14 +
            math.sin(a * 5 + seed * 1.7) * 0.07;
        final p = at.translate(
            math.cos(a) * r * wob, math.sin(a) * r * wob * squish);
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path..close();
    }

    void islet(Offset at, double r, double seed, {bool palm = false}) {
      canvas.drawPath(
          blob(at, r * 1.42, seed + 2),
          Paint()..color = const Color(0xFF7FD6C8).withValues(alpha: 0.18));
      canvas.drawPath(blob(at, r * 1.22, seed),
          Paint()..color = const Color(0xFFD9C58F));
      canvas.drawPath(blob(at, r * 0.94, seed + 5),
          Paint()..color = const Color(0xFF5E7C3E));
      canvas.drawPath(
          blob(at.translate(-r * 0.22, -r * 0.22), r * 0.48, seed + 9),
          Paint()..color = const Color(0xFF74A038));
      if (palm) {
        final trunk = Paint()
          ..color = const Color(0xFF7A6540)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(at.translate(0, 2), at.translate(4, -r * 1.05), trunk);
        for (var a = 0; a < 5; a++) {
          final ang = -math.pi / 2 + (a - 2) * 0.5;
          canvas.drawLine(
            at.translate(4, -r * 1.05),
            at.translate(4 + math.cos(ang) * r * 0.6,
                -r * 1.05 + math.sin(ang) * r * 0.5),
            Paint()
              ..color = const Color(0xFF4F6B34)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    final iy = sea + (h - sea) * 0.52;
    islet(Offset(w * 0.18, iy + (h - sea) * 0.10), w * 0.026, 3);
    islet(Offset(w * 0.46, iy - (h - sea) * 0.06), w * 0.034, 7, palm: true);
    islet(Offset(w * 0.72, iy + (h - sea) * 0.12), w * 0.028, 11);
    islet(Offset(w * 0.92, iy - (h - sea) * 0.02), w * 0.020, 15, palm: true);
  }

  @override
  bool shouldRepaint(covariant CampaignTriptychPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════ GÖREV SAYFASI FONLARI

/// Görev haritası fonu: rota ve 5 platform FONUN PARÇASIDIR — üstteki
/// düğüm widget'ları yalnız durum (numara/kilit/bayrak/halka) çizer.
class CampaignPagePainter extends CustomPainter {
  CampaignPagePainter({required this.id, required this.nodes});

  final CampaignId id;
  final List<Offset> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    switch (id) {
      case CampaignId.fire:
        _firePage(canvas, size);
      case CampaignId.ice:
        _icePage(canvas, size);
      case CampaignId.islands:
        _islandPage(canvas, size);
    }
  }

  // -------- ATEŞ: kavrulmuş plato, akkor LAV YOLU, obsidyen platformlar.
  void _firePage(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A100C), Color(0xFF4A1A10), Color(0xFF5E2412)],
        ).createShader(Offset.zero & s),
    );
    // Uzak volkan + akkor ağız + duman.
    final volcano = Path()
      ..moveTo(s.width * 0.55, s.height * 0.36)
      ..lineTo(s.width * 0.72, s.height * 0.08)
      ..lineTo(s.width * 0.78, s.height * 0.12)
      ..lineTo(s.width * 0.96, s.height * 0.38)
      ..close();
    c.drawPath(volcano, Paint()..color = const Color(0xFF1C0D0A));
    c.drawLine(
      Offset(s.width * 0.72, s.height * 0.08),
      Offset(s.width * 0.78, s.height * 0.12),
      Paint()
        ..color = const Color(0xFFF6C044)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 4; i++) {
      c.drawCircle(
        Offset(s.width * (0.745 + i * 0.014), s.height * (0.06 - i * 0.018)),
        6.0 + i * 3,
        Paint()..color = const Color(0xFF6E5648).withValues(alpha: 0.4 - i * 0.08),
      );
    }
    // Zemin dokusu: kavrulmuş yamalar + çatlaklar.
    for (var i = 0; i < 12; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * ((i * 0.29) % 1.0),
              s.height * (0.45 + (i * 0.19) % 0.5)),
          width: 90,
          height: 40,
        ),
        Paint()..color = const Color(0xFF241210).withValues(alpha: 0.35),
      );
    }
    // LAV YOLU: duraklar arasında akkor çatlak — rota fonla bütündür.
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = nodes[i];
      final b = nodes[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + 26);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1C0D0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB3491C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF6C044).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    // Obsidyen platformlar: lav yolunun genişlediği kürsüler.
    for (final n in nodes) {
      c.drawCircle(n.translate(3, 5), 34,
          Paint()..color = Colors.black.withValues(alpha: 0.35));
      c.drawCircle(n, 33,
          Paint()..color = const Color(0xFFE8683C).withValues(alpha: 0.45));
      c.drawCircle(n, 29, Paint()..color = const Color(0xFF241210));
      c.drawCircle(n, 29 * 0.72,
          Paint()..color = const Color(0xFF3A1B12));
      // Kürsü kenarında kor benekleri.
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + n.dx * 0.01;
        c.drawCircle(
          n.translate(math.cos(a) * 31, math.sin(a) * 31),
          1.6,
          Paint()..color = const Color(0xFFF6C044).withValues(alpha: 0.7),
        );
      }
    }
    // Havada korlar.
    for (var i = 0; i < 18; i++) {
      c.drawCircle(
        Offset(s.width * ((i * 0.37) % 1.0), s.height * ((i * 0.23) % 0.9)),
        1.4 + (i % 3) * 0.8,
        Paint()
          ..color = const Color(0xFFF6C044)
              .withValues(alpha: 0.30 + (i % 3) * 0.14),
      );
    }
  }

  // -------- BUZ: aurora, donmuş göl, buz kütlesi platformlar.
  void _icePage(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF10202E), Color(0xFF1E3A50), Color(0xFF2E556E)],
        ).createShader(Offset.zero & s),
    );
    // Aurora perdeleri.
    for (var i = 0; i < 3; i++) {
      final base = s.height * (0.10 + i * 0.035);
      final a = Path()..moveTo(-4, base);
      for (var x = 0.0; x <= s.width; x += s.width / 6) {
        a.quadraticBezierTo(
            x + s.width / 12, base - 26 - i * 8, x + s.width / 6, base);
      }
      a
        ..lineTo(s.width + 4, base + 30)
        ..lineTo(-4, base + 30)
        ..close();
      c.drawPath(
          a,
          Paint()
            ..color = const Color(0xFF7FD6C8)
                .withValues(alpha: 0.10 - i * 0.02));
    }
    // Buzul sırtları.
    final ridge = Path()..moveTo(-4, s.height * 0.44);
    for (var i = 0; i <= 8; i++) {
      ridge.lineTo(
          s.width * i / 8, s.height * (0.18 + ((i * 37) % 5) * 0.05));
    }
    ridge
      ..lineTo(s.width + 4, s.height * 0.44)
      ..close();
    c.drawPath(ridge, Paint()..color = const Color(0xFF48708C));
    // DONMUŞ GÖL: platformların yüzdüğü geniş buz aynası.
    c.drawOval(
      Rect.fromCenter(
          center: Offset(s.width * 0.5, s.height * 0.66),
          width: s.width * 1.05,
          height: s.height * 0.62),
      Paint()..color = const Color(0xFF7FA6BC).withValues(alpha: 0.35),
    );
    c.drawOval(
      Rect.fromCenter(
          center: Offset(s.width * 0.5, s.height * 0.66),
          width: s.width * 0.9,
          height: s.height * 0.5),
      Paint()..color = const Color(0xFFA9C8D8).withValues(alpha: 0.30),
    );
    // Duraklar arası: buzda ÇATLAK rota.
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = nodes[i];
      final b = nodes[i + 1];
      final u = (b - a) / (b - a).distance;
      var p = a;
      final crack = Paint()
        ..color = const Color(0xFFE8F6FC).withValues(alpha: 0.55)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final len = (b - a).distance;
      for (var d = 30.0; d < len - 30; d += 24) {
        final q = a +
            u * d +
            Offset(-u.dy, u.dx) * (math.sin(d * 0.2 + a.dx) * 6);
        c.drawLine(p, q, crack);
        p = q;
      }
      c.drawLine(p, b - u * 30, crack);
    }
    // BUZ KÜTLESİ platformlar (yüzen kırık kenarlı levhalar).
    for (final n in nodes) {
      final floe = Path();
      for (var k = 0; k <= 7; k++) {
        final a = k / 7 * 2 * math.pi;
        final r = 32 * (1 + math.sin(a * 3 + n.dx) * 0.10);
        final p = n.translate(math.cos(a) * r, math.sin(a) * r * 0.92);
        if (k == 0) {
          floe.moveTo(p.dx, p.dy);
        } else {
          floe.lineTo(p.dx, p.dy);
        }
      }
      floe.close();
      c.drawPath(floe, Paint()..color = const Color(0xFF9CBDD2));
      c.drawPath(
        floe,
        Paint()
          ..color = const Color(0xFFE8F6FC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.drawCircle(n, 22, Paint()..color = const Color(0xFFC9DCE8));
    }
    // Tipi.
    for (var i = 0; i < 24; i++) {
      c.drawCircle(
        Offset(s.width * ((i * 0.43) % 1.0), s.height * ((i * 0.19) % 1.0)),
        1.2 + (i % 2) * 0.8,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }
  }

  // -------- ADALAR: her durak GERÇEK bir adadır; rota kalas köprüler.
  void _islandPage(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14343A), Color(0xFF1E4A50), Color(0xFF2A6A6E)],
        ).createShader(Offset.zero & s),
    );
    // Dalgalar + güneş ışıltısı.
    final wave = Paint()
      ..color = const Color(0xFF7FD6C8).withValues(alpha: 0.22)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final y = s.height * (0.06 + i * 0.08);
      for (var x = 0.0; x < s.width; x += 34) {
        c.drawLine(Offset(x + (i * 9) % 22, y),
            Offset(x + 15 + (i * 9) % 22, y), wave);
      }
    }
    c.drawOval(
      Rect.fromCenter(
          center: Offset(s.width * 0.78, s.height * 0.20),
          width: s.width * 0.2,
          height: s.height * 0.05),
      Paint()..color = const Color(0xFFF6D879).withValues(alpha: 0.15),
    );
    // Rota: adalar arası KALAS KÖPRÜLER.
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = nodes[i];
      final b = nodes[i + 1];
      final u = (b - a) / (b - a).distance;
      final n = Offset(-u.dy, u.dx);
      final len = (b - a).distance;
      for (var d = 40.0; d < len - 40; d += 9) {
        final p = a + u * d;
        c.drawLine(p - n * 6, p + n * 6,
            Paint()..color = const Color(0xFF7A6540)..strokeWidth = 4);
      }
      // Halatlar.
      for (final side in const [-1.0, 1.0]) {
        c.drawLine(
          a + u * 40 + n * 7 * side,
          b - u * 40 + n * 7 * side,
          Paint()
            ..color = const Color(0xFF3E3018)
            ..strokeWidth = 1.6,
        );
      }
    }
    // ADA platformlar: kum + çimen + minik palmiye ve dalga halkası.
    for (final n in nodes) {
      c.drawCircle(
        n,
        44,
        Paint()
          ..color = const Color(0xFF7FD6C8).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final blobSand = Path();
      final blobGrass = Path();
      for (var k = 0; k <= 9; k++) {
        final a = k / 9 * 2 * math.pi;
        final wob = 1 + math.sin(a * 3 + n.dy) * 0.10;
        final ps = n.translate(
            math.cos(a) * 37 * wob, math.sin(a) * 33 * wob);
        final pg = n.translate(
            math.cos(a) * 28 * wob, math.sin(a) * 25 * wob);
        if (k == 0) {
          blobSand.moveTo(ps.dx, ps.dy);
          blobGrass.moveTo(pg.dx, pg.dy);
        } else {
          blobSand.lineTo(ps.dx, ps.dy);
          blobGrass.lineTo(pg.dx, pg.dy);
        }
      }
      c.drawPath(blobSand..close(), Paint()..color = const Color(0xFFD9C58F));
      c.drawPath(blobGrass..close(), Paint()..color = const Color(0xFF5E7C3E));
      c.drawCircle(n.translate(-7, -7), 12,
          Paint()..color = const Color(0xFF74A038));
      // Kenarda minik palmiye.
      final palmBase = n.translate(20, -18);
      c.drawLine(
        palmBase,
        palmBase.translate(4, -12),
        Paint()
          ..color = const Color(0xFF7A6540)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      for (var a = 0; a < 5; a++) {
        final ang = -math.pi / 2 + (a - 2) * 0.55;
        c.drawLine(
          palmBase.translate(4, -12),
          palmBase.translate(
              4 + math.cos(ang) * 9, -12 + math.sin(ang) * 7),
          Paint()
            ..color = const Color(0xFF4F6B34)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CampaignPagePainter old) =>
      old.id != id || old.nodes != nodes;
}
