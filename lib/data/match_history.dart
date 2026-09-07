import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'campaigns.dart';
import 'i18n.dart';
import 'maps.dart';

/// MAÇ GEÇMİŞİ: her biten maç cihazda saklanır (son 40 kayıt) —
/// istatistik sayfası buradan beslenir.
class MatchRecord {
  const MatchRecord({
    required this.dateMs,
    required this.mapId,
    required this.mode, // solo | team | alliance | lan | mission | horde
    required this.won,
    required this.durationSec,
    required this.produced,
    required this.goldEarned,
    required this.difficultyIndex,
    this.score = 0, // horde: hayatta kalınan saniye
  });

  final int dateMs;
  final String mapId;
  final String mode;
  final bool won;
  final int durationSec;
  final int produced;
  final int goldEarned;
  final int difficultyIndex;
  final int score;

  Map<String, dynamic> toJson() => {
        'd': dateMs,
        'm': mapId,
        'o': mode,
        'w': won ? 1 : 0,
        't': durationSec,
        'p': produced,
        'g': goldEarned,
        'f': difficultyIndex,
        if (score > 0) 's': score,
      };

  static MatchRecord? fromJson(Map<String, dynamic> j) {
    try {
      return MatchRecord(
        dateMs: (j['d'] as num).toInt(),
        mapId: j['m'] as String,
        mode: j['o'] as String,
        won: (j['w'] as num) == 1,
        durationSec: (j['t'] as num).toInt(),
        produced: (j['p'] as num).toInt(),
        goldEarned: (j['g'] as num).toInt(),
        difficultyIndex: (j['f'] as num).toInt(),
        score: ((j['s'] as num?) ?? 0).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Harita adı (aktif dilde): normal + eğitim + sefer haritalarında aranır.
  String get mapName {
    for (final m in [
      ...allMaps,
      tutorialMap,
      ...fireMissionMaps,
      ...iceMissionMaps,
      ...islandMissionMaps,
    ]) {
      if (m.id == mapId) return m.name;
    }
    return mapId;
  }

  String get modeLabel => switch (mode) {
        'team' => loc('Eşli 2v2', '2v2 Teams'),
        'alliance' => loc('İttifak', 'Alliance'),
        'lan' => 'LAN',
        'mission' => loc('Sefer', 'Campaign'),
        'horde' => loc('Hayatta Kalma', 'Survival'),
        'tutorial' => loc('Eğitim', 'Training'),
        _ => loc('Tekli', 'Solo'),
      };
}

const _historyKey = 'match_history_v1';
const _maxRecords = 40;

Future<List<MatchRecord>> loadMatchHistory() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_historyKey) ?? const [];
    final out = <MatchRecord>[];
    for (final line in raw) {
      final r =
          MatchRecord.fromJson(jsonDecode(line) as Map<String, dynamic>);
      if (r != null) out.add(r);
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Yeni kayıt EN BAŞA eklenir; liste [_maxRecords] ile sınırlı tutulur.
Future<void> saveMatchRecord(MatchRecord record) async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = List.of(p.getStringList(_historyKey) ?? const <String>[]);
    raw.insert(0, jsonEncode(record.toJson()));
    if (raw.length > _maxRecords) raw.removeRange(_maxRecords, raw.length);
    await p.setStringList(_historyKey, raw);
  } catch (_) {}
}
