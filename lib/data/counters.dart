import 'units.dart';

/// Tür avantaj çemberi (saldıran → savunan hasar çarpanı) — temiz 4'lü RPS:
///
///   Orman (menzilli) → Kesici (tank)   : yaklaşamadan eritir
///   Kapan Çene (suikastçı) → Orman     : hızla yaklaşıp keser
///   Ateş (sürü) → Kapan Çene           : kalabalık boğar
///   Kesici (tank) → Ateş               : alan temizler
const Map<UnitType, Map<UnitType, double>> _counterTable = {
  UnitType.wood: {UnitType.leafcutter: 1.5},
  UnitType.trapjaw: {UnitType.wood: 1.5},
  UnitType.fire: {UnitType.trapjaw: 1.3},
  UnitType.leafcutter: {UnitType.fire: 1.5},
};

/// [attacker] tipinin [defender] tipine vurduğu hasarın çarpanı (varsayılan 1).
double counterMultiplier(UnitType attacker, UnitType defender) =>
    _counterTable[attacker]?[defender] ?? 1.0;
