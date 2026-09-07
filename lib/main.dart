import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/abilities.dart';
import 'game/audio_controller.dart';
import 'data/settings.dart';
import 'game/game_state.dart';
import 'ui/game_screen.dart';
import 'ui/main_menu.dart';
import 'ui/result_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Oyun yalnızca yatay modda oynanır.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await appSettings.load();
  // Ses hazırlığı AÇILIŞI BEKLETMEZ: yavaş/aksayan ses altyapısı (özellikle
  // web) oyunun açılmasını engellememeli — arka planda tamamlanır.
  unawaited(AudioController.init());
  final gameState = GameState()..abilityLoadout = await loadAbilityLoadout();
  runApp(AntsWarsApp(gameState: gameState));
}

class AntsWarsApp extends StatelessWidget {
  AntsWarsApp({super.key, GameState? gameState})
      : gameState = gameState ?? GameState();

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ants War: Colonies',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF16200F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C7A2E),
          brightness: Brightness.dark,
        ),
      ),
      // WEB: oyun tam ekran yayılmaz — sayfa ortasında telefon oranında
      // (16:9) çerçeveli bir sahnede çalışır. Diğer platformlar tam ekran.
      builder: (context, child) =>
          kIsWeb ? _WebFrame(child: child!) : child!,
      // Dil değişince (appSettings) TÜM arayüz tazelenir.
      home: AnimatedBuilder(
        animation: Listenable.merge([gameState, appSettings]),
        builder: (context, _) {
          switch (gameState.phase) {
            case GamePhase.menu:
              return MainMenu(gameState: gameState);
            case GamePhase.playing:
              // matchId anahtarı: yeniden başlatınca sahne sıfırdan kurulur.
              return GameScreen(
                key: ValueKey(gameState.matchId),
                gameState: gameState,
              );
            case GamePhase.victory:
            case GamePhase.defeat:
              return ResultScreen(gameState: gameState);
          }
        },
      ),
    );
  }
}

/// WEB ÇERÇEVESİ: koyu sayfa fonu üzerinde ortalanmış, yatay telefon
/// oranında (16:9, en çok 1024×576) yuvarlak köşeli oyun sahnesi.
/// Pencere küçülürse oranını koruyarak küçülür; tüm ekranlar ve
/// pencereler (Navigator dahil) bu çerçevenin İÇİNDE yaşar.
class _WebFrame extends StatelessWidget {
  const _WebFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0D1208),
      child: Center(
        child: LayoutBuilder(
          builder: (context, box) {
            var w = math.min(box.maxWidth - 24, 1024.0);
            var h = w * 9 / 16;
            final maxH = box.maxHeight - 24;
            if (h > maxH) {
              h = maxH;
              w = h * 16 / 9;
            }
            return Container(
              width: w,
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4A6130), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 34,
                    spreadRadius: 4,
                  ),
                ],
              ),
              // İçerideki ekranlar pencereyi değil ÇERÇEVEYİ ölçü alsın.
              // DİKKAT: MaterialApp.builder bağlamında MediaQuery henüz
              // OLMAYABİLİR — MediaQuery.of burada atarsa ilk kare hiç
              // çizilmez (webde bomboş beyaz sayfa). maybeOf + View yedeği.
              child: MediaQuery(
                data: (MediaQuery.maybeOf(context) ??
                        MediaQueryData.fromView(View.of(context)))
                    .copyWith(size: Size(w, h)),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
