import 'dart:async';

import 'package:flame/components.dart';

import '../data/abilities.dart';
import '../data/units.dart';
import '../game/ability_effects.dart';
import '../game/audio_controller.dart';
import '../game/ants_wars_game.dart';
import '../game/game_state.dart';
import '../game/unit_component.dart';
import '../models/building.dart';
import 'lan_client.dart';
import 'lan_protocol.dart';

/// İSTEMCİ köprüsü: host'un DURUM yayınını oyuna uygular, insan girdisini
/// EMİR olarak gönderir. İstemcide simülasyon yoktur — bu köprü sahnenin
/// tek gerçeklik kaynağıdır.
class NetClientBridge {
  NetClientBridge({required this.game, required this.client}) {
    _sub = client.match.stream.listen(_onMessage);
  }

  final AntsWarsGame game;
  final LanClientService client;

  StreamSubscription? _sub;

  /// Son gelen durum (bir sonraki karede uygulanır — en tazesi kazanır).
  Map<String, dynamic>? _pendingState;
  final List<Map<String, dynamic>> _fxQueue = [];
  Map<String, dynamic>? _end;

  void _onMessage(Map<String, dynamic> m) {
    switch (m['t']) {
      case MsgType.state:
        _pendingState = m;
      case MsgType.fx:
        _fxQueue.add(m);
      case MsgType.end:
        _end = m;
    }
  }

  // ---- emir gönderimi (AntsWarsGame/InputController çağırır) ----

  void sendDeploy(double fraction, double x, double y, {Vector2? exit}) =>
      client.sendDeploy(fraction, x, y, ex: exit?.x, ey: exit?.y);

  void sendNestUpgrade() => client.sendNestUpgrade();

  void sendMove(List<int> ids, Vector2 target, {bool toNest = false}) =>
      client.sendMove(ids, target.x, target.y, toNest: toNest);

  void sendAbility(int slot, Vector2? target) =>
      client.sendAbility(slot, target?.x, target?.y);

  void sendProduce(int unitTypeIndex) => client.sendProduce(unitTypeIndex);

  void sendUpgrade(int buildingIndex) => client.sendUpgrade(buildingIndex);

  void sendConvert(int buildingIndex, int newTypeIndex) =>
      client.sendConvert(buildingIndex, newTypeIndex);

  /// Oyun döngüsünden her karede çağrılır (sahne yüklendikten sonra):
  /// bekleyen durum + efekt + son mesajları uygular.
  void applyPending() {
    final st = _pendingState;
    if (st != null) {
      _pendingState = null;
      _applyState(st);
    }
    if (_fxQueue.isNotEmpty) {
      for (final fx in List.of(_fxQueue)) {
        _applyFx(fx);
      }
      _fxQueue.clear();
    }
    final end = _end;
    if (end != null) {
      _end = null;
      _applyEnd(end);
    }
  }

  // ------------------------------------------------------------- durum

  /// Uygulanan anlık görüntü sayısı — karşılaşma ekranı, kurucunun
  /// BAŞLA'sına bununla uyanır (kurucu duraklıyken akış yoktur).
  int snapshotsSeen = 0;

