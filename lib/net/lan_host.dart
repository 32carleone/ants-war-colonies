import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'lan_discovery.dart';
import 'lan_protocol.dart';

class _Client {
  _Client(this.socket) {
    decoder = FrameDecoder((m) => onMessage?.call(m));
    // Yazma tarafı hatası (kaba kopan bağlantıya add) asenkron gelir ve
    // yutulmazsa YAKALANMAMIŞ hata olur — kopuş zaten okuma tarafında
    // (_drop) ele alınıyor.
    socket.done.catchError((_) {});
  }

  final Socket socket;
  late final FrameDecoder decoder;
  void Function(Map<String, dynamic>)? onMessage;
  int? slot;
  String name = '';
  List<int> loadout = const [];

  void send(Map<String, dynamic> msg) {
    try {
      socket.add(encodeFrame(msg));
    } catch (_) {}
  }
}

/// OYUN KURAN cihazın servisi: TCP lobisi + UDP duyurusu; maç başlayınca
/// EMİRLERİ toplar ve DURUM yayınlar. Oyun mantığına dokunmaz —
/// köprü (NetHostBridge) game ile arasını kurar.
class LanHostService {
  LanHostService({
    required this.hostName,
    required this.mapId,
    required this.mapName,
    required this.mode,
    required this.playerCount,
    required this.localLoadout,
  });

  final String hostName;
  final String mapId;
  final String mapName;
  final LanMode mode;
  final int playerCount;
  final List<int> localLoadout;

  /// Kurucunun slotu — lobide yer değiştirilebilir (2v2'de takım seçimi).
  int hostSlot = 0;

  /// Bot zorluğu (Difficulty.index) — lobide herkese gösterilir,
  /// botları yalnız host simüle ettiği için oyun kurallarını host uygular.
  int difficultyIndex = 1;

  ServerSocket? _server;
  LanBeacon? _beacon;
  final List<_Client> _clients = [];
  bool _started = false;
  bool _disposed = false;
  int port = kLanGamePort;

  /// Lobi görünümü (UI dinler): slot sırasına göre oyuncular.
  final ValueNotifier<List<LanPlayerMeta>> lobby = ValueNotifier(const []);

  /// LOBİ SOHBETİ: (slot, hazır mesaj indexi) — son 6 mesaj.
  final ValueNotifier<List<(int, int)>> chats = ValueNotifier(const []);

  void _pushChat(int slot, int msg) {
    final list = List.of(chats.value)..add((slot, msg));
    if (list.length > 6) list.removeAt(0);
    chats.value = list;
  }

  /// Kurucunun hazır mesaj göndermesi: yerelde eklenir + herkese yayınlanır.
  void sendChat(int msg) {
    _pushChat(hostSlot, msg);
    broadcast({'t': MsgType.chat, 's': hostSlot, 'm': msg});
  }

  /// Maç sırasında gelen emirler: (slot, mesaj).
  final StreamController<(int, Map<String, dynamic>)> commands =
      StreamController.broadcast();

  /// Maç sırasında kopan oyuncular (slot) — köprü botla devralır.
  final StreamController<int> playerLost = StreamController.broadcast();

  /// Başlat sinyali (start yayınlandıktan sonra UI maça geçsin).
  void Function(int seed, List<LanPlayerMeta> players)? onStarted;

  int teamForSlot(int slot) =>
      mode == LanMode.teams2v2 ? (slot < 2 ? 0 : 1) : slot;

  Future<void> start() async {
    // Port meşgulse birkaç ardılı dene (aynı cihazda iki oturum vb).
    for (var p = kLanGamePort; p < kLanGamePort + 8; p++) {
      try {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, p);
        port = p;
        break;
      } catch (_) {}
    }
    _server ??= await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    port = _server!.port;
    // onError: kaba kopan bağlantı (RST) dinleyici akışına hata düşürebilir;
    // yutulmazsa uygulamayı deviren yakalanmamış hataya dönüşür.
    _server!.listen(_accept, onError: (_) {});

