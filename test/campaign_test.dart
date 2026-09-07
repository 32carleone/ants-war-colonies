import 'dart:math' as math;

import 'package:ants_wars/data/abilities.dart';
import 'package:ants_wars/data/campaigns.dart';
import 'package:ants_wars/game/ants_wars_game.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/models/building.dart';
import 'package:ants_wars/ui/campaign_map_screen.dart';
import 'package:ants_wars/ui/result_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sefer görev kurulumu: takımlar, sabit yetenekler, destekler, ilerleme.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Lav Nehri (2v1): takımlar, kule ve sabit yetenekler doğru',
      (tester) async {
    final fire = campaigns[0];
    final mission = fire.missions[2]; // Lav Nehri
    final state = GameState()
      ..startMatch(
        playerCount: mission.map!.playerCount,
        map: mission.map,
        mission: mission.setup(fire.id, 3),
      );

    // 3 oyuncu: oyuncu takım 0, İKİ düşman bot TEK takım (1).
    expect(state.players.length, 3);
    expect(state.players[0].team, 0);
    expect(state.players[1].team, 1);
    expect(state.players[2].team, 1);

    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Oyuncu HARİTANIN İLK yuva noktasında (karıştırma yok).
    expect(game.nests[0]!.position, mission.map!.nestSpots[0]);
    // Batı köprübaşı kulesi OYUNCUNUN; altın desteği uygulanmış.
    expect(game.buildings[0].type, BuildingType.tower);
    expect(game.buildings[0].owner, state.humanPlayer);
    expect(state.humanPlayer!.resources, 150);
    // Sabit yetenekler (2 slot).
    expect(game.humanAbilities,
        [AbilityType.fireRing, AbilityType.poisonCloud]);
    expect(game.abilityCooldowns.length, 2);
  });

  testWidgets('görev zaferi sefer ilerlemesini kaydeder', (tester) async {
    final fire = campaigns[0];
    final mission = fire.missions[0];
    final state = GameState()
      ..startMatch(
        playerCount: 2,
        map: mission.map,
        mission: mission.setup(fire.id, 1),
      );
    state.endMatch(humanWon: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(await loadCampaignProgress(CampaignId.fire), 1);

    // Kaybedince ilerleme değişmez.
    state.startMatch(
      playerCount: 2,
      map: fire.missions[1].map,
      mission: fire.missions[1].setup(fire.id, 2),
    );
    state.endMatch(humanWon: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(await loadCampaignProgress(CampaignId.fire), 1);
  });

  testWidgets('Volkanın Kalbi: düşman altın desteği uygulanır',
      (tester) async {
    final fire = campaigns[0];
    final mission = fire.missions[4];
    final state = GameState()
      ..startMatch(
        playerCount: 4,
        map: mission.map,
        mission: mission.setup(fire.id, 5),
      );
    final game = AntsWarsGame(gameState: state, rng: math.Random(7))
      ..countdown = 0;
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(state.humanPlayer!.resources, 300);
    for (final p in state.players.where((p) => p.isBot)) {
      expect(p.resources, 220);
    }
    // İki kule oyuncunun.
    expect(game.buildings[0].owner, state.humanPlayer);
    expect(game.buildings[1].owner, state.humanPlayer);
  });

  testWidgets('sefer zaferinde sonuç ekranı SEFERE yönlendirir (menü değil)',
      (tester) async {
    final fire = campaigns[0];
    final mission = fire.missions[0];
    final state = GameState()
      ..startMatch(
        playerCount: 2,
        map: mission.map,
        mission: mission.setup(fire.id, 1),
      );
    state.endMatch(humanWon: true);
    await tester.pumpWidget(MaterialApp(home: ResultScreen(gameState: state)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sefere Dön'), findsOneWidget);
    expect(find.text('Ana Menü'), findsNothing);

    await tester.tap(find.text('Sefere Dön'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // rota animasyonu sürekli — settle beklenmez
    expect(state.phase, GamePhase.menu);
    expect(find.byType(CampaignMapScreen), findsOneWidget);
  });
}