import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/constants.dart';
import '../data/i18n.dart';
import 'crossed_swords.dart';
import 'game_back_button.dart';

/// GELİŞTİRİCİ DETAYLARI — menünün sağ üst köşesindeki bilgi butonundan
/// açılır: solda geliştirici kartı, sağda oyunun amacı / nasıl yapıldığı.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title: Text(loc('Geliştirici', 'Developer'),
            style: const TextStyle(color: Color(0xFFD8C9A3))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOL: geliştirici kartı.
            SizedBox(width: 300, child: _panel(child: _devCard(context))),
            const SizedBox(width: 10),
            // SAĞ: oyun hakkında.
            Expanded(child: _panel(child: _about())),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: child,
      );

  Widget _devCard(BuildContext context) {
    // Dar yüksekliklerde TAŞMAZ: içerik kaydırılabilir.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // Rozet: altın çerçeveli daire içinde UYGULAMA İKONU.
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE8B33C), width: 2),
            ),
            child: ClipOval(
              child: Image.asset('assets/icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Yunus Can',
              style: TextStyle(
                  color: Color(0xFFF2E8D5),
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          Text(loc('Tasarım & Geliştirme', 'Design & Development'),
              style:
                  const TextStyle(color: Color(0xFF8BC34A), fontSize: 12)),
          const SizedBox(height: 18),
          _contactRow(context, Icons.public, 'yunuscan.xyz'),
          const SizedBox(height: 8),
          _contactRow(context, Icons.mail_outline, '32carleone@gmail.com'),
          const SizedBox(height: 26),
          const CrossedSwordsIcon(size: 26, color: Color(0xFF4A6130)),
          const SizedBox(height: 8),
          Text('Ants War: Colonies — v$kAppVersion',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Dokununca panoya kopyalanan iletişim satırı.
  Widget _contactRow(BuildContext context, IconData icon, String text) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc('$text panoya kopyalandı',
              '$text copied to clipboard')),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF3E5527),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFFE8B33C)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Color(0xFFF2E8D5), fontSize: 13)),
            ),
            const Icon(Icons.copy, size: 13, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _about() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(loc('OYUNUN AMACI', 'THE GOAL')),
          _body(loc(
              'Ants War: Colonies, karınca kolonileri arasında geçen gerçek '
              'zamanlı bir strateji oyunudur. Tek ekranlık bir haritada '
              'ana yuvandan asker üretir, orduyu sürükle-bırak ile sahaya '
              'sürer, nötr binaları çevresinde çoğunluk kurarak ele '
              'geçirirsin. Amaç basit ve acımasızdır: kraliçeni yaşat, '
              'rakip kraliçelerin hepsini düşür. Kraliçesi ölen koloni '
              'yıkılır — binaları nötre döner, askerleri yabanileşir.',
              'Ants War: Colonies is a real-time strategy game fought '
              'between ant colonies. On a single-screen map you train '
              'soldiers at your nest, drag-and-drop your army into the '
              'field and capture neutral buildings by holding the '
              'majority around them. The goal is simple and merciless: '
              'keep your queen alive, topple every rival queen. A colony '
              'whose queen dies collapses — its buildings turn neutral, '
              'its soldiers go feral.')),
          _title(loc('NE VAR?', "WHAT'S INSIDE?")),
          _body(loc(
              '11 harita ve 3 arazi teması (çimen, çorak-lav, kar-buz); '
              'bataklık, kazı tıkacı, yaban arısı kovanı ve '
              'kuluçka istasyonu gibi canlı harita öğeleri; 11 kraliçe '
              'yeteneği; 3 kampanya × 5 görevlik SEFER modu; eğitim kampı, '
              '2v2 eşli mod ve düşman ittifakı seçeneği; stratejik botlar '
              've adil savaş sisi.',
              '11 maps and 3 terrain themes (grass, scorched-lava, '
              'snow-ice); living map features like swamps, '
              'passages, dig plugs, wasp hives and hatcheries; 11 queen '
              'abilities; a CAMPAIGN mode of 3 campaigns × 5 missions; a '
              'boot camp, 2v2 team mode and an enemy-alliance option; '
              'strategic bots and a fair fog of war.')),
          _title(loc('NASIL YAPILDI?', 'HOW WAS IT MADE?')),
          _body(loc(
              'Flutter + Flame ile geliştirildi. Oyundaki TÜM grafikler '
              'kodla, prosedürel olarak çizilir — tek bir harici sprite '
              'yoktur. Harita kartları ve uygulama ikonu bile oyunun kendi '
              'çiziminden üretilir. 260\'tan fazla otomatik test her '
              'sürümde oyunun kurallarını ve görsellerini korur.',
              'Built with Flutter + Flame. EVERY graphic in the game is '
              'drawn procedurally in code — there is not a single '
              'external sprite. Even the map cards and the app icon are '
              "generated from the game's own drawing. More than 260 "
              'automated tests guard the rules and visuals in every '
              'release.')),
          _title(loc('TEŞEKKÜR', 'THANKS')),
          _body(loc(
              'Müzikler OpenGameArt topluluğunun açık lisanslı '
              'eserlerinden derlenmiştir (HorrorPen, Matthew Pablo, '
              'cynicmusic); ayrıntılı atıflar oyun deposundaki '
              'CREDITS dosyasındadır. İyi savaşlar, kraliçem! 🐜',
              'The music is compiled from openly licensed works of the '
              'OpenGameArt community (HorrorPen, Matthew Pablo, '
              'cynicmusic); detailed credits live in the CREDITS file of '
              'the game repository. Fight well, my queen! 🐜')),
        ],
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(t,
            style: const TextStyle(
                color: Color(0xFF8BC34A),
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 2)),
      );

  Widget _body(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white70, fontSize: 13, height: 1.5));
}
