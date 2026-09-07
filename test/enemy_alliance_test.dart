import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// DÜŞMAN İTTİFAKI (Savaş Kur tiki): tekli maçta tüm botlar tek takım.
void main() {
  test('ittifak açık: botlar takım 1, insan takım 0', () {
    final state = GameState()
      ..startMatch(
          playerCount: 3, map: rootTriangle, enemyAlliance: true);
    expect(state.players[0].team, 0);
    expect(state.players[1].team, 1);
    expect(state.players[2].team, 1);
  });

  test('ittifak kapalı: herkes kendi takımı', () {
    final state = GameState()..startMatch(playerCount: 4, map: panamaPass);
    expect(state.players.map((p) => p.team).toSet().length, 4);
  });

  test('tekrar oyna ittifakı korur', () {
    final state = GameState()
      ..startMatch(
          playerCount: 4, map: okavangoDelta, enemyAlliance: true)
      ..restartLastMatch();
    expect(state.players.where((p) => p.team == 1).length, 3);
  });
}
