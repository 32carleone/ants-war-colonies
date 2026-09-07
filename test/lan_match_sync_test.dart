import 'dart:async';
import 'dart:math' as math;

import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/net/lan_client.dart';
import 'package:ants_wars/net/lan_host.dart';
import 'package:ants_wars/net/lan_protocol.dart';
import 'package:ants_wars/net/net_client_bridge.dart';
import 'package:ants_wars/net/net_host_bridge.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UÇTAN UCA LAN MAÇI (loopback): host simüle eder, istemci durum yayınını
/// uygular; istemcinin emirleri host'ta işler. Gerçek soketler kullanılır.
void main() {
  testWidgets('host simülasyonu istemciye akar, istemci emri host\'ta işler',
      (tester) async {
    late LanHostService host;
    late LanClientService client;
    late int seed;
    late int mySlot;
    late List<LanPlayerMeta> players;

    await tester.runAsync(() async {
      host = LanHostService(
        hostName: 'Kurucu',
        mapId: riverCrossing.id,
        mapName: riverCrossing.name,
        mode: LanMode.ffa,
        playerCount: 2,
        localLoadout: const [0, 1, 2],
      );
      await host.start();
      client =
          LanClientService(playerName: 'Misafir', loadout: const [0, 1, 2]);
      final started = Completer<(int, int, List<LanPlayerMeta>)>();
      client.onStart = (s, sl, p) => started.complete((s, sl, p));
      final joined = Completer<void>();
      client.lobby.addListener(() {
        if (client.lobby.value.isNotEmpty && !joined.isCompleted) {
          joined.complete();
        }
      });
      await client.connect('127.0.0.1', host.port);
      await joined.future.timeout(const Duration(seconds: 5));
      host.startGame();
      (seed, mySlot, players) =
          await started.future.timeout(const Duration(seconds: 5));
    });
    addTearDown(() async {
      await host.dispose();
      await client.dispose();
    });
    expect(mySlot, 1);

    // İki taraf da AYNI kurulumla maçı kurar.
    final hostState = GameState()
      ..startLanMatch(
        map: riverCrossing,
        seed: seed,
        localSlot: 0,
        mode: LanMode.ffa,
        lanPlayers: players,
        host: host,
      );
    final clientState = GameState()
      ..startLanMatch(
        map: riverCrossing,
        seed: seed,
        localSlot: mySlot,
        mode: LanMode.ffa,
        lanPlayers: players,
        client: client,
      );
    final hostGame =
        AntsWarsGame(gameState: hostState, rng: math.Random(seed))
          ..countdown = 0;
    final clientGame =
        AntsWarsGame(gameState: clientState, rng: math.Random(seed))
          ..countdown = 0;

    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        Expanded(child: GameWidget(game: hostGame)),
        Expanded(child: GameWidget(game: clientGame)),
      ]),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    hostGame.netHost = NetHostBridge(game: hostGame, host: host);
    clientGame.netClient = NetClientBridge(game: clientGame, client: client);
    hostGame.bots.clear(); // deterministik akış: bot karışmasın

    // PAYLAŞILAN TOHUM: yuvalar iki cihazda da aynı noktadadır.
    expect(hostGame.nests[0]!.position, clientGame.nests[0]!.position);
    expect(hostGame.nests[1]!.position, clientGame.nests[1]!.position);
    expect(clientGame.isNetClient, isTrue);
    expect(clientGame.bots, isEmpty,
        reason: 'İstemci bot simüle etmez — botlar host\'ta yaşar');

    Future<void> run(double seconds) async {
      for (var t = 0.0; t < seconds; t += 0.05) {
        hostGame.update(0.05);
        clientGame.update(0.05);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    }

    await tester.runAsync(() async {
      // 1) HOST asker çıkarır → istemcide durum yayınıyla belirir.
      hostGame.deployFromNest(
          hostGame.nests[0]!, 1.0, Vector2(500, 350));
      await run(1.5);
      final hostOwn =
          hostGame.units.where((u) => u.owner.id == 0 && !u.dead).length;
      final clientSees =
          clientGame.units.where((u) => u.owner.id == 0 && !u.dead).length;
      expect(hostOwn, greaterThan(0));
      expect(clientSees, hostOwn,
          reason: 'İstemci host\'un tüm askerlerini görmeli');

      // 2) İSTEMCİ çıkarma EMRİ gönderir → host kendi simülasyonunda uygular.
      clientGame.requestDeploy(
          clientGame.nests[1]!, 1.0, Vector2(700, 350));
      await run(1.5);
      expect(
          hostGame.units.where((u) => u.owner.id == 1 && !u.dead).length,
          greaterThan(0),
          reason: 'İstemcinin emri host simülasyonunda işlemeli');
      expect(
          clientGame.units.where((u) => u.owner.id == 1 && !u.dead).length,
          greaterThan(0),
          reason: 'İstemci kendi askerlerini yayından geri görmeli');

      // 3) Kaynak senkronu: host'taki değer istemciye akar (pasif gelir
      // aktığı için küçük bir tolerans bırakılır).
      hostState.players[1].resources = 777;
      await run(0.4);
      expect(clientState.players[1].resources, greaterThanOrEqualTo(777));
      expect(
          (clientState.players[1].resources -
                  hostState.players[1].resources)
              .abs(),
          lessThanOrEqualTo(5));

      // 4) Maç sonu: istemcinin kraliçesi düşer → iki tarafta da sonuç.
      hostGame.nests[1]!.receiveAttack(999999);
      await run(0.6);
      expect(hostState.phase, GamePhase.victory,
          reason: 'Host (takım 0) kazanmalı');
      expect(clientState.phase, GamePhase.defeat,
          reason: 'İstemci (takım 1) yenilmeli');
      expect(clientState.lastPlayerStats, isNotNull);
      expect(clientState.lastPlayerStats!.first.name, 'Kurucu');
    });
  });
}
