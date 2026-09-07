import 'dart:ui';

/// Bir oyuncu (insan veya bot).
class Player {
  Player({
    required this.id,
    required this.color,
    required this.isBot,
    int? team,
    this.remote = false,
    this.resources = 0,
  }) : team = team ?? id;

  final int id;

  /// Takım kimliği (2v2'de müttefikler aynı takımdadır; teklide team == id).
  final int team;

  final Color color;
  final bool isBot;

  /// LAN maçında BAŞKA cihazdaki insan oyuncu (bu cihazın oyuncusu değildir).
  final bool remote;

  /// Kaynak (para). Kaynak binaları ve pasif gelirle artar.
  int resources;

  /// Kraliçesi öldüğünde true olur; oyuncu oyundan elenir.
  bool eliminated = false;

  // ---- maç sonu çizelgesi sayaçları ----
  /// Maç boyunca kazanılan toplam altın (başlangıç sermayesi hariç).
  int goldEarned = 0;

  /// Kaybedilen asker sayısı.
  int unitsLost = 0;

  @override
  String toString() =>
      'Player($id, ${isBot ? "bot" : "human"}, res: $resources)';
}