    _beacon = LanBeacon(
      infoBuilder: () => LanGameInfo(
        hostName: hostName,
        mapId: mapId,
        mapName: mapName,
        mode: mode,
        playerCount: playerCount,
        joined: humanCount,
        port: port,
        address: '',
      ),
    );
    await _beacon!.start();
    _publishLobby();
  }

  int get humanCount =>
      1 + _clients.where((c) => c.slot != null).length;

  void _accept(Socket socket) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    final client = _Client(socket);
    client.onMessage = (m) => _handle(client, m);
    _clients.add(client);
    socket.listen(
      client.decoder.add,
      onDone: () => _drop(client),
      onError: (_) => _drop(client),
    );
  }

  void _drop(_Client client) {
    if (!_clients.remove(client)) return;
    final slot = client.slot;
    client.slot = null;
    try {
      client.socket.destroy();
    } catch (_) {}
    if (slot != null && !_disposed) {
      if (_started) {
        playerLost.add(slot); // maçta: koloniyi bot devralır
      } else {
        _publishLobby();
      }
    }
  }

  /// [slot] şu an bir İNSAN tarafından dolu mu?
  bool _slotTaken(int slot) =>
      slot == hostSlot ||
      _clients.any((c) => c.slot == slot);

  /// Kurucu lobide yer değiştirir (yalnız boş/bot slotlara).
  bool moveSelf(int desired) {
    if (_started || desired < 0 || desired >= playerCount) return false;
    if (_slotTaken(desired)) return false;
    hostSlot = desired;
    _publishLobby();
    return true;
  }

  void _handle(_Client client, Map<String, dynamic> m) {
    switch (m['t']) {
      case MsgType.join:
        if (_started || client.slot != null) return;
        final slot = _freeSlot();
        if (slot == null) {
          client.send({'t': MsgType.kick});
          return;
        }
        client.slot = slot;
        client.name = _uniqueName((m['n'] as String?) ?? 'Oyuncu');
        client.loadout = [
          for (final v in (m['l'] as List? ?? const [])) (v as num).toInt()
        ];
        _publishLobby();
      case MsgType.chat:
        // Hazır mesaj: kurucuda görünür + tüm istemcilere aktarılır.
        final slot = client.slot;
        final msg = ((m['m'] as num?) ?? -1).toInt();
        if (slot == null || _disposed || msg < 0 || msg > 15) return;
        _pushChat(slot, msg);
        broadcast({'t': MsgType.chat, 's': slot, 'm': msg});
      case MsgType.slot:
        // Lobide yer değiştirme isteği: yalnız boş/bot slotlara geçilir.
        if (_started || client.slot == null) return;
        final desired = ((m['s'] as num?) ?? -1).toInt();
        if (desired < 0 || desired >= playerCount) return;
        if (_slotTaken(desired)) return;
        client.slot = desired;
        _publishLobby();
      default:
        final slot = client.slot;
        if (_started && slot != null && !_disposed) {
          commands.add((slot, m));
        }
    }
  }

  int? _freeSlot() {
    final used = {hostSlot, ..._clients.map((c) => c.slot).whereType<int>()};
    for (var s = 0; s < playerCount; s++) {
      if (!used.contains(s)) return s;
    }
    return null;
  }

  String _uniqueName(String name) {
    final taken = {hostName, ..._clients.map((c) => c.name)};
    var out = name.trim().isEmpty ? 'Oyuncu' : name.trim();
    var i = 2;
    while (taken.contains(out)) {
      out = '$name ($i)';
      i++;
    }
    return out;
  }

  /// Lobi meta listesi: insanlar + kalan slotlar BOT.
  List<LanPlayerMeta> buildPlayers() {
    final metas = <LanPlayerMeta>[
      LanPlayerMeta(
          slot: hostSlot,
          name: hostName,
          team: teamForSlot(hostSlot),
          isBot: false,
          loadout: localLoadout),
      for (final c in _clients)
        if (c.slot != null)
          LanPlayerMeta(
              slot: c.slot!,
              name: c.name,
              team: teamForSlot(c.slot!),
              isBot: false,
              loadout: c.loadout),
    ];
    final used = metas.map((m) => m.slot).toSet();
    for (var s = 0; s < playerCount; s++) {
      if (!used.contains(s)) {
        metas.add(LanPlayerMeta(
            slot: s, name: 'Bot', team: teamForSlot(s), isBot: true));
      }
    }
    metas.sort((a, b) => a.slot.compareTo(b.slot));
    return metas;
  }

  void _publishLobby() {
    final players = buildPlayers();
    lobby.value = players;
    for (final c in _clients) {
      if (c.slot == null) continue;
      c.send({
        't': MsgType.lobby,
        'players': [for (final p in players) p.toJson()],
        'mapId': mapId,
        'mapName': mapName,
        'mode': mode.index,
        'd': difficultyIndex,
        'hs': hostSlot, // kurucunun slotu (taç işareti)
        'you': c.slot, // alıcının KENDİ slotu ("SEN" işareti güvenilir olsun)
      });
    }
  }

  /// Maçı başlat: seed + kurulum herkese gider; duyuru durur.
  void startGame() {
    if (_started) return;
    _started = true;
    _beacon?.stop();
    final seed = math.Random().nextInt(1 << 30);
    final players = buildPlayers();
    for (final c in _clients) {
      final slot = c.slot;
      if (slot == null) {
        c.send({'t': MsgType.kick});
        continue;
      }
      c.send({
        't': MsgType.start,
        'seed': seed,
        'mapId': mapId,
        'mode': mode.index,
        'slot': slot,
        'players': [for (final p in players) p.toJson()],
      });
    }
    onStarted?.call(seed, players);
  }

  void broadcast(Map<String, dynamic> msg) {
    for (final c in _clients) {
      if (c.slot != null) c.send(msg);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _beacon?.stop();
    for (final c in List.of(_clients)) {
      c.send({'t': MsgType.closed});
      try {
        await c.socket.flush();
      } catch (_) {}
      c.socket.destroy();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    await commands.close();
    await playerLost.close();
  }
}
