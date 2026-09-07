import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UYGULAMA İKONU KORUMASI.
///
/// İkon artık kodla çizilmez: `python3 tool/make_icon.py`,
/// assets/assetsss.png referansını (kaligrafik karınca kafası) birebir
/// işleyip assets/icon.png üretir — çizgiler yeşil, zemin beyaz, sağdaki
/// eksik kontur sol yarının aynasıyla tamamlanır, filigran temizlenir.
/// Bu test üretilen ikonu golden ile kilitler; ikon değişecekse önce
/// betik çalıştırılır, sonra `--update-goldens`.
void main() {
  testWidgets('uygulama ikonu üretimi', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bytes = File('assets/icon.png').readAsBytesSync();
    await tester.pumpWidget(
      RepaintBoundary(
        child: Image.memory(bytes, width: 1024, height: 1024),
      ),
    );
    // Görselin çözülmesini bekle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/app_icon.png'),
    );
  });
}
