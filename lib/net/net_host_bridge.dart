import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';

import '../data/abilities.dart';
import '../data/constants.dart';
import '../data/units.dart';
import '../game/ability_effects.dart';
import '../game/ants_wars_game.dart';
import '../game/bot_controller.dart';
import '../game/game_state.dart';
import '../game/scorpion_component.dart';
import '../game/unit_component.dart';
import '../models/building.dart';
import '../models/player.dart';
import 'lan_host.dart';
import 'lan_protocol.dart';

/// HOST köprüsü: LanHostService ile AntsWarsGame arasını kurar.
///
/// - İstemci EMİRLERİNİ sahiplik/kaynak denetimiyle oyuna uygular.
/// - 10 Hz DURUM yayını üretir (birimler, yuvalar, binalar, kaynaklar...).
/// - Uzak insanların yetenek bekleme sürelerini yönetir.
/// - Bağlantısı kopan oyuncunun kolonisini BOT devralır.
/// - Maç sonunu ilan eder (tek takım kalınca) ve karneleri yayınlar.
class NetHostBridge {
  NetHostBridge({required this.game, required this.host}) {
    final lan = game.gameState.lan!;
    for (final meta in lan.players) {
      if (meta.isBot || meta.slot == lan.localSlot) continue;
      final abilities = [
        for (final i in meta.loadout)
          if (i >= 0 && i < AbilityType.values.length) AbilityType.values[i],
      ];
      _remoteAbilities[meta.slot] =
          abilities.isEmpty ? List.of(defaultLoadout) : abilities;
      _remoteCooldowns[meta.slot] = [
        for (final t in _remoteAbilities[meta.slot]!) abilitySpecs[t]!.cooldown,
      ];
    }
    _cmdSub = host.commands.stream.listen(_onCommand);
    _lostSub = host.playerLost.stream.listen(_onPlayerLost);
  }

  final AntsWarsGame game;
  final LanHostService host;

  /// Uzak oyuncu slot → yetenek yükü ve kalan bekleme süreleri.
  final Map<int, List<AbilityType>> _remoteAbilities = {};
  final Map<int, List<double>> _remoteCooldowns = {};

  StreamSubscription? _cmdSub;
  StreamSubscription? _lostSub;
  double _acc = 0;
  bool _ended = false;

  static const _goldenAngle = 2.399963;

  Player? _playerAt(int slot) {
    for (final p in game.gameState.players) {
      if (p.id == slot) return p;
    }
    return null;
  }

  /// Her karede çağrılır (host simülasyonundan sonra): uzak bekleme
  /// süreleri iner, aralık dolunca durum yayını çıkar.
  void tick(double dt) {
    for (final cds in _remoteCooldowns.values) {
      for (var i = 0; i < cds.length; i++) {
        if (cds[i] > 0) cds[i] -= dt;
      }
    }
    _acc += dt;
    final interval = 1 / kSnapshotHz;
    if (_acc < interval) return;
    _acc %= interval;
    host.broadcast(_snapshot());
  }

  // ------------------------------------------------------------- emirler

