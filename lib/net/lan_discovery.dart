import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'lan_protocol.dart';

/// KEŞİF YAYINCISI (host tarafı): oyun bilgisini periyodik olarak
/// yerel ağa UDP broadcast eder.
class LanBeacon {
  LanBeacon({required LanGameInfo Function() infoBuilder})
      : _infoBuilder = infoBuilder;

  final LanGameInfo Function() _infoBuilder;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;
    _timer = Timer.periodic(kBeaconInterval, (_) => _send());
    _send();
  }

  void _send() {
    final s = _socket;
    if (s == null) return;
    final body = utf8.encode(jsonEncode(_infoBuilder().toJson()));
    try {
      s.send(body, InternetAddress('255.255.255.255'), kLanDiscoveryPort);
    } catch (_) {}
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

/// KEŞİF DİNLEYİCİSİ (katıl tarafı): yayınları toplar, güncel oyun
/// listesini [games] olarak sunar; [kBeaconTimeout] içinde yenilenmeyen
/// kayıtlar düşer.
class LanDiscovery {
  final ValueNotifier<List<LanGameInfo>> games = ValueNotifier(const []);

  RawDatagramSocket? _socket;
  Timer? _prune;
  final Map<String, (LanGameInfo, DateTime)> _seen = {};

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, kLanDiscoveryPort,
        reuseAddress: true, reusePort: !Platform.isAndroid);
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket!.receive();
      if (dg == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(dg.data));
        if (decoded is! Map<String, dynamic>) return;
        final info =
            LanGameInfo.fromJson(decoded, dg.address.address);
        if (info == null) return;
        _seen['${info.address}:${info.port}'] = (info, DateTime.now());
        _publish();
      } catch (_) {}
    });
    _prune = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final before = _seen.length;
      _seen.removeWhere((_, v) => now.difference(v.$2) > kBeaconTimeout);
      if (_seen.length != before) _publish();
    });
  }

  void _publish() {
    final list = _seen.values.map((v) => v.$1).toList()
      ..sort((a, b) => a.hostName.compareTo(b.hostName));
    games.value = list;
  }

  void stop() {
    _prune?.cancel();
    _prune = null;
    _socket?.close();
    _socket = null;
    _seen.clear();
    games.value = const [];
  }
}
