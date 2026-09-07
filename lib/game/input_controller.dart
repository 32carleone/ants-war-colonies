import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../models/building.dart';
import '../models/nest.dart';
import 'ability_effects.dart' show wavyCircle;
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'building_painter.dart';
import 'unit_component.dart';

/// Tüm oyun içi dokunma/sürükleme kontrolleri tek yerden yönetilir:
///
/// - Yuvaya dokun → soldan oran barı + tip seçici panel açılır.
/// - Yuvadan basılı tutup sürükle → güzergah oku + yerleşim ön izlemesi;
///   bırakınca seçili oran/tipte askerler çıkar.
/// - Askere dokun → zincirleme küme seçimi (yakınların yakınları da seçilir).
/// - Seçili kümeyi sürükle → aynı ön izleme; bırakınca yürürler.
///   Kendi yuvana bırakırsan içeri girip savunmayı güçlendirirler.
/// - Boş zemine dokun → seçim/panel kapanır.
class InputController extends PositionComponent
    with TapCallbacks, DragCallbacks, HasGameReference<AntsWarsGame> {
  InputController()
      : super(
          position: Vector2.zero(),
          size: Vector2(kGameWidth, kGameHeight),
          priority: 100,
        );

  /// Seçili asker kümesi.
  final List<UnitComponent> selection = [];

  /// Panel açıkken seçili yuva.
  Nest? selectedNest;

  /// Seçili (kendi) bina: çevresinde ikon butonlar belirir
  /// (yükselt / değiştir; değiştir açılınca dönüşüm seçenekleri).
  Building? selectedBuilding;

  /// "Değiştir" butonuna basıldı: dönüşüm seçenekleri açık.
  bool convertOpen = false;

  static const double _btnR = 23;

  /// Bina çevresi buton konumları (bina merkezine göre) — KENAR AKILLI:
  /// üst kenara yakın binalarda butonlar ALTA iner (üst bilgi barının
  /// altında kalmasınlar), sağ kenara yakınlarda düzen SOLA aynalanır.
  /// Böylece butonlar her binada görünür ve tıklanabilir kalır.
  ({Vector2 upgrade, Vector2 change, Vector2 optA, Vector2 optB})
      _buttonOffsets(Building b) {
    // Üst bilgi barına yakın binalarda butonlar ALTA iner — eşik geniş
    // tutulur (140'ta üst sıradaki binaların butonları bara gömülüp
    // tıklanamıyordu).
    final below = b.position.y < 190;
    final side = b.position.x > kGameWidth - 160 ? -1.0 : 1.0;
    final vy = below ? 47.0 : -47.0;
    final change = Vector2(47 * side, vy);
    return (
      upgrade: Vector2(-47 * side, vy),
      change: change,
      optA: change + Vector2(15 * side, 50),
      optB: change + Vector2(15 * side, 102),
    );
  }

  /// Kurulmuş yetenek slotu: bir sonraki dokunuş bu yeteneği o noktaya atar
  /// (yedek yol; asıl kullanım bas-sürükle-bırak).
  int? pendingAbilitySlot;

  /// Yetenek butonundan sürükleme: aktif slot ve haritadaki hedef noktası.
  int? abilityDragSlot;
  Vector2? abilityDragPoint;

  // Sürükleme durumu.
  bool _dragging = false;
  bool _dragFromNest = false;

  /// Sürükleme bir KULUÇKA İSTASYONUNUN üstünde başladıysa o bina:
  /// askerler yuva garnizonundan ama BU noktadan sahaya iner
  /// (ikinci çıkarma noktası — tut-sürükle ile açıkça seçilir).
  Building? _dragHatchery;
  final Vector2 _pointer = Vector2.zero();
  Vector2? _dragTarget;
  List<Vector2> _previewPath = const [];
  final Vector2 _lastPathTarget = Vector2(-9999, -9999);
  int _previewCount = 0;
  double _pulse = 0;

  static const _goldenAngle = 2.399963;

  Nest? get _humanNest {
    final human = game.gameState.humanPlayer;
    if (human == null || human.eliminated) return null;
    final nest = game.nests[human.id]!;
    return nest.destroyed ? null : nest;
  }

  // ------------------------------------------------------------- mantık

  void handleTap(Vector2 pos) {
    // Kurulu yetenek varsa dokunuş hedeftir (görünmez noktaya atılamaz).
    final slot = pendingAbilitySlot;
    if (slot != null) {
      pendingAbilitySlot = null;
      game.useHumanAbility(slot, pos);
      return;
    }

    // Seçili binanın çevre butonları (yükselt/değiştir/dönüştür) önceliklidir.
    if (_tapBuildingButton(pos)) return;
    if (_tapNestUpgrade(pos)) return;

    final nest = _humanNest;
    if (nest != null && pos.distanceTo(nest.position) < kNestTapRadius) {
      // Panel yok: yuva sadece vurgulanır; kontroller kenar HUD'unda.
      clearSelection();
      _closeBuildingButtons();
      selectedNest = nest;
      return;
    }

    final tapped = _ownUnitAt(pos);
    if (tapped != null) {
      _closeNestPanel();
      _closeBuildingButtons();
      selectClusterFrom(tapped);
      return;
    }

    // Kendi binası: çevresinde ikon butonlar açılır (panel yok).
    final building = _ownBuildingAt(pos);
    if (building != null) {
      clearSelection();
      _closeNestPanel();
      selectedBuilding = building;
      convertOpen = false;
      return;
    }

    // Boş zemin: her şeyi kapat.
    clearSelection();
    _closeNestPanel();
    _closeBuildingButtons();
  }

  /// ANA YUVA YÜKSELTME butonu konumu (üst kenara yakınsa alta iner).
  Vector2 _nestUpOffset(Nest nest) =>
      Vector2(0, nest.position.y < 190 ? 76 : -76);

  /// Seçili KENDİ yuvasının yükseltme butonuna dokunulduysa işler.
  bool _tapNestUpgrade(Vector2 pos) {
    final nest = selectedNest;
    final human = game.gameState.humanPlayer;
    if (nest == null ||
        human == null ||
        nest.owner != human ||
        nest.destroyed ||
        nest.upgradeLevel >= 2) {
      return false;
    }
    final c = nest.position + _nestUpOffset(nest);
    if (pos.distanceToSquared(c) >= (_btnR + 3) * (_btnR + 3)) {
      return false;
    }
    if (game.requestNestUpgrade()) AudioController.uiClick();
    return true;
  }

  /// Seçili binanın çevre butonlarından birine dokunulduysa işler.
  bool _tapBuildingButton(Vector2 pos) {
    final b = selectedBuilding;
    final human = game.gameState.humanPlayer;
    if (b == null || human == null || b.owner != human) return false;
    // Kuluçka istasyonunun butonu yoktur (yükseltme/dönüşüm kapalı).
    if (b.type == BuildingType.hatchery) return false;
    final offs = _buttonOffsets(b);
    bool hit(Vector2 off) =>
        pos.distanceToSquared(b.position + off) < (_btnR + 3) * (_btnR + 3);

    // Yükselt.
    if (b.level < b.maxLevel && hit(offs.upgrade)) {
      final cost = b.upgradeCost;
      // LAN istemcisi: yükseltme EMİR olarak host'a gider (host doğrular;
      // sonuç durum yayınıyla döner). Yerel ön kontrol his için yeterli.
      if (game.isNetClient) {
        if (b.canUpgrade(human)) {
          game.netClient!.sendUpgrade(game.buildings.indexOf(b));
          game.registerSpend(cost);
          AudioController.uiClick();
        }
        return true;
      }
      if (b.upgrade(human)) {
        game.registerSpend(cost);
        AudioController.uiClick();
      }
      return true;
    }
    // Değiştir: dönüşüm seçeneklerini aç/kapat.
    if (hit(offs.change)) {
      convertOpen = !convertOpen;
      AudioController.uiClick();
      return true;
    }
    // Dönüşüm seçenekleri (diğer iki bina tipi).
    if (convertOpen) {
      final options = _convertOptions(b);
      final optOffs = [offs.optA, offs.optB];
      for (var i = 0; i < options.length; i++) {
        if (hit(optOffs[i])) {
          if (game.isNetClient) {
            if (human.resources >= kConvertCost) {
              game.netClient!.sendConvert(
                  game.buildings.indexOf(b), options[i].index);
              game.registerSpend(kConvertCost);
              AudioController.uiClick();
              convertOpen = false;
            }
            return true;
          }
          if (human.resources >= kConvertCost &&
              b.convertTo(human, options[i])) {
            game.registerSpend(kConvertCost);
            AudioController.uiClick();
            convertOpen = false;
          }
          return true;
        }
      }
    }
    return false;
  }

  /// Dönüşüm seçenekleri: kuluçka istasyonu HARİÇ (haritaya özeldir,
  /// ne ona çevrilebilir ne de o başka türe çevrilir).
  List<BuildingType> _convertOptions(Building b) => [
        for (final t in BuildingType.values)
          if (t != b.type && t != BuildingType.hatchery) t
      ];

  Building? _ownBuildingAt(Vector2 pos) {
    final human = game.gameState.humanPlayer;
    if (human == null) return null;
    for (final b in game.buildings) {
      if (b.owner == human && b.position.distanceTo(pos) < 36) return b;
    }
    return null;
  }

  /// Dokunulan noktadaki en yakın kendi askeri ([radius] yakalama payıyla).
  UnitComponent? _ownUnitAt(Vector2 pos, {double radius = 18}) {
    final human = game.gameState.humanPlayer;
    if (human == null) return null;
    UnitComponent? best;
    var bestD = radius * radius;
    for (final u in game.spatialGrid.near(pos, radius)) {
      if (u.dead || u.owner.id != human.id) continue;
      final d = u.position.distanceToSquared(pos);
      if (d < bestD) {
        bestD = d;
        best = u;
      }
    }
    return best;
  }

  /// Zincirleme küme seçimi: dokunulan askerden başlayarak,
  /// yarıçap içindeki dostlar ve onların yakınları da (flood-fill) seçilir.
  void selectClusterFrom(UnitComponent seed) {
    clearSelection();
    final visited = <UnitComponent>{seed};
    final queue = <UnitComponent>[seed];
    while (queue.isNotEmpty) {
      final u = queue.removeLast();
      for (final n in game.spatialGrid.near(u.position, kClusterRadius)) {
        if (n.dead || n.owner.id != seed.owner.id) continue;
        if (visited.add(n)) queue.add(n);
      }
    }
    selection.addAll(visited);
    for (final u in selection) {
      u.selected = true;
    }
  }

  void clearSelection() {
    for (final u in selection) {
      u.selected = false;
    }
    selection.clear();
  }

  void beginDrag(Vector2 pos) {
    _pointer.setFrom(pos);
    _dragHatchery = null;
    final nest = _humanNest;

    if (nest != null && pos.distanceTo(nest.position) < kNestTapRadius) {
      selectedNest = nest;
      _dragging = true;
      _dragFromNest = true;
      return;
    }

    // KULUÇKA İSTASYONUNDAN çıkarma: kendi kuluçkanın üstünden sürükle →
    // yuva garnizonu O noktadan sahaya iner (yuvadan sürüklemekle aynı
    // oran/tip; sadece çıkış noktası değişir).
    if (nest != null) {
      final b = _ownBuildingAt(pos);
      if (b != null && b.type == BuildingType.hatchery) {
        selectedNest = nest;
        _dragHatchery = b;
        _dragging = true;
        _dragFromNest = true;
        return;
      }
    }

    final nearSelection = selection.any(
        (u) => !u.dead && u.position.distanceToSquared(pos) < 50 * 50);
    if (nearSelection) {
      _dragging = true;
      _dragFromNest = false;
      return;
    }

    // Kullanışlılık: önce dokunup seçmek ŞART DEĞİL — sürükleme bir kendi
    // askerinin üstünde başlarsa oradaki küme otomatik seçilir ve taşınır.
    final grabbed = _ownUnitAt(pos, radius: 26);
    if (grabbed != null) {
      _closeNestPanel();
      _closeBuildingButtons();
      selectClusterFrom(grabbed);
      _dragging = true;
      _dragFromNest = false;
    }
  }

  void updateDrag(Vector2 delta) {
    if (!_dragging) return;
    _pointer.add(delta);
    _pointer.x = _pointer.x.clamp(0, kGameWidth);
    _pointer.y = _pointer.y.clamp(0, kGameHeight);
    _dragTarget = game.grid.nearestOpen(_pointer);
    _refreshPreview();
  }

  void _refreshPreview() {
    final target = _dragTarget;
    if (target == null) return;
    if (target.distanceToSquared(_lastPathTarget) < 12 * 12) return;
    _lastPathTarget.setFrom(target);

    final source = _dragFromNest
        ? (_dragHatchery?.position ?? selectedNest!.position)
        : _selectionCentroid();
    _previewPath = game.pathfinder.findPath(source, target);
    // KISA MESAFE: düz görüş yolu tek noktayla döner — ok çizilebilsin
    // diye kaynak eklenir (eskiden kısa sürüklemede rota hiç görünmüyordu).
    if (_previewPath.length < 2) {
      _previewPath = [source.clone(), target.clone()];
    }
    _previewCount = _dragFromNest
        ? _plannedDeployCount()
        : selection.where((u) => !u.dead).length;
  }

  Vector2 _selectionCentroid() {
    final c = Vector2.zero();
    var n = 0;
    for (final u in selection) {
      if (u.dead) continue;
      c.add(u.position);
      n++;
    }
    if (n > 0) c.scale(1 / n);
    return c;
  }

  /// Panelde seçili oran/tiple kaç asker çıkacağını (garnizonu bozmadan) hesaplar.
  int _plannedDeployCount() {
    final nest = selectedNest;
    if (nest == null) return 0;
    final fraction = game.deployFraction.value;
    var total = 0;
    nest.garrison.forEach((type, count) {
      total += fraction >= 0.999 ? count : (count * fraction).round();
    });
    return total;
  }

  void endDrag() {
    if (!_dragging) return;
    final target = _dragTarget;
    _dragging = false;
    _dragTarget = null;
    _previewPath = const [];
    _lastPathTarget.setValues(-9999, -9999);
    if (target == null) return;

    if (_dragFromNest) {
      final nest = selectedNest;
      final exit = _dragHatchery?.position;
      _dragHatchery = null;
      if (nest == null || nest.destroyed) return;
      game.requestDeploy(nest, game.deployFraction.value, target,
          exit: exit);
      return;
    }

    // Seçili kümeyi yönlendir — SOL % KAMASI ORDUYU BÖLER: %50 seçiliyse
    // kümenin yalnız yarısı (hedefe en yakın olanlar) yürür, kalanı
    // yerinde bekler. Emir sonrası seçim yürüyen gruba geçer.
    final nest = _humanNest;
    final intoNest = nest != null &&
        target.distanceTo(nest.position) < kNestTapRadius;
    final alive = [
      for (final u in selection)
        if (!u.dead) u,
    ];
    if (alive.isEmpty) return;
    AudioController.moveOrder();

    final frac = game.deployFraction.value;
    List<UnitComponent> movers = alive;
    if (frac < 0.999 && alive.length > 1) {
      alive.sort((a, b) => a.position
          .distanceToSquared(target)
          .compareTo(b.position.distanceToSquared(target)));
      movers = alive.sublist(
          0, (alive.length * frac).ceil().clamp(1, alive.length));
      // Seçim yürüyen kolda kalır; geride kalanlar bırakılır.
      for (final u in selection) {
        u.selected = false;
      }
      selection
        ..clear()
        ..addAll(movers);
      for (final u in movers) {
        u.selected = true;
      }
    }

    // LAN istemcisi: hareket EMİR olarak host'a gider (kimliklerle).
    if (game.isNetClient) {
      final ids = [for (final u in movers) u.netId];
      game.netClient!.sendMove(ids, target, toNest: intoNest);
      return;
    }

    var i = 0;
    for (final u in movers) {
      if (intoNest) {
        u.orderReturnToNest();
      } else {
        final scatter = Vector2(
          math.cos(_goldenAngle * i),
          math.sin(_goldenAngle * i),
        )..scale(9 * math.sqrt(i.toDouble()));
        u.orderMove(target + scatter);
      }
      i++;
    }
  }

  void _closeNestPanel() {
    selectedNest = null;
  }

  void _closeBuildingButtons() {
    selectedBuilding = null;
    convertOpen = false;
  }

  // ------------------------------------------------------------- olaylar

  @override
  void onTapUp(TapUpEvent event) => handleTap(event.localPosition);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    beginDrag(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => updateDrag(event.localDelta);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    endDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    endDrag();
  }

  // ------------------------------------------------------------- çizim

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
    // Ölen/kaldırılan birimleri seçimden ayıkla.
    selection.removeWhere((u) => u.isRemoved);
  }

  @override
  void render(Canvas canvas) {
    final human = game.gameState.humanPlayer;
    if (human == null) return;
    final color = human.color;

    // Seçili kendi binası: menzil dairesi (kule) + çevre ikon butonları.
    final b = selectedBuilding;
    if (b != null && b.owner == human) {
      final center = Offset(b.position.x, b.position.y);
      if (b.type == BuildingType.tower) {
        canvas.drawCircle(
          center,
          b.towerRange,
          Paint()..color = color.withValues(alpha: 0.07),
        );
        canvas.drawCircle(
          center,
          b.towerRange,
          Paint()
            ..color = color.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      _renderBuildingButtons(canvas, b, color);
    }

    // Kuluçkadan sürükleme: çıkış noktası vurgusu (nefes alan halka).
    final hb = _dragHatchery;
    if (_dragging && hb != null) {
      canvas.drawCircle(
        Offset(hb.position.x, hb.position.y),
        26 + math.sin(_pulse * 3) * 2,
        Paint()
          ..color = color.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Seçili yuva vurgusu (panel açıkken nazikçe nefes alır).
    final nest = selectedNest;
    if (nest != null && !nest.destroyed) {
      final r = kNestTapRadius + math.sin(_pulse * 3) * 2;
      canvas.drawCircle(
        Offset(nest.position.x, nest.position.y),
        r,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      // ANA YUVA YÜKSELTMESİ (2 kademe): hız ×2, sonra ANINDA üretim.
      if (nest.owner == human && nest.upgradeLevel < 2) {
        final cost = nest.upgradeLevel == 0
            ? kNestUpgradeCost
            : kNestUpgrade2Cost;
        final canBuy = human.resources >= cost;
        final off = _nestUpOffset(nest);
        final bc = Offset(nest.position.x + off.x, nest.position.y + off.y);
        canvas.drawCircle(bc.translate(0, 2), _btnR,
            Paint()..color = const Color(0x66000000));
        canvas.drawCircle(bc, _btnR, Paint()..color = const Color(0xF0223019));
        canvas.drawCircle(
          bc,
          _btnR,
          Paint()
            ..color = canBuy ? color : const Color(0x40FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        // 1. kademe: çift ok (hız ×2) · 2. kademe: üç ok (ANINDA).
        final col =
            canBuy ? const Color(0xFFE8B33C) : const Color(0x59FFFFFF);
        final chevrons = nest.upgradeLevel == 0
            ? const [3.0, -6.0]
            : const [7.0, -1.0, -9.0];
        for (final dy in chevrons) {
          final head = Path()
            ..moveTo(bc.dx - 8, bc.dy + dy + 5)
            ..lineTo(bc.dx, bc.dy + dy - 3)
            ..lineTo(bc.dx + 8, bc.dy + dy + 5)
            ..close();
          canvas.drawPath(head, Paint()..color = col);
        }
        _label(canvas, '$cost', bc.translate(0, _btnR + 8),
            color: canBuy
                ? const Color(0xFFE8B33C)
                : const Color(0x59FFFFFF));
      }
    }

    // Yetenek sürüklerken/kuruluyken RAKİP yuvaların YASAK BÖLGELERİ
    // görünür: pürüzlü (organik) kırmızı sınır — "buraya atılamaz".
    if (abilityDragSlot != null || pendingAbilitySlot != null) {
      for (final n in game.nests.values) {
        if (n.destroyed || n.owner.eliminated) continue;
        if (n.owner.team == human.team) continue;
        final zone = wavyCircle(
          kAbilityNestExclusion + math.sin(_pulse * 2) * 3,
          (n.position.x + n.position.y).toInt() % 15,
          t: _pulse * 0.4,
        );
        canvas.save();
        canvas.translate(n.position.x, n.position.y);
        canvas.drawPath(zone,
            Paint()..color = const Color(0x14B0553A));
        canvas.drawPath(
          zone,
          Paint()
            ..color = const Color(0xA6B0553A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.restore();
      }
    }

    // Yetenek sürükleme ön izlemesi: hedefte etki alanı halkası.
    final dragSlot = abilityDragSlot;
    final dragPoint = abilityDragPoint;
    if (dragSlot != null && dragPoint != null) {
      final spec = abilitySpecs[game.humanAbilities[dragSlot]]!;
      final radius = spec.global ? 40.0 : spec.radius;
      final center = Offset(dragPoint.x, dragPoint.y);
      final pulse = 1 + math.sin(_pulse * 6) * 0.04;
      // YASAK BÖLGE (rakip yuva dibi): alan kırmızıya döner — bırakırsan
      // yetenek atılmaz, cooldown yanmaz.
      final blocked =
          !spec.global && !game.abilityAllowedAt(human, dragPoint);
      final areaColor =
          blocked ? const Color(0xFFB0553A) : color;
      // Etki alanı KIVRIMLI çizilir (yetenek görsel dili: tam daire yok).
      final area = wavyCircle(radius * pulse,
          (dragPoint.x + dragPoint.y).toInt() % 15,
          t: _pulse);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawPath(
          area, Paint()..color = areaColor.withValues(alpha: 0.12));
      canvas.drawPath(
        area,
        Paint()
          ..color = areaColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (blocked) {
        // Kırmızı çarpı: burası rakip yuvanın korunaklı alanı.
        final x = Paint()
          ..color = const Color(0xFFB0553A)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-11, -11), const Offset(11, 11), x);
        canvas.drawLine(const Offset(-11, 11), const Offset(11, -11), x);
      }
      canvas.restore();
      // Nişangah.
      final cross = Paint()
        ..color = areaColor.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center.translate(-9, 0), center.translate(-3, 0), cross);
      canvas.drawLine(center.translate(3, 0), center.translate(9, 0), cross);
      canvas.drawLine(center.translate(0, -9), center.translate(0, -3), cross);
      canvas.drawLine(center.translate(0, 3), center.translate(0, 9), cross);
    }

    if (!_dragging || _dragTarget == null) return;
    final target = _dragTarget!;

    // Güzergah oku: gerçek rota (A* yolu) boyunca çizgi + ok başı.
    if (_previewPath.length >= 2) {
      final path = Path()
        ..moveTo(_previewPath.first.x, _previewPath.first.y);
      for (final p in _previewPath.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Ok başı (çakışık uçlarda NaN üretme — sadece baş atlanır).
      final tip = _previewPath.last;
      final prev = _previewPath[_previewPath.length - 2];
      final diff = tip - prev;
      if (diff.length2 >= 1e-9) {
        final dir = diff..normalize();
        final left = Vector2(-dir.y, dir.x);
        final headPath = Path()
          ..moveTo(tip.x, tip.y)
          ..lineTo(
              tip.x - dir.x * 12 + left.x * 7, tip.y - dir.y * 12 + left.y * 7)
          ..lineTo(
              tip.x - dir.x * 12 - left.x * 7, tip.y - dir.y * 12 - left.y * 7)
          ..close();
        canvas.drawPath(headPath, Paint()..color = color);
      }
    }

    // Yerleşim ön izlemesi: varış alanı + hayalet askerler.
    final radius = 14 + 9 * math.sqrt(_previewCount.toDouble());
    canvas.drawCircle(
      Offset(target.x, target.y),
      radius,
      Paint()..color = color.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      Offset(target.x, target.y),
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final ghost = Paint()..color = color.withValues(alpha: 0.55);
    for (var i = 0; i < _previewCount; i++) {
      final off = Vector2(
        math.cos(_goldenAngle * i),
        math.sin(_goldenAngle * i),
      )..scale(9 * math.sqrt(i.toDouble()));
      canvas.drawCircle(
          Offset(target.x + off.x, target.y + off.y), 2.6, ghost);
    }
  }

  // ------------------------------------------- bina çevresi ikon butonları

  void _renderBuildingButtons(Canvas canvas, Building b, Color color) {
    final human = game.gameState.humanPlayer!;
    final c = Offset(b.position.x, b.position.y);

    // Seçim vurgusu: nazikçe nefes alan ince halka.
    canvas.drawCircle(
      c,
      24 + math.sin(_pulse * 3) * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Kuluçka istasyonu: yalnız seçim halkası (yükseltme/dönüşüm yok).
    if (b.type == BuildingType.hatchery) return;

    void button(Vector2 off, bool enabled, void Function(Offset) glyph,
        {String? cost}) {
      final bc = c.translate(off.x, off.y);
      // Gölge + gövde + kenarlık (parmakla rahat basılır büyüklükte).
      canvas.drawCircle(
          bc.translate(0, 2), _btnR, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(bc, _btnR, Paint()..color = const Color(0xF0223019));
      canvas.drawCircle(
        bc,
        _btnR,
        Paint()
          ..color = enabled ? color : const Color(0x40FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      glyph(bc);
      if (cost != null) {
        _label(canvas, cost, bc.translate(0, _btnR + 8),
            color: enabled ? const Color(0xFFE8B33C) : const Color(0x59FFFFFF));
      }
    }

    final offs = _buttonOffsets(b);

    // Yükselt: kalın altın çift şerit yukarı ok (+ maliyet).
    // Maks seviyede buton çizilmez.
    if (b.level < b.maxLevel) {
      final canUp = b.canUpgrade(human);
      button(offs.upgrade, canUp, (bc) {
        final col =
            canUp ? const Color(0xFFE8B33C) : const Color(0x59FFFFFF);
        final head = Path()
          ..moveTo(bc.dx - 8, bc.dy + 1)
          ..lineTo(bc.dx, bc.dy - 9)
          ..lineTo(bc.dx + 8, bc.dy + 1)
          ..close();
        canvas.drawPath(head, Paint()..color = col);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: bc.translate(0, 6), width: 7, height: 9),
            const Radius.circular(2),
          ),
          Paint()..color = col,
        );
      }, cost: '${b.upgradeCost}');
    }

    // Değiştir: dairesel yenileme okları (dönüşüm seçeneklerini açar).
    button(offs.change, true, (bc) {
      final p = Paint()
        ..color = const Color(0xFFF2E8D5)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      const r = 8.5;
      final rect = Rect.fromCircle(center: bc, radius: r);
      canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.7, false, p);
      canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.7, false, p);
      final headFill = Paint()..color = const Color(0xFFF2E8D5);
      // Ok başları (arc uçlarında).
      for (final a in [-math.pi * 0.15, math.pi * 0.85]) {
        final tip = bc.translate(math.cos(a) * r, math.sin(a) * r);
        final dir = a + math.pi / 2; // saat yönü teğet
        final head = Path()
          ..moveTo(tip.dx + math.cos(dir) * 5.5, tip.dy + math.sin(dir) * 5.5)
          ..lineTo(tip.dx + math.cos(dir + 2.5) * 4.5,
              tip.dy + math.sin(dir + 2.5) * 4.5)
          ..lineTo(tip.dx + math.cos(dir - 2.5) * 4.5,
              tip.dy + math.sin(dir - 2.5) * 4.5)
          ..close();
        canvas.drawPath(head, headFill);
      }
    });

    // Dönüşüm seçenekleri: hedef binanın GERÇEK oyun çizimi (mini).
    if (convertOpen) {
      final canConvert = human.resources >= kConvertCost;
      final options = _convertOptions(b);
      final optOffs = [offs.optA, offs.optB];
      for (var i = 0; i < options.length; i++) {
        final type = options[i];
        button(optOffs[i], canConvert, (bc) {
          canvas.save();
          canvas.clipPath(
              Path()..addOval(Rect.fromCircle(center: bc, radius: _btnR - 1)));
          canvas.translate(bc.dx, bc.dy);
          canvas.scale(0.48);
          if (!canConvert) {
            canvas.saveLayer(
                null,
                Paint()
                  ..colorFilter = const ColorFilter.mode(
                      Color(0x88000000), BlendMode.srcATop));
          }
          paintBuilding(canvas, type,
              center: Offset(0, type == BuildingType.tower ? 12 : 4),
              time: _pulse,
              seed: 7);
          if (!canConvert) canvas.restore();
          canvas.restore();
        }, cost: '$kConvertCost');
      }
    }
  }

  void _label(Canvas canvas, String text, Offset center,
      {Color color = const Color(0xFFD8C9A3)}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }
}