  void _onCommand((int, Map<String, dynamic>) cmd) {
    final (slot, m) = cmd;
    // Sahne yüklenmeden (grid/nests hazır değil) emir işlenmez.
    if (!game.isLoaded) return;
    if (game.gameState.phase != GamePhase.playing || game.countdown > 0) {
      return;
    }
    final player = _playerAt(slot);
    if (player == null || player.eliminated) return;

    double numOf(String k) => ((m[k] as num?) ?? 0).toDouble();
    Vector2 pointOf() => game.grid.nearestOpen(Vector2(
          numOf('x').clamp(0, kGameWidth),
          numOf('y').clamp(0, kGameHeight),
        ));

    switch (m['t']) {
      case MsgType.deploy:
        final nest = game.nests[slot];
        if (nest == null || nest.destroyed) return;
        // ex/ey: kuluçkadan tut-sürükle çıkışı (deployFromNest yalnız
        // oyuncunun KENDİ kuluçkasıysa kabul eder).
        Vector2? exit;
        if (m.containsKey('ex') && m.containsKey('ey')) {
          exit = Vector2(
            numOf('ex').clamp(0, kGameWidth),
            numOf('ey').clamp(0, kGameHeight),
          );
        }
        game.deployFromNest(nest, numOf('f').clamp(0.1, 1.0), pointOf(),
            exitOverride: exit);

      case MsgType.move:
        final ids = {
          for (final v in (m['ids'] as List? ?? const [])) (v as num).toInt()
        };
        if (ids.isEmpty) return;
        final toNest = m['r'] == 1;
        final target = pointOf();
        var i = 0;
        for (final u in List.of(game.units)) {
          if (u.dead || u.owner.id != slot || !ids.contains(u.netId)) {
            continue;
          }
          if (toNest) {
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

      case MsgType.ability:
        final s = ((m['s'] as num?) ?? -1).toInt();
        final abilities = _remoteAbilities[slot];
        final cds = _remoteCooldowns[slot];
        if (abilities == null || cds == null) return;
        if (s < 0 || s >= abilities.length || cds[s] > 0) return;
        final type = abilities[s];
        final spec = abilitySpecs[type]!;
        Vector2? target;
        if (!spec.global) {
          if (m['x'] == null || m['y'] == null) return;
          target = Vector2(
            numOf('x').clamp(0, kGameWidth),
            numOf('y').clamp(0, kGameHeight),
          );
        }
        // Yasak bölge (rakip yuva dibi) host'ta da doğrulanır.
        if (!game.abilityAllowedAt(player, target)) return;
        castAbility(game, player, type, target);
        cds[s] = spec.cooldown;

      case MsgType.nestUp:
        game.buyNestUpgrade(player);

      case MsgType.produce:
        final u = ((m['u'] as num?) ?? -1).toInt();
        if (u < 0 || u >= UnitType.values.length) return;
        game.nests[slot]?.enqueue(UnitType.values[u]);

      case MsgType.upgrade:
        final i = ((m['i'] as num?) ?? -1).toInt();
        if (i < 0 || i >= game.buildings.length) return;
        game.buildings[i].upgrade(player);

      case MsgType.convert:
        final i = ((m['i'] as num?) ?? -1).toInt();
        final u = ((m['u'] as num?) ?? -1).toInt();
        if (i < 0 || i >= game.buildings.length) return;
        if (u < 0 || u >= BuildingType.values.length) return;
        game.buildings[i].convertTo(player, BuildingType.values[u]);
    }
  }

  /// Bağlantısı kopan oyuncu: kolonisini BOT devralır (maç bozulmaz).
  void _onPlayerLost(int slot) {
    final player = _playerAt(slot);
    if (player == null || player.eliminated) return;
    if (game.gameState.phase != GamePhase.playing) return;
    final taken = game.bots.any((b) => b.player.id == slot);
    if (!taken) game.bots.add(BotController(game, player));
    _remoteCooldowns.remove(slot); // yetenekleri artık bot mantığı yönetmez
    _remoteAbilities.remove(slot);
  }

  // ------------------------------------------------------------- yayınlar

  /// AKREP ÖLDÜ: ödülü kazanan istemciye "+altın" uçuşu için bildirim
  /// (kaynak zaten durum yayınıyla senklenir; bu yalnız görsel geribildirim).
  void broadcastScorpionDeath(ScorpionComponent sc) {
    host.broadcast({
      't': MsgType.fx,
      'scd': 1,
      'p': -1, // ödül sahibi kaynak senkronundan görünür; slot gerekmez
      'x': sc.position.x.round(),
      'y': sc.position.y.round(),
    });
  }

  /// Yetenek görseli tüm istemcilerde patlasın (castAbility çağırır).
  void broadcastFx(AbilityType type, Vector2? target, int casterTeam) {
    host.broadcast({
      't': MsgType.fx,
      'a': type.index,
      if (target != null) 'x': target.x.round(),
      if (target != null) 'y': target.y.round(),
      'tm': casterTeam,
    });
  }

  int _unitFlags(UnitComponent u) {
    var f = 0;
    if (u.inCombat) f |= 1;
    if (u.frozenNow) f |= 2;
    if (u.spawnDelay > 0) f |= 4;
    return f;
  }

  Map<String, dynamic> _snapshot() {
    final gs = game.gameState;
    return {
      't': MsgType.state,
      'u': [
        for (final u in game.units)
          [
            u.netId,
            u.type.index,
            u.owner.id,
            u.position.x.round(),
            u.position.y.round(),
            u.dead ? 0 : u.hp.ceil(),
            _unitFlags(u),
          ],
      ],
      'n': [
        for (final e in game.nests.entries)
          [
            e.key,
            e.value.queenHp.round(),
            [for (final t in UnitType.values) e.value.garrison[t] ?? 0],
            e.value.productionQueue.length,
            e.value.productionQueue.isEmpty
                ? -1
                : e.value.productionQueue.first.index,
            (e.value.productionProgress * 100).round(),
            e.value.producedCount,
          ],
      ],
      'b': [
        for (final b in game.buildings)
          [
            b.owner?.id ?? -1,
            b.level,
            b.type.index,
            (b.captureProgress * 100).round(),
            b.capturingPlayer?.id ?? -1,
          ],
      ],
      'r': [for (final p in gs.players) p.resources],
      'cd': {
        for (final e in _remoteCooldowns.entries)
          '${e.key}': [
            for (final v in e.value) (v * 10).round() / 10,
          ],
      },
      'el': [
        for (final p in gs.players)
          if (p.eliminated) p.id,
      ],
      if (game.digSites.isNotEmpty)
        'dig': [
          for (final s in game.digSites)
            [
              (s.progress * 100).round(),
              s.open ? 1 : 0,
              s.digger?.id ?? -1,
            ],
        ],
      if (game.raiderCamps.isNotEmpty)
        'camp': [
          for (final c in game.raiderCamps)
            [
              (c.progress * 100).round(),
              (c.cooldown * 10).round(),
              c.capturingLeader?.id ?? -1,
            ],
        ],
      if (game.waspNests.isNotEmpty)
        'wasp': [
          for (final w in game.waspNests)
            w.destroyed ? 0 : w.hp.round(),
        ],
      if (game.scorpions.isNotEmpty)
        'sco': [
          for (final sc in game.scorpions)
            [
              sc.position.x.round(),
              sc.position.y.round(),
              sc.hp.round(),
              (sc.respawnLeft * 10).round(),
            ],
        ],
      if (game.clearedFeatures.isNotEmpty)
        'clr': [
          for (final f in game.clearedFeatures)
            game.map.features.indexOf(f),
        ],
    };
  }

  /// Elemeler değişince çağrılır: TEK takım kaldıysa sonu ilan et —
  /// karneleri yayınla, yerel sonucu kur (host elense de maç sürer).
  void checkMatchEnd() {
    if (_ended) return;
    final gs = game.gameState;
    final aliveTeams = <int>{
      for (final p in gs.players)
        if (!p.eliminated) p.team,
    };
    if (aliveTeams.length > 1) return;
    _ended = true;
    final winner = aliveTeams.isEmpty ? -1 : aliveTeams.first;

    final rawStats = [
      for (final p in gs.players)
        {
          's': p.id,
          'e': p.eliminated ? 1 : 0,
          'pr': game.nests[p.id]?.producedCount ?? 0,
          'g': p.goldEarned,
          'bl': game.buildings.where((b) => b.owner?.id == p.id).length,
          'ul': p.unitsLost,
        },
    ];
    host.broadcast({
      't': MsgType.end,
      'w': winner,
      'st': rawStats,
      'tb': game.buildings.length,
      'hist': game.strengthHistory,
    });

    final human = gs.humanPlayer;
    if (human == null) return;
    final lan = gs.lan!;
    gs.lastStrengthHistory = List.of(game.strengthHistory);
    gs.lastStats = MatchStats(
      duration: game.matchDuration,
      unitsProduced: game.nests[human.id]?.producedCount ?? 0,
      buildingsCaptured: game.captureCounts[human.id] ?? 0,
    );
    gs.lastPlayerStats = [
      for (final p in gs.players)
        PlayerMatchStats(
          color: p.color,
          isHuman: p.id == human.id,
          ally: p.team == human.team && p.id != human.id,
          eliminated: p.eliminated,
          produced: game.nests[p.id]?.producedCount ?? 0,
          goldEarned: p.goldEarned,
          buildings: game.buildings.where((b) => b.owner?.id == p.id).length,
          unitsLost: p.unitsLost,
          name: lan.nameOf(p.id),
        ),
    ];
    gs.totalBuildings = game.buildings.length;
    gs.endMatch(humanWon: human.team == winner);
  }

  Future<void> dispose() async {
    await _cmdSub?.cancel();
    await _lostSub?.cancel();
    _cmdSub = null;
    _lostSub = null;
  }
}
