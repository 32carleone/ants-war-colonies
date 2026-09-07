import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'tutorial_prompted': true}));

  testWidgets('menü → savaş kur → başlat akışı çalışır', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AntsWarsApp());
    expect(find.text('ANTS WAR'), findsOneWidget);

    // Oyna → Savaş Kur ekranı.
    await tester.tap(find.text('SAVAŞ'));
    await tester.pumpAndSettle();
    expect(find.text('Savaş Kur'), findsOneWidget);
    // Varsayılan sekme HARİTALAR: özel kartlar TÜMÜ sekmesinde
    // (setup_overflow_test sekme davranışını ayrıca doğrular).
    expect(find.text('Hayatta Kalma'), findsNothing);
    expect(find.text('Amazon Geçidi'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Serengeti Üçgeni'),
        find.byType(ListView).first, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Serengeti Üçgeni'), findsOneWidget);
    await tester.dragUntilVisible(find.text('SAVAŞA BAŞLA'),
        find.byType(ListView).first, const Offset(160, 0));
    await tester.pumpAndSettle();

    // Başlat → oyun sahnesi (route kapanış animasyonu bitene dek bekle).
    await tester.tap(find.text('SAVAŞA BAŞLA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ANTS WAR'), findsNothing);
    expect(find.text('Savaş Kur'), findsNothing);
  });

  testWidgets('menüden Wiki açılır ve askerler listelenir', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AntsWarsApp());
    await tester.tap(find.text('Wiki'));
    await tester.pumpAndSettle();

    // Sol konu listesi: askerler.
    expect(find.textContaining('Ateş Karıncası'), findsWidgets);
    expect(find.textContaining('Kesici Asker'), findsWidgets);
    // Bina konusu: listeden seçilince SAĞ panelde detay açılır.
    await tester.tap(find.text('Ana Yuva').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('kraliçe burada yaşar'), findsOneWidget);
    // Güç konusu (liste kaydırılarak bulunur).
    await tester.dragUntilVisible(find.text('Yıldırım'),
        find.byType(ListView).first, const Offset(0, -80));
    await tester.pumpAndSettle(); // kaydırma ataleti dursun, tap kaymasın
    await tester.tap(find.text('Yıldırım').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dolum'), findsWidgets);
  });

  test('startMatch oyuncuları kurar ve evreyi playing yapar', () {
    final state = GameState();
    state.startMatch(playerCount: 3);

    expect(state.phase, GamePhase.playing);
    expect(state.players.length, 3);
    expect(state.players.where((p) => !p.isBot).length, 1);
    expect(state.humanPlayer!.id, 0);
    expect(state.matchId, 1);

    state.endMatch(humanWon: true);
    expect(state.phase, GamePhase.victory);

    state.backToMenu();
    expect(state.phase, GamePhase.menu);
    expect(state.players, isEmpty);
  });
}
