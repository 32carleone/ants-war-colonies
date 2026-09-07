import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/i18n.dart';
import 'lan_protocol.dart';

/// OYUNA KATILAN cihazın servisi: host'a TCP ile bağlanır, lobiyi
/// dinler, maçta EMİR gönderir ve DURUM yayınını akıtır.
class LanClientService {
  LanClientService({required this.playerName, required this.loadout});

  final String playerName;
  final List<int> loadout;

  Socket? _socket;

  /// Lobi görünümü (UI dinler).
  final ValueNotifier<List<LanPlayerMeta>> lobby = ValueNotifier(const []);
  String mapName = '';
  String mapId = '';
  LanMode mode = LanMode.ffa;

  /// Lobide BENİM slotum (host yayınlar) — "SEN" işareti ve yer değiştirme.
  int? mySlot;

  /// LOBİ SOHBETİ: (slot, hazır mesaj indexi) — son 6 mesaj.
  final ValueNotifier<List<(int, int)>> chats = ValueNotifier(const []);

  /// Kurucunun seçtiği bot zorluğu (Difficulty.index) — lobide gösterilir.
  int difficultyIndex = 1;

  /// Kurucunun slotu (taç işareti — kurucu da yer değiştirebilir).
  int hostSlotIndex = 0;

  /// Maç başladı: (seed, benim slotum, oyuncular).
  void Function(int seed, int slot, List<LanPlayerMeta> players)? onStart;

  /// Host kapattı / bağlantı koptu / yer yok.
  void Function(String reason)? onClosed;

  /// Maç akışı mesajları (state / fx / end) — köprü dinler.
  final StreamController<Map<String, dynamic>> match =
      StreamController.broadcast();

  bool _connected = false;

  Future<void> connect(String address, int port) async {
    final socket = await Socket.connect(address, port,
        timeout: const Duration(seconds: 5));
    socket.setOption(SocketOption.tcpNoDelay, true);
    // Yazma tarafı hatası asenkron gelir; yutulmazsa yakalanmamış hata olur
    // (kopuş okuma tarafındaki onDone/onError ile zaten ele alınıyor).
    socket.done.catchError((_) {});
    _socket = socket;
    _connected = true;
    final decoder = FrameDecoder(_handle);
    socket.listen(
      decoder.add,
      onDone: () => _lost(loc('Bağlantı koptu', 'Connection lost')),
      onError: (_) => _lost(loc('Bağlantı koptu', 'Connection lost')),
    );
    send({'t': MsgType.join, 'n': playerName, 'l': loadout});
  }

  void _handle(Map<String, dynamic> m) {
    switch (m['t']) {
      case MsgType.lobby:
        mapId = (m['mapId'] as String?) ?? mapId;
        mapName = (m['mapName'] as String?) ?? mapName;
        mode = LanMode.values[(m['mode'] as num?)?.toInt() ?? 0];
        mySlot = (m['you'] as num?)?.toInt() ?? mySlot;
        difficultyIndex =
            (m['d'] as num?)?.toInt() ?? difficultyIndex;
        hostSlotIndex = (m['hs'] as num?)?.toInt() ?? hostSlotIndex;
        lobby.value = [
          for (final p in (m['players'] as List))
            LanPlayerMeta.fromJson(p as Map<String, dynamic>)
        ];
      case MsgType.start:
        mapId = (m['mapId'] as String?) ?? mapId;
        mode = LanMode.values[(m['mode'] as num?)?.toInt() ?? 0];
        onStart?.call(
          (m['seed'] as num).toInt(),
          (m['slot'] as num).toInt(),
          [
            for (final p in (m['players'] as List))
              LanPlayerMeta.fromJson(p as Map<String, dynamic>)
          ],
        );
      case MsgType.chat:
        final list = List.of(chats.value)
          ..add((
            ((m['s'] as num?) ?? -1).toInt(),
            ((m['m'] as num?) ?? -1).toInt(),
          ));
        if (list.length > 6) list.removeAt(0);
        chats.value = list;
      case MsgType.closed:
        _lost(loc('Kurucu lobiyi kapattı', 'The host closed the lobby'));
      case MsgType.kick:
        _lost(loc('Oyunda yer kalmadı', 'No room left in the game'));
      default:
        match.add(m);
    }
  }

  void _lost(String reason) {
    if (!_connected) return;
    _connected = false;
    onClosed?.call(reason);
  }

  void send(Map<String, dynamic> msg) {
    try {
      _socket?.add(encodeFrame(msg));
    } catch (_) {}
  }

  /// Hazır lobi mesajı gönder (host herkese dağıtır).
  void sendChat(int msg) => send({'t': MsgType.chat, 'm': msg});

  /// Lobide yer değiştirme isteği (yalnız boş/bot slotlara geçilir;
  /// host doğrular, sonuç lobi yayınıyla döner).
  void sendSlot(int desired) => send({'t': MsgType.slot, 's': desired});

  // ---- oyun emirleri ----
  void sendDeploy(double fraction, double x, double y,
          {int? only, double? ex, double? ey}) =>
      send({
        't': MsgType.deploy,
        'f': fraction,
        'x': x,
        'y': y,
        'o': ?only,
        'ex': ?ex, // çıkış noktası (kuluçkadan tut-sürükle)
        'ey': ?ey,
      });

  /// Ana yuva yükseltmesi isteği (host doğrular ve uygular).
  void sendNestUpgrade() => send({'t': MsgType.nestUp});

  void sendMove(List<int> ids, double x, double y, {bool toNest = false}) =>
      send({
        't': MsgType.move,
        'ids': ids,
        'x': x,
        'y': y,
        if (toNest) 'r': 1,
      });

  void sendAbility(int slot, double? x, double? y) => send({
        't': MsgType.ability,
        's': slot,
        'x': ?x,
        'y': ?y,
      });

  void sendProduce(int unitTypeIndex) =>
      send({'t': MsgType.produce, 'u': unitTypeIndex});

  void sendUpgrade(int buildingIndex) =>
      send({'t': MsgType.upgrade, 'i': buildingIndex});

  void sendConvert(int buildingIndex, int newTypeIndex) =>
      send({'t': MsgType.convert, 'i': buildingIndex, 'u': newTypeIndex});

  Future<void> dispose() async {
    _connected = false;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    await match.close();
  }
}
