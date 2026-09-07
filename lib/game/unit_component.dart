import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../data/constants.dart';
import '../data/settings.dart';
import '../data/counters.dart';
import '../data/units.dart';
import '../models/nest.dart';
import '../models/player.dart';
import 'ant_painter.dart';
import 'game_state.dart' show Difficulty;
import 'ant_sprite_cache.dart';
import 'ants_wars_game.dart';
import 'audio_controller.dart';
import 'projectile.dart';

/// Haritadaki tek bir savaşçı karınca.
///
/// Yuvadan çıktıktan sonra hep haritadadır; kendi yuvasına yönlendirilirse
/// içeri girip garnizona katılır. Düşmanla karşılaşınca otomatik savaşır.
class UnitComponent extends PositionComponent
    with HasGameReference<AntsWarsGame> {
  UnitComponent({
    required this.type,
    required this.owner,
    required Vector2 position,
    this.spawnDelay = 0,
  }) : super(
          position: position,
          anchor: Anchor.center,
          size: Vector2.all(30 * unitSpecs[type]!.scale),
          priority: 20,
        );

  final UnitType type;
  final Player owner;

  // ---- LAN senkronu ----

  /// Ağ kimliği: host'ta otomatik atanır, istemcide host'un durum
  /// yayınındaki kimlikle EZİLİR (eşleşme buradan yapılır).
  static int _netCounter = 0;
  int netId = ++_netCounter;

  /// İstemci modunda host konumuna yumuşakça yaklaşılır.
  Vector2? netTarget;
  bool _netMoving = false;
  bool _netCombat = false;

  /// İSTEMCİ: host'un durum kaydını uygular (konum hedefi, can, bayraklar).
  void netSync({
    required double x,
    required double y,
    required double newHp,
    required bool combat,
    required bool frozen,
    required bool hidden,
  }) {
    (netTarget ??= Vector2.zero()).setValues(x, y);
    final wasDead = dead;
    hp = newHp;
    if (dead && !wasDead) priority = 15; // ceset yaşayanların altına
    _netCombat = combat;
    _freezeTimer = frozen ? 0.35 : 0; // buz görseli (yayınla tazelenir)
    spawnDelay = hidden ? 1 : 0; // yuvadan sıralı çıkış gizliliği
  }

  /// SAVAŞ TAKIMI: yuvası düşen oyuncunun askerleri YABANİLEŞİR —
  /// benzersiz negatif takıma geçer ve HERKESİ düşman beller
  /// (eski müttefikleri dahil; herkes de onları vurur).
  int get combatTeam => owner.eliminated ? -(owner.id + 1) : owner.team;

  /// Yuvadan sırayla çıkış efekti: süre dolana dek görünmez ve hareketsiz.
  double spawnDelay;

  UnitSpec get spec => unitSpecs[type]!;

  late double hp = spec.maxHp;
  bool get dead => hp <= 0;
  double _corpseTimer = 0;

  /// Küme seçiminde seçili mi (InputController yönetir).
  bool selected = false;

  List<Vector2> _path = const [];
  int _pathIndex = 0;
  bool _returningToNest = false;

  // ---- savaş durumu ----
  /// Kilitlenilen düşman birimi.
  UnitComponent? target;
  Nest? _nestTarget;
  double _attackCooldown = 0;

  /// Kapan Çene: her yeni hedefe ilk vuruş kritiktir.
  bool _critReady = true;

  /// Kapan Çene: düşük canda bir kez çenesiyle geriye fırlar.
  bool _escapeUsed = false;

  /// Hareket emrinden sonra kısa süre düşman kilitlemez (geri çekilme payı).
  double _aggroSuppress = 0;
  double _aggroScanTimer = -1;

  /// Nöbet noktası: son emirle gidilen yer (ya da boşta savaşa girilen yer).
  /// Kovalamaca bu noktadan [kChaseLeash]'ten fazla uzaklaşamaz.
  Vector2? _guardPos;
  static const double kChaseLeash = 110;
  double _repathCooldown = 0;
  bool _engaged = false;

  /// Düşman algılama yarıçapı.
  static const double aggroRadius = 85;

  // ---- geçici etkiler (yetenek buffları) ----
  double _speedFactor = 1;
  double _speedTimer = 0;
  double _damageFactor = 1;
  double _damageTimer = 0;

  /// Hız çarpanı uygula (yağmur < 1, feromon > 1). Son gelen geçerlidir.
  void applySpeedBuff(double factor, double duration) {
    _speedFactor = factor;
    _speedTimer = duration;
  }

  void applyDamageBuff(double factor, double duration) {
    _damageFactor = factor;
    _damageTimer = duration;
  }

  void healBy(double amount) {
    if (dead) return;
    hp = math.min(hp + amount, spec.maxHp);
  }

  /// Bufflar dahil anlık hareket hızı. BATAKLIKTA herkes yavaşlar.
  double get moveSpeedNow =>
      spec.moveSpeed *
      _speedFactor *
      (game.grid.isSlowAt(position) ? kSwampSlowFactor : 1);

  /// Bakış açısı (radyan; 0 = +x).
  double facing = 0;
  double _walkPhase = 0;
  double _idleTime = 0;
  bool get isMoving =>
      game.isNetClient ? _netMoving : _pathIndex < _path.length;
  bool get inCombat => game.isNetClient ? _netCombat : _engaged;

  static const _turnSpeed = 8.0; // radyan/sn

  @override
  void onMount() {
    super.onMount();
    // deployFromNest anında kaydeder; başka yoldan eklenen birimler için güvence.
    if (!game.units.contains(this)) game.units.add(this);
  }

  @override
  void onRemove() {
    game.units.remove(this);
    game.netUnits.remove(netId);
    super.onRemove();
  }

  /// Birimi hedefe yürütür (yol A* ile hesaplanır).
  /// Savaştaysa hedef bırakılır; kısa süre yeni kilit alınmaz (geri çekilme).
  void orderMove(Vector2 targetPos) {
    _returningToNest = false;
    target = null;
    _nestTarget = null;
    _aggroSuppress = 1.2;
    // Nöbet noktası: buradan fazla uzaklaşan kovalamaca iptal edilir.
    (_guardPos ??= Vector2.zero()).setFrom(targetPos);
    _path = game.pathfinder.findPath(position, targetPos);
    _pathIndex = 0;
  }

  /// ORTAK ROTA: kol lideri için BİR kez hesaplanan yolu paylaşarak yürü —
  /// birim başına A* çağrısı yapılmaz (büyük ordu emirlerinin ucuz yolu).
  /// Rotadan sapmalar _chase/yeniden-rota güvenceleriyle toparlanır.
  void orderMoveShared(List<Vector2> route, Vector2 dest) {
    _returningToNest = false;
    target = null;
    _nestTarget = null;
    _aggroSuppress = 1.2;
    (_guardPos ??= Vector2.zero()).setFrom(dest);
    _path = [...route, dest];
    _pathIndex = 0;
    // Gerideki ara noktaları atla: rotaya en yakın ileri noktadan katıl.
    var bestD = double.infinity;
    for (var i = 0; i < _path.length; i++) {
      final d = _path[i].distanceToSquared(position);
      if (d < bestD) {
        bestD = d;
        _pathIndex = i;
      }
    }
  }

  /// Kendi yuvasına dönüp içeri girme emri (savunma güçlendirme).
  void orderReturnToNest() {
    final nest = game.nests[owner.id]!;
    if (nest.destroyed) return;
    orderMove(nest.position);
    _returningToNest = true;
  }

  /// Hasar al; ölürse ceset kısa süre kalır, sonra kaybolur.
  // Zırh Feromonu: gelen hasar çarpanı (1 = etkisiz).
  double _armorMult = 1;
  double _armorTimer = 0;

  void applyArmorBuff(double mult, double duration) {
    _armorMult = mult;
    _armorTimer = duration;
  }

  // Dondurma: kalan buz süresi (hareket + saldırı tamamen durur).
  double _freezeTimer = 0;

  /// Şu an donmuş mu (durum yayını için).
  bool get frozenNow => _freezeTimer > 0;

  /// ArmyLayer için: gövde karesinin yürüyüş fazı (donmuşken kıpırdamaz;
  /// savaşırken bacaklar boğuşma temposunda).
  double get renderWalkPhase => _freezeTimer <= 0 && (isMoving || inCombat)
      ? _walkPhase + (inCombat ? _idleTime * 6 : 0)
      : 0.0;

  /// ArmyLayer için: ceset solma alfası (0..0.7).
  double get corpseAlpha => (1 - _corpseTimer / 4).clamp(0.0, 1.0) * 0.7;

  /// Dondurma: birim [duration] boyunca buz tutar.
  void applyFreeze(double duration) {
    _freezeTimer = math.max(_freezeTimer, duration);
    target = null;
  }

  /// Korku Çığlığı: [from] noktasından kaçar, süre boyunca savaşamaz.
  void applyFear(Vector2 from, double duration) {
    _aggroSuppress = math.max(_aggroSuppress, duration);
    target = null;
    orderMove(game.grid.nearestOpen(position + _safeAway(from) * 130));
  }

  /// YARALI GERİ ÇEKİLME: bu asker yuvaya kaçış modunda mı?
  bool _fleeingHome = false;

  void takeDamage(double amount) {
    if (dead) return;
    // Feromon merkezi zırhı: sahibin güç binaları alınan hasarı azaltır.
    hp -= amount * _armorMult * game.powerArmorMultiplier(owner);
    // YARALI GERİ ÇEKİLME (ayar açıksa, YEREL insan oyuncunun askerleri):
    // %20 canın altına düşen asker savaşı bırakıp yuvaya kaçar; içeri
    // girince tam canla garnizona katılır. LAN'da yalnız simülasyonu
    // yapan cihazın kendi askerlerine uygulanır.
    // ZOR/KÂBUS BOTLARI DA ÇEKİLİR: yaralıyı kurtarmak etkin can demektir
    // — bot ordusu aynı altınla daha uzun savaşır (zorluk artışı,
    // kaynak hilesi değil). Yabaniler (eliminated) kaçmaz.
    final botRetreats = owner.isBot &&
        !owner.eliminated &&
        game.gameState.difficulty.index >= Difficulty.hard.index;
    if (!dead &&
        !_fleeingHome &&
        ((appSettings.autoRetreat &&
                !owner.isBot &&
                !owner.remote &&
                !game.isNetClient) ||
            (botRetreats && !game.isNetClient)) &&
        hp < spec.maxHp * 0.2) {
      final home = game.nests[owner.id];
      if (home != null && !home.destroyed) {
        _fleeingHome = true;
        orderReturnToNest();
        _aggroSuppress = 999; // yolda yeni savaşa girmez (kaçak koşusu)
      }
    }
    if (dead) {
      _path = const [];
      target = null;
      priority = 15; // cesetler yaşayanların altına
      owner.unitsLost++; // maç sonu çizelgesi
    }
  }

  // ------------------------------------------------------------- güncelleme

  /// Son bilinen GEÇERLİ konum (çökme güvenlik ağı için).
  Vector2? _lastSafePos;

  /// Sıfır vektörü normalize etmek NaN üretir; NaN konum grid indeksinde
  /// UNSUPPORTED hatasıyla OYUNU ÇÖKERTİR. Üst üste binen birimlerde
  /// sabit bir kaçış yönü döndürülür.
  Vector2 _safeAway(Vector2 from) {
    final d = position - from;
    if (d.length2 < 1e-9) return Vector2(1, 0);
    return d..normalize();
  }

  /// İSTEMCİ karesi: host konumuna yumuşak yaklaşım + yürüyüş/ceset görseli.
  /// Savaş, yol bulma, ayrışma — hepsi host'ta; burada yalnız sunum var.
  void _clientUpdate(double dt) {
    _idleTime += dt;
    if (_freezeTimer > 0) _freezeTimer -= dt;
    if (dead) {
      _corpseTimer = math.min(_corpseTimer + dt, 3.6); // host 4 sn'de siler
      return;
    }
    if (spawnDelay > 0) return; // görünürlük bayrağı yayınla açılır
    final t = netTarget;
    if (t == null) return;
    final dx = t.x - position.x;
    final dy = t.y - position.y;
    final d2 = dx * dx + dy * dy;
    if (d2 > 90 * 90) {
      // Kopukluk/ışınlanma (korku, kapan çene): yumuşatmadan yapıştır.
      position.setValues(t.x, t.y);
      _netMoving = false;
      return;
    }
    if (d2 < 0.5) {
      _netMoving = false;
      return;
    }
    final k = math.min(1.0, dt * 10);
    position.x += dx * k;
    position.y += dy * k;
    _netMoving = d2 > 6;
    if (_netMoving) {
      _walkPhase += math.sqrt(d2) * k * 0.45;
      _faceTowards(t, dt);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isNetClient) {
      _clientUpdate(dt);
      return;
    }
    _idleTime += dt;

    // Güvenlik ağı: konum herhangi bir yolla NaN/sonsuz olduysa son güvenli
    // konuma dön — tek bir bozuk değer tüm oyunu düşürmesin.
    if (!position.x.isFinite || !position.y.isFinite) {
      position.setFrom(_lastSafePos ?? Vector2(kGameWidth / 2, kGameHeight / 2));
    } else {
      (_lastSafePos ??= Vector2.zero()).setFrom(position);
    }

    // HARİTA DIŞI YASAK: itilme/kaçış/korku dışarı taşırdıysa asker
    // anında sahaya geri sabitlenir (kenardan kaybolan karınca olmaz).
    if (position.x < 8 ||
        position.x > kGameWidth - 8 ||
        position.y < 8 ||
        position.y > kGameHeight - 8) {
      position.x = position.x.clamp(8.0, kGameWidth - 8.0);
      position.y = position.y.clamp(8.0, kGameHeight - 8.0);
      if (game.grid.isBlockedAt(position)) {
        position.setFrom(game.grid.nearestOpen(position));
      }
    }

    if (dead) {
      _corpseTimer += dt;
      if (_corpseTimer > 4) removeFromParent();
      return;
    }

    if (spawnDelay > 0) {
      spawnDelay -= dt;
      return;
    }

    // Buz: hareket ve saldırı tamamen durur (hasar almaya devam eder).
    if (_freezeTimer > 0) {
      _freezeTimer -= dt;
      return;
    }

    // Kaçış modundayken yuva düştüyse: pasiflik kilidi çözülür.
    if (_fleeingHome && (game.nests[owner.id]?.destroyed ?? true)) {
      _fleeingHome = false;
      _aggroSuppress = 0;
    }

    _attackCooldown -= dt;
    _aggroSuppress -= dt;
    _armorTimer -= dt;
    if (_armorTimer <= 0) _armorMult = 1;
    _repathCooldown -= dt;
    if (_speedTimer > 0) {
      _speedTimer -= dt;
      if (_speedTimer <= 0) _speedFactor = 1;
    }
    if (_damageTimer > 0) {
      _damageTimer -= dt;
      if (_damageTimer <= 0) _damageFactor = 1;
    }

    _updateCombat(dt);
    if (!_engaged) _followPath(dt);
    // PERFORMANS: ayrışma itmesi dönüşümlü karelerde çalışır (etki dt×2
    // ile korunur) — kalabalıkta en pahalı komşu taraması yarıya iner.
    if (((netId + game.frameNo) & 1) == 0) _separate(dt * 2);
    _checkNestEntry();
  }

  // ------------------------------------------------------------- savaş

  void _updateCombat(double dt) {
    _engaged = false;

    if (target != null && (target!.dead || target!.isRemoved)) {
      target = null;
      _critReady = true;
    }
    if (_aggroSuppress > 0) {
      target = null;
      _nestTarget = null;
      return;
    }

    // En yakın düşmana kilitlen (tahsissiz tarama).
    // PERFORMANS: boştaki birim her karede değil ~8 karede bir tarar —
    // büyük ordularda (yuva sv3: 165 birim/oyuncu) tarama maliyeti düşer.
    if (target == null) {
      if (_aggroScanTimer < 0) {
        // İlk kare: konumdan türetilen faz — tüm ordu aynı karede taramasın.
        _aggroScanTimer = ((position.x + position.y) % 12) / 100;
      }
      _aggroScanTimer -= dt;
      if (_aggroScanTimer <= 0) {
        _aggroScanTimer = 0.12;
        UnitComponent? best;
        var bestD = aggroRadius * aggroRadius;
        game.spatialGrid.forEachNear(position, aggroRadius, (u) {
          if (u.dead || u.combatTeam == combatTeam) return;
          final d = u.position.distanceToSquared(position);
          if (d < bestD) {
            bestD = d;
            best = u;
          }
        });
        if (best != null) {
          target = best;
          _critReady = true;
          // Boşta dururken savaşa giren asker bulunduğu yeri nöbet noktası
          // yapar — kaçan düşmanı fazla kovalarsa oraya geri döner.
          _guardPos ??= position.clone();
        }
      }
    }

    if (target != null) {
      _engaged = true;
      _engageUnit(dt);
      return;
    }

    // Düşman birimi yoksa: yakın düşman yuvasını kuşat.
    _nestTarget ??= _nearestEnemyNest();
    if (_nestTarget != null) {
      if (_nestTarget!.destroyed) {
        _nestTarget = null;
        return;
      }
      _engaged = true;
      _engageNest(dt);
    }
  }

  Nest? _nearestEnemyNest() {
    Nest? best;
    var bestD = 90.0 * 90.0;
    for (final nest in game.nests.values) {
      if (nest.destroyed || nest.owner.team == combatTeam) continue;
      final d = nest.position.distanceToSquared(position);
      if (d < bestD) {
        bestD = d;
        best = nest;
      }
    }
    return best;
  }

  void _engageUnit(double dt) {
    final t = target!;
    final dist = position.distanceTo(t.position);
    _faceTowards(t.position, dt);

    if (dist > spec.attackRange + 6) {
      // TASMA: nöbet noktasından fazla uzaklaşan kovalamaca iptal —
      // kaçan düşmanın peşinde ordu dağılmasın, asker yerine dönsün.
      final guard = _guardPos;
      if (guard != null &&
          position.distanceToSquared(guard) > kChaseLeash * kChaseLeash) {
        target = null;
        _aggroSuppress = 1.0;
        orderMove(game.grid.nearestOpen(guard));
        return;
      }
      _chase(dt, t.position);
      return;
    }

    if (_attackCooldown <= 0) {
      _attackCooldown = spec.attackCooldown;
      _attack(t);
    }

    // Menzilli birim vur-kaç yapar: düşman sokulursa geri açılır (kite).
    // Yavaş tanklara karşı üstünlük buradan gelir; hızlı düşmanlar yetişir.
    if (spec.ranged && dist < spec.attackRange * 0.55) {
      final away = _safeAway(t.position);
      final step = moveSpeedNow * dt;
      final next = position + away * step;
      if (!game.grid.isBlockedAt(next)) {
        position.setFrom(next);
        _walkPhase += step * 0.45;
      }
    }

    // Kapan Çene: düşük canda çenesiyle kendini geriye fırlatır (bir kez).
    if (spec.firstStrike && !_escapeUsed && hp < spec.maxHp * 0.35) {
      _escapeUsed = true;
      final away = _safeAway(t.position);
      for (final jump in [70.0, 45.0, 25.0]) {
        final next = position + away * jump;
        if (!game.grid.isBlockedAt(next)) {
          position.setFrom(next);
          break;
        }
      }
      target = null;
      _critReady = true;
      _aggroSuppress = 0.5;
    }
  }

  void _attack(UnitComponent t) {
    var dmg = computeAttackDamage(t);
    if (spec.firstStrike && _critReady) _critReady = false;
    final audible = game.fog.isVisible(position);
    if (spec.ranged) {
      // Formik asit püskürtme.
      if (audible) AudioController.acidSpit();
      game.world.add(Projectile(
        position: position.clone(),
        target: t,
        damage: dmg,
        speed: 300,
      ));
    } else {
      if (audible) AudioController.bite();
      t.takeDamage(dmg);
    }
  }

  /// Bu birimin [t]'ye vuracağı hasar: temel × counter × güç binası bonusu
  /// × özel mekanikler (kritik, sürü bonusu).
  double computeAttackDamage(UnitComponent t) {
    var dmg = spec.damage *
        counterMultiplier(type, t.type) *
        game.powerMultiplier(owner) *
        _damageFactor;
    if (spec.firstStrike && _critReady) dmg *= 3;
    return dmg;
  }

  void _engageNest(double dt) {
    final nest = _nestTarget!;
    final dist = position.distanceTo(nest.position);
    _faceTowards(nest.position, dt);
    if (dist > 55) {
      _chase(dt, nest.position);
      return;
    }
    if (_attackCooldown <= 0) {
      _attackCooldown = spec.attackCooldown;
      nest.receiveAttack(spec.damage * game.powerMultiplier(owner));
      // Garnizon misillemesi: dolu yuvaya saldırmak bedelsiz değil.
      if (nest.population > 0) {
        takeDamage((nest.defensePower * 0.3).clamp(0, 15));
      }
    }
  }

  /// Hedefe doğru düz koşu; engel araya girerse A* ile dolan.
  void _chase(double dt, Vector2 goal) {
    final delta = goal - position;
    final dist = delta.length;
    if (dist < 0.01) return;
    final dir = delta / dist;
    final step = math.min(moveSpeedNow * dt, dist);
    final next = position + dir * step;
    if (!game.grid.isBlockedAt(next)) {
      position.setFrom(next);
      _walkPhase += step * 0.45;
      return;
    }
    // A* pahalı: yalnızca gerçekten sıkışınca ve seyrek yeniden hesapla.
    if (_repathCooldown <= 0 && dist > 30) {
      _repathCooldown = 1.4;
      _path = game.pathfinder.findPath(position, goal);
      _pathIndex = 0;
    }
    _followPath(dt);
  }

  void _faceTowards(Vector2 p, double dt) {
    final targetAngle = math.atan2(p.y - position.y, p.x - position.x);
    var diff = (targetAngle - facing) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;
    facing += diff.clamp(-_turnSpeed * dt, _turnSpeed * dt);
  }

  // ------------------------------------------------------------- hareket

  void _followPath(double dt) {
    if (!isMoving) return;
    final waypoint = _path[_pathIndex];
    final delta = waypoint - position;
    final dist = delta.length;
    if (dist < 4) {
      _pathIndex++;
      return;
    }

    final dir = delta / dist;
    _faceTowards(waypoint, dt);
    final step = math.min(moveSpeedNow * dt, dist);
    position += dir * step;
    _walkPhase += step * 0.45; // bacak döngüsü yol ile senkron
  }

  /// Basit ayrışma: üst üste binen dostları iter (engellere itmez).
  /// Tahsissiz tarama + tekrar kullanılan vektörler (GC baskısı yok).
  static final Vector2 _pushBuf = Vector2.zero();
  static final Vector2 _nextBuf = Vector2.zero();

  void _separate(double dt) {
    _pushBuf.setZero();
    game.spatialGrid.forEachNear(position, 13, (other) {
      if (identical(other, this) || other.dead) return;
      final dx = position.x - other.position.x;
      final dy = position.y - other.position.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 0.01) {
        _pushBuf.x += math.cos(_idleTime * 7);
        _pushBuf.y += math.sin(_idleTime * 7);
      } else {
        final f = (1 - d / 13) / d;
        _pushBuf.x += dx * f;
        _pushBuf.y += dy * f;
      }
    });
    if (_pushBuf.length2 == 0) return;
    _nextBuf
      ..setFrom(position)
      ..addScaled(_pushBuf, 40 * dt);
    if (!game.grid.isBlockedAt(_nextBuf)) position.setFrom(_nextBuf);
  }

  void _checkNestEntry() {
    if (!_returningToNest) return;
    final nest = game.nests[owner.id]!;
    if (nest.destroyed) {
      _returningToNest = false;
      return;
    }
    if (position.distanceToSquared(nest.position) < 34 * 34) {
      nest.returnUnits({type: 1});
      removeFromParent();
    }
  }

  // ------------------------------------------------------------- çizim

  /// Önbellekten karınca karesi basar (performans: tek drawImageRect).
  void _drawCachedAnt(Canvas canvas, double phase, double alpha) {
    final cache = AntSpriteCache.instance;
    final atlas = cache.atlas;
    if (atlas == null) {
      // Önbellek hazır değilse (ilk kareler) doğrudan çiz.
      paintAnt(canvas, type,
          walkPhase: phase, idleTime: _idleTime, teamColor: owner.color);
      return;
    }
    const he = AntSpriteCache.halfExtent;
    canvas.drawImageRect(
      atlas,
      cache.frameRect(type, phase),
      const Rect.fromLTWH(-he, -he, he * 2, he * 2),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..filterQuality = FilterQuality.medium,
    );
    // Takım kimliği: abdomen tamamen takım renginde boyanır (gövdeye
    // işlenmiş görünüm — halka/daire yok). Cesetlerde çizilmez.
    if (alpha >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(-6.5, 0), width: 9.4, height: 6.4),
        Paint()..color = owner.color.withValues(alpha: 0.85),
      );
      // Doğal parlama (asset ile bütünleşsin).
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(-7, -1.2), width: 5, height: 2),
        Paint()..color = const Color(0x59FFFFFF),
      );
    }
  }

  /// PERFORMANS: gövde/gölge/ceset ArmyLayer atlasından TEK çağrıda
  /// basılır — birim, ağaca yalnız nadir ekstraları (seçim, buz, can
  /// barı; atlas hazır değilken tam çizim) gerektiğinde girer. 600
  /// birimlik save/transform + komut seli böyle kalkar.
  bool get _needsOwnRender {
    if (!AntSpriteCache.instance.ready) return true;
    if (spawnDelay > 0 || dead) return false;
    // Can barları da ArmyLayer'da çizilir — ağaca yalnız seçim/buz girer.
    return selected || _freezeTimer > 0;
  }

  @override
  void renderTree(Canvas canvas) {
    if (!_needsOwnRender) return;
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    if (spawnDelay > 0) return;

    // Sis: düşman birimleri görünür alan dışındaysa çizilmez.
    final human = game.gameState.humanPlayer;
    if (human != null &&
        owner.id != human.id &&
        !game.fog.isVisible(position)) {
      return;
    }

    // Atlas devredeyken SEÇİLİ birim tam yoldan çizilir (halka gövdenin
    // altında kalmalı); diğer ekstralar gövdesiz bindirilir.
    final atlasLive = AntSpriteCache.instance.ready;
    final fullBody = !atlasLive || (selected && !dead);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    if (dead) {
      // Ceset: soluk, hafif dönük, yavaşça kaybolur (yalnız atlas yokken).
      canvas.rotate(facing + 2.6);
      canvas.scale(spec.scale);
      _drawCachedAnt(canvas, 0, corpseAlpha);
      canvas.restore();
      return;
    }

    // Seçim vurgusu: gövdenin altında yumuşak takım rengi halkası.
    if (selected) {
      canvas.drawCircle(
        Offset.zero,
        12 * spec.scale,
        Paint()..color = owner.color.withValues(alpha: 0.22),
      );
      canvas.drawCircle(
        Offset.zero,
        12 * spec.scale,
        Paint()
          ..color = owner.color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    if (fullBody) {
      // Gölge.
      canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(0, 1.5),
            width: 20 * spec.scale,
            height: 9 * spec.scale),
        Paint()..color = const Color(0x33000000),
      );
    }

    canvas.rotate(facing);
    canvas.scale(spec.scale);
    if (fullBody) _drawCachedAnt(canvas, renderWalkPhase, 1);
    // Buz kaplaması: yarı saydam buz kütlesi + parlama.
    if (_freezeTimer > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 18),
        Paint()..color = const Color(0xFFBFE6F5).withValues(alpha: 0.45),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 18),
        Paint()
          ..color = const Color(0xFFE8F6FC).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(const Offset(-5, -4), const Offset(-1, -7),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..strokeWidth = 1.2);
    }
    canvas.restore();

    // Can barı: sadece hasarlıyken (atlas devredeyken ArmyLayer çizer;
    // burada yalnız tam çizim yolunda tekrar edilir — çift bar olmasın).
    if (fullBody && hp < spec.maxHp) {
      final ratio = (hp / spec.maxHp).clamp(0.0, 1.0);
      final w = size.x * 0.7;
      final rect = Rect.fromLTWH((size.x - w) / 2, -3, w, 2.5);
      canvas.drawRect(rect, Paint()..color = const Color(0x99000000));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, w * ratio, 2.5),
        Paint()
          ..color = Color.lerp(
              const Color(0xFFD32F2F), const Color(0xFF7CB342), ratio)!,
      );
    }
  }
}
