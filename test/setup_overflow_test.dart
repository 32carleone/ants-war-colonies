import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/game/game_state.dart';
import 'package:ants_wars/ui/play_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Savaş Kur düzeni: son (4 kişilik) harita seçiliyken — Kâbus çipi +
/// MOD + DÜŞMANLAR kontrolleri birlikteyken — hiçbir boyutta taşma olmaz.
/// ("son haritayı seçince overflow" regresyonu.)
void main() {
  Future<void> selectLastMap(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: PlaySetupScreen(gameState: GameState()),
    ));
    await tester.pump();
    final last = allMaps.last; // Okavango (4p → DÜŞMANLAR tiki açılır)
    await tester.dragUntilVisible(find.text(last.name),
        find.byType(ListView).first, const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(last.name));
    await tester.pumpAndSettle();
    expect(find.text('DÜŞMANLAR'), findsOneWidget);
  }

  testWidgets('1280x720: son harita seçili, taşma yok', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await selectLastMap(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('784x360 dar telefon: taşma yok', (tester) async {
    tester.view.physicalSize = const Size(784, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await selectLastMap(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sekmeler: HARİTALAR varsayılan, TÜMÜ özel kartları açar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: PlaySetupScreen(gameState: GameState()),
    ));
    await tester.pump();
    // Varsayılan: yalnız haritalar.
    expect(find.text('Hayatta Kalma'), findsNothing);
    expect(find.text('Eğitim Kampı'), findsNothing);
    expect(find.text('Amazon Geçidi'), findsOneWidget);
    // TÜMÜ: özel kartlar görünür.
    await tester.tap(find.text('TÜMÜ'));
    await tester.pumpAndSettle();
    expect(find.text('Hayatta Kalma'), findsOneWidget);
    expect(find.text('Eğitim Kampı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