  void _applyState(Map<String, dynamic> m) {
    snapshotsSeen++;
    final gs = game.gameState;

    // BİRİMLER: kimliğe göre eşle — yeni olan doğar, kaybolan silinir.
    final seen = <int>{};
    for (final rec in (m['u'] as List? ?? const [])) {
      final r = rec as List;
      final id = (r[0] as num).toInt();
      final typeIdx = (r[1] as num).toInt();
      final ownerId = (r[2] as num).toInt();
      final x = (r[3] as num).toDouble();
      final y = (r[4] as num).toDouble();
      final hp = (r[5] as num).toDouble();
      final flags = (r[6] as num).toInt();
      if (typeIdx < 0 || typeIdx >= UnitType.values.length) continue;
      final owner = ownerId >= 0 && ownerId < gs.players.length
          ? gs.players[ownerId]
          : null;
      if (owner == null) continue;
      seen.add(id);

      var unit = game.netUnits[id];
      if (unit == null) {
        unit = UnitComponent(
          type: UnitType.values[typeIdx],
          owner: owner,
          position: Vector2(x, y),
        )..netId = id;
        game.netUnits[id] = unit;
        game.units.add(unit);
        game.world.add(unit);
      }
      unit.netSync(
        x: x,
        y: y,
        newHp: hp,
        combat: flags & 1 != 0,
        frozen: flags & 2 != 0,
        hidden: flags & 4 != 0,
      );
    }
    for (final id in List.of(game.netUnits.keys)) {
      if (!seen.contains(id)) {
        game.netUnits[id]?.removeFromParent();
        game.netUnits.remove(id);
      }
    }

    // YUVALAR: garnizon, kraliçe canı, üretim görünümü.
    for (final rec in (m['n'] as List? ?? const [])) {
      final r = rec as List;
      final nest = game.nests[(r[0] as num).toInt()];
      if (nest == null) continue;
      nest.queenHp = (r[1] as num).toDouble();
      final g = r[2] as List;
      nest.garrison.clear();
      for (var i = 0; i < UnitType.values.length && i < g.length; i++) {
        final c = (g[i] as num).toInt();
        if (c > 0) nest.garrison[UnitType.values[i]] = c;
      }
      final qLen = (r[3] as num).toInt();
      final qFirst = (r[4] as num).toInt();
      nest.productionQueue.clear();
      if (qLen > 0 && qFirst >= 0 && qFirst < UnitType.values.length) {
        nest.productionQueue
            .addAll(List.filled(qLen, UnitType.values[qFirst]));
        nest.netProgressOverride = (r[5] as num).toDouble() / 100;
      } else {
        nest.netProgressOverride = 0;
      }
      nest.producedCount = (r[6] as num).toInt();
    }

    // BİNALAR.
    final bRecs = m['b'] as List? ?? const [];
    for (var i = 0; i < bRecs.length && i < game.buildings.length; i++) {
      final r = bRecs[i] as List;
      final b = game.buildings[i];
      final ownerId = (r[0] as num).toInt();
      b.owner = ownerId >= 0 && ownerId < gs.players.length
          ? gs.players[ownerId]
          : null;
      b.level = (r[1] as num).toInt();
      final typeIdx = (r[2] as num).toInt();
      if (typeIdx >= 0 && typeIdx < BuildingType.values.length) {
        b.type = BuildingType.values[typeIdx];
      }
      b.captureProgress = (r[3] as num).toDouble() / 100;
      final capId = (r[4] as num).toInt();
      b.capturingPlayer = capId >= 0 && capId < gs.players.length
          ? gs.players[capId]
          : null;
    }

    // KAYNAKLAR + ELEMELER.
    final res = m['r'] as List? ?? const [];
    for (var i = 0; i < res.length && i < gs.players.length; i++) {
      gs.players[i].resources = (res[i] as num).toInt();
    }
    for (final v in (m['el'] as List? ?? const [])) {
      final id = (v as num).toInt();
      if (id >= 0 && id < gs.players.length) {
        gs.players[id].eliminated = true;
      }
    }

    // KENDİ yetenek bekleme sürelerimiz (host doğrulaması esastır).
    final cds = (m['cd'] as Map?)?['${gs.lan!.localSlot}'] as List?;
    if (cds != null) {
      for (var i = 0;
          i < cds.length && i < game.abilityCooldowns.length;
          i++) {
        game.abilityCooldowns[i] = (cds[i] as num).toDouble();
      }
    }

    // GELGİT.

    // KAZI GEÇİTLERİ.
    final digs = m['dig'] as List?;
    if (digs != null) {
      for (var i = 0; i < digs.length && i < game.digSites.length; i++) {
        final r = digs[i] as List;
        final site = game.digSites[i];
        site.progress = (r[0] as num).toDouble() / 100;
        site.open = (r[1] as num) == 1;
        final diggerId = (r[2] as num).toInt();
        site.digger = diggerId >= 0 && diggerId < gs.players.length
            ? gs.players[diggerId]
            : null;
      }
    }

    // ARI KOVANLARI.
    // YAĞMACI KAMPLARI: doluş/sönme/halka rengi host'tan.
    final camps = m['camp'] as List?;
    if (camps != null) {
      for (var i = 0;
          i < camps.length && i < game.raiderCamps.length;
          i++) {
        final r = camps[i] as List;
        final c = game.raiderCamps[i];
        c.progress = (r[0] as num).toDouble() / 100;
        c.cooldown = (r[1] as num).toDouble() / 10;
        final leaderId = (r[2] as num).toInt();
        c.capturingLeader =
            leaderId >= 0 && leaderId < gs.players.length
                ? gs.players[leaderId]
                : null;
      }
    }

    final wasps = m['wasp'] as List?;
    if (wasps != null) {
      for (var i = 0; i < wasps.length && i < game.waspNests.length; i++) {
        final w = game.waspNests[i];
        final hp = (wasps[i] as num).toDouble();
        w.hp = hp;
        if (hp <= 0 && !w.destroyed) w.destroyed = true;
      }
    }

    // AKREPLER: konum/can/yeniden doğma host'tan.
    final scos = m['sco'] as List?;
    if (scos != null) {
      for (var i = 0;
          i < scos.length && i < game.scorpions.length;
          i++) {
        final r = scos[i] as List;
        game.scorpions[i].netSync(
          (r[0] as num).toDouble(),
          (r[1] as num).toDouble(),
          (r[2] as num).toDouble(),
          (r[3] as num).toDouble() / 10,
        );
      }
    }

    // KALICI AÇILAN ENGELLER (kazılan tıkaç / yıkılan kovan): grid açılır.
    for (final v in (m['clr'] as List? ?? const [])) {
      final idx = (v as num).toInt();
      if (idx < 0 || idx >= game.map.features.length) continue;
      final f = game.map.features[idx];
      if (!game.clearedFeatures.contains(f)) game.clearFeature(f);
    }
  }

