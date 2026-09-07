import 'package:flutter/material.dart';

import '../data/i18n.dart';
import '../data/match_history.dart';
import 'game_back_button.dart';

/// İSTATİSTİKLER — solda özet karneler, sağda son maçların listesi.
/// Veri cihazdaki maç geçmişinden gelir (son 40 maç).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<MatchRecord>? _records;

  @override
  void initState() {
    super.initState();
    loadMatchHistory().then((r) {
      if (mounted) setState(() => _records = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title: Text(loc('İstatistikler', 'Statistics'),
            style: const TextStyle(color: Color(0xFFD8C9A3))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _records == null
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Color(0xFF8BC34A)),
                ),
              )
            : _records!.isEmpty
                ? _empty()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 292, child: _summaryPanel()),
                      const SizedBox(width: 10),
                      Expanded(child: _historyPanel()),
                    ],
                  ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6223019),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4A6130)),
        ),
        child: child,
      );

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats,
                size: 44, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 10),
            Text(loc('Henüz kayıtlı maç yok', 'No matches recorded yet'),
                style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 3),
            Text(
                loc('İlk savaşını yap — karnen burada birikecek.',
                    'Fight your first battle — your record grows here.'),
                style:
                    const TextStyle(color: Colors.white30, fontSize: 10.5)),
          ],
        ),
      );

  // ------------------------------------------------------------- ÖZET

  Widget _summaryPanel() {
    final all = _records!;
    // Eğitim maçları karneyi şişirmesin.
    final r = all.where((m) => m.mode != 'tutorial').toList();
    final wins = r.where((m) => m.won).length;
    final rate = r.isEmpty ? 0 : (wins * 100 / r.length).round();
    final produced =
        r.fold<int>(0, (sum, m) => sum + m.produced);
    final playSec = r.fold<int>(0, (sum, m) => sum + m.durationSec);
    final bestHorde = r
        .where((m) => m.mode == 'horde')
        .fold<int>(0, (best, m) => m.score > best ? m.score : best);

    // En çok oynanan harita.
    final mapCounts = <String, int>{};
    for (final m in r) {
      mapCounts.update(m.mapId, (c) => c + 1, ifAbsent: () => 1);
    }
    String favMap = '—';
    var favCount = 0;
    mapCounts.forEach((id, c) {
      if (c > favCount) {
        favCount = c;
        favMap = r.firstWhere((m) => m.mapId == id).mapName;
      }
    });

    String clock(int sec) {
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      return h > 0 ? '${h}s ${m}dk' : '${m}dk';
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc('GENEL KARNE', 'OVERALL RECORD'),
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          // Büyük kazanma oranı göstergesi.
          Row(
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: rate / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF8BC34A),
                    ),
                    Center(
                      child: Text('%$rate',
                          style: const TextStyle(
                              color: Color(0xFFF2E8D5),
                              fontWeight: FontWeight.w900,
                              fontSize: 17)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc('kazanma oranı', 'win rate'),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('$wins / ${r.length}',
                        style: const TextStyle(
                            color: Color(0xFFF2E8D5),
                            fontWeight: FontWeight.w900,
                            fontSize: 20)),
                    Text(loc('zafer / maç', 'wins / matches'),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _statRow(Icons.egg_alt, loc('Üretilen asker', 'Ants trained'),
              '$produced'),
          _statRow(Icons.timer, loc('Toplam savaş süresi', 'Time at war'),
              clock(playSec)),
          _statRow(Icons.map, loc('Favori harita', 'Favorite map'), favMap),
          if (bestHorde > 0)
            _statRow(
                Icons.local_fire_department,
                loc('Hayatta kalma rekoru', 'Survival record'),
                '${bestHorde ~/ 60}:${(bestHorde % 60).toString().padLeft(2, "0")}'),
          const Spacer(),
          Text(
            loc('Son ${all.length} maç kayıtlı.',
                'Last ${all.length} matches on record.'),
            style: const TextStyle(color: Colors.white30, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFE8B33C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
            ),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFF2E8D5),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      );

  // ------------------------------------------------------------- LİSTE

  Widget _historyPanel() {
    final r = _records!;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc('SON MAÇLAR', 'RECENT MATCHES'),
              style: const TextStyle(
                  color: Color(0xFF8BC34A),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: r.length,
              separatorBuilder: (_, i) => const SizedBox(height: 6),
              itemBuilder: (_, i) => _matchTile(r[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchTile(MatchRecord m) {
    final date = DateTime.fromMillisecondsSinceEpoch(m.dateMs);
    final months = isEnglish
        ? const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
            'Sep', 'Oct', 'Nov', 'Dec']
        : const ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu',
            'Eyl', 'Eki', 'Kas', 'Ara'];
    final when = '${date.day} ${months[date.month - 1]} '
        '${date.hour.toString().padLeft(2, "0")}:'
        '${date.minute.toString().padLeft(2, "0")}';
    final mins = m.durationSec ~/ 60;
    final secs = m.durationSec % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3A20),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: m.won
                ? const Color(0x668BC34A)
                : const Color(0x55B0553A)),
      ),
      child: Row(
        children: [
          Icon(
            m.won ? Icons.emoji_events : Icons.heart_broken,
            size: 20,
            color: m.won
                ? const Color(0xFFE8B33C)
                : const Color(0xFFB0553A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.mapName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFF2E8D5),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                  '${m.modeLabel} · $mins:${secs.toString().padLeft(2, "0")}'
                  ' · ${loc("asker", "ants")}: ${m.produced}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(when,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
