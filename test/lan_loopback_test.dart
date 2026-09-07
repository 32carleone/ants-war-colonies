import 'dart:async';

import 'package:ants_wars/net/lan_client.dart';
import 'package:ants_wars/net/lan_host.dart';
import 'package:ants_wars/net/lan_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

/// GERÇEK soketlerle (127.0.0.1) host + istemci lobisi uçtan uca test edilir.
/// UDP keşif atlanır (test makinesinde yayın güvenilmez) — doğrudan bağlanılır.
void main() {
  test('katıl → lobi → başlat akışı (loopback)', () async {
    final host = LanHostService(
      hostName: 'Kurucu',
      mapId: 'nile_delta',
      mapName: 'Nil Deltası',
      mode: LanMode.teams2v2,
      playerCount: 4,
      localLoadout: const [0, 1, 2],
    );
    await host.start();
    addTearDown(host.dispose);

    final client = LanClientService(
        playerName: 'Misafir', loadout: const [3, 4, 5]);
    final lobbySeen = Completer<List<LanPlayerMeta>>();
    client.lobby.addListener(() {
      if (client.lobby.value.isNotEmpty && !lobbySeen.isCompleted) {
        lobbySeen.complete(client.lobby.value);
      }
    });
    final started = Completer<(int, int, List<LanPlayerMeta>)>();
    client.onStart =
        (seed, slot, players) => started.complete((seed, slot, players));

    await client.connect('127.0.0.1', host.port);
    addTearDown(client.dispose);

    // Lobi yayını: kurucu + misafir + 2 bot; misafir 1. slotta.
    final lobby =
        await lobbySeen.future.timeout(const Duration(seconds: 5));
    expect(lobby, hasLength(4));
    expect(lobby[0].name, 'Kurucu');
    expect(lobby[0].isBot, isFalse);
    expect(lobby[1].name, 'Misafir');
    expect(lobby[1].isBot, isFalse);
    expect(lobby[2].isBot, isTrue);
    expect(lobby[3].isBot, isTrue);
    // 2v2 takımları: slot 0-1 takım 0, slot 2-3 takım 1.
    expect([for (final p in lobby) p.team], [0, 0, 1, 1]);
    expect(client.mapName, 'Nil Deltası');
    expect(client.mode, LanMode.teams2v2);

    // Host tarafında da aynı lobi.
    expect(host.lobby.value, hasLength(4));
    expect(host.humanCount, 2);

    // Başlat: istemciye seed + slot + oyuncular gider.
    host.startGame();
    final (seed, slot, players) =
        await started.future.timeout(const Duration(seconds: 5));
    expect(slot, 1);
    expect(seed, greaterThanOrEqualTo(0));
    expect(players, hasLength(4));
    expect(players[1].loadout, [3, 4, 5]); // yetenek yükü korunur
  });

  test('lobide yer değiştirme: boş slota geçilir, dolu slot reddedilir',
      () async {
    final host = LanHostService(
      hostName: 'Kurucu',
      mapId: 'four_corners',
      mapName: 'Tuna Kıyıları',
      mode: LanMode.teams2v2,
      playerCount: 4,
      localLoadout: const [0, 1, 2],
    );
    await host.start();
    addTearDown(host.dispose);

    final client =
        LanClientService(playerName: 'Misafir', loadout: const []);
    var updates = 0;
    Completer<void> next = Completer();
    client.lobby.addListener(() {
      updates++;
      if (!next.isCompleted) next.complete();
    });
    Future<void> waitUpdate() async {
      next = Completer();
      await next.future.timeout(const Duration(seconds: 5));
    }

    await client.connect('127.0.0.1', host.port);
    await next.future.timeout(const Duration(seconds: 5)); // ilk lobi
    expect(client.mySlot, 1);
    expect(client.lobby.value[1].team, 0); // slot 1 → takım 1

    // Karşı takıma geç (slot 3): kabul edilir, takım değişir.
    client.sendSlot(3);
    await waitUpdate();
    expect(client.mySlot, 3);
    final me3 =
        client.lobby.value.firstWhere((p) => p.name == 'Misafir');
    expect(me3.slot, 3);
    expect(me3.team, 1);
    expect(client.lobby.value[1].isBot, isTrue); // eski yer bota döndü

    // DOLU slota (kurucunun 0'ı) geçme isteği REDDEDİLİR.
    final before = updates;
    client.sendSlot(0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(client.mySlot, 3, reason: 'Dolu slota geçilmemeli');
    expect(updates, before, reason: 'Reddedilen istek lobi yayınlamaz');

    // Kurucu da yer değiştirebilir (slot 2'ye) — herkese yayınlanır.
    expect(host.moveSelf(3), isFalse); // Misafir'in yeri dolu
    expect(host.moveSelf(2), isTrue);
    await waitUpdate();
    expect(client.hostSlotIndex, 2);
    expect(client.lobby.value[2].name, 'Kurucu');
    expect(client.lobby.value[2].team, 1);
  });

  test('lobi sohbeti: hazır mesaj herkese dağıtılır', () async {
    final host = LanHostService(
      hostName: 'Kurucu',
      mapId: 'nile_delta',
      mapName: 'Nil Deltası',
      mode: LanMode.ffa,
      playerCount: 3,
      localLoadout: const [],
    );
    await host.start();
    addTearDown(host.dispose);

    final client =
        LanClientService(playerName: 'Misafir', loadout: const []);
    final joined = Completer<void>();
    client.lobby.addListener(() {
      if (client.lobby.value.isNotEmpty && !joined.isCompleted) {
        joined.complete();
      }
    });
    await client.connect('127.0.0.1', host.port);
    addTearDown(client.dispose);
    await joined.future.timeout(const Duration(seconds: 5));

    // İstemci mesaj atar → host görür + geri yayınlar (istemci de görür).
    final clientSees = Completer<void>();
    client.chats.addListener(() {
      if (client.chats.value.isNotEmpty && !clientSees.isCompleted) {
        clientSees.complete();
      }
    });
    client.sendChat(3); // "Başlat!"
    await clientSees.future.timeout(const Duration(seconds: 5));
    expect(host.chats.value, contains((1, 3)));
    expect(client.chats.value, contains((1, 3)));

    // Host mesaj atar → istemciye ulaşır.
    host.sendChat(0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(client.chats.value, contains((0, 0)));
  });

  test('aynı isimli ikinci oyuncu "(2)" ekiyle ayrışır', () async {
    final host = LanHostService(
      hostName: 'Ali',
      mapId: 'nile_delta',
      mapName: 'Nil Deltası',
      mode: LanMode.ffa,
      playerCount: 3,
      localLoadout: const [0, 1, 2],
    );
    await host.start();
    addTearDown(host.dispose);

    Future<LanClientService> join(String name) async {
      final c = LanClientService(playerName: name, loadout: const []);
      await c.connect('127.0.0.1', host.port);
      addTearDown(c.dispose);
      return c;
    }

    await join('Ali');
    final c2 = await join('Ali');
    final done = Completer<void>();
    c2.lobby.addListener(() {
      if (c2.lobby.value.length == 3 && !done.isCompleted) done.complete();
    });
    if (c2.lobby.value.length != 3) {
      await done.future.timeout(const Duration(seconds: 5));
    }
    final names = [for (final p in c2.lobby.value) p.name];
    expect(names.toSet().length, 3); // hepsi benzersiz
    expect(names, contains('Ali'));
    expect(names.where((n) => n.startsWith('Ali')).length, 3);
  });

  test('dolu lobiye katılan kibarca reddedilir', () async {
    final host = LanHostService(
      hostName: 'Kurucu',
      mapId: 'nile_delta',
      mapName: 'Nil Deltası',
      mode: LanMode.ffa,
      playerCount: 2,
      localLoadout: const [],
    );
    await host.start();
    addTearDown(host.dispose);

    final c1 = LanClientService(playerName: 'Bir', loadout: const []);
    await c1.connect('127.0.0.1', host.port);
    addTearDown(c1.dispose);

    final c2 = LanClientService(playerName: 'İki', loadout: const []);
    final rejected = Completer<String>();
    c2.onClosed = rejected.complete;
    await c2.connect('127.0.0.1', host.port);
    addTearDown(c2.dispose);

    final reason =
        await rejected.future.timeout(const Duration(seconds: 5));
    expect(reason, isNotEmpty);
  });

  test('maçta kopan istemci playerLost yayınlar (bot devralımı)', () async {
    final host = LanHostService(
      hostName: 'Kurucu',
      mapId: 'nile_delta',
      mapName: 'Nil Deltası',
      mode: LanMode.ffa,
      playerCount: 3,
      localLoadout: const [],
    );
    await host.start();
    addTearDown(host.dispose);

    final client =
        LanClientService(playerName: 'Kaçak', loadout: const []);
    final joined = Completer<void>();
    client.lobby.addListener(() {
      if (client.lobby.value.isNotEmpty && !joined.isCompleted) {
        joined.complete();
      }
    });
    await client.connect('127.0.0.1', host.port);
    await joined.future.timeout(const Duration(seconds: 5));

    final lost = Completer<int>();
    host.playerLost.stream.listen(lost.complete);
    host.startGame();
    await client.dispose(); // bağlantıyı kes

    final slot = await lost.future.timeout(const Duration(seconds: 5));
    expect(slot, 1);
  });
}