  void _applyFx(Map<String, dynamic> m) {
    // Akrep ölümü: yalnız ses (görsel leş durumu senkrondan gelir).
    if (m['scd'] == 1) {
      final x = ((m['x'] as num?) ?? 0).toDouble();
      final y = ((m['y'] as num?) ?? 0).toDouble();
      if (game.fog.isVisible(Vector2(x, y))) AudioController.capture();
      return;
    }
    final a = ((m['a'] as num?) ?? -1).toInt();
    if (a < 0 || a >= AbilityType.values.length) return;
    Vector2? target;
    if (m['x'] != null && m['y'] != null) {
      target = Vector2(
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
      );
    }
    spawnAbilityFxVisual(game, AbilityType.values[a], target,
        ((m['tm'] as num?) ?? -99).toInt());
  }

  void _applyEnd(Map<String, dynamic> m) {
    final gs = game.gameState;
    final human = gs.humanPlayer;
    final lan = gs.lan;
    if (human == null || lan == null) return;
    if (gs.phase != GamePhase.playing) return;
    final winner = ((m['w'] as num?) ?? -1).toInt();

    final stats = <PlayerMatchStats>[];
    for (final rec in (m['st'] as List? ?? const [])) {
      final r = rec as Map;
      final slot = ((r['s'] as num?) ?? -1).toInt();
      if (slot < 0 || slot >= gs.players.length) continue;
      final p = gs.players[slot];
      stats.add(PlayerMatchStats(
        color: p.color,
        isHuman: slot == lan.localSlot,
        ally: p.team == human.team && slot != human.id,
        eliminated: (r['e'] as num?) == 1,
        produced: ((r['pr'] as num?) ?? 0).toInt(),
        goldEarned: ((r['g'] as num?) ?? 0).toInt(),
        buildings: ((r['bl'] as num?) ?? 0).toInt(),
        unitsLost: ((r['ul'] as num?) ?? 0).toInt(),
        name: lan.nameOf(slot),
      ));
    }
    if (stats.isNotEmpty) gs.lastPlayerStats = stats;
    final hist = m['hist'] as List?;
    if (hist != null) {
      gs.lastStrengthHistory = [
        for (final row in hist)
          [for (final v in (row as List)) (v as num).toInt()],
      ];
    }
    gs.totalBuildings =
        ((m['tb'] as num?) ?? game.buildings.length).toInt();
    gs.lastStats = MatchStats(
      duration: game.matchDuration,
      unitsProduced: game.nests[human.id]?.producedCount ?? 0,
      buildingsCaptured: 0,
    );
    gs.endMatch(humanWon: human.team == winner);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
