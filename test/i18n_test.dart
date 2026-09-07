import 'package:ants_wars/data/abilities.dart';
import 'package:ants_wars/data/campaigns.dart';
import 'package:ants_wars/data/i18n.dart';
import 'package:ants_wars/data/maps.dart';
import 'package:ants_wars/data/settings.dart';
import 'package:ants_wars/data/units.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dil altyapısı: veri katmanı getter'ları aktif dile göre döner;
/// varsayılan Türkçedir ve İngilizce karşılıklar EKSİKSİZDİR.
void main() {
  tearDown(() => appSettings.language = 'tr'); // diğer testleri etkileme

  test('varsayılan dil Türkçe', () {
    expect(isEnglish, isFalse);
    expect(loc('merhaba', 'hello'), 'merhaba');
    expect(abilitySpecs[AbilityType.lightning]!.name, 'Yıldırım');
    expect(unitSpecs[UnitType.fire]!.name, 'Ateş Karıncası');
    expect(allMaps.first.name, 'Amazon Geçidi');
  });

  test('dil değişince veri katmanı İngilizce döner', () {
    appSettings.language = 'en';
    expect(isEnglish, isTrue);
    expect(loc('merhaba', 'hello'), 'hello');
    expect(abilitySpecs[AbilityType.lightning]!.name, 'Lightning');
    expect(unitSpecs[UnitType.fire]!.name, 'Fire Ant');
    expect(allMaps.first.name, 'Amazon Crossing');
    expect(campaigns.first.name, 'Fire Campaign');
    expect(campaigns.first.missions.first.title, 'Spark');
  });

  test('tüm çeviriler eksiksiz (boş EN alanı yok)', () {
    for (final spec in abilitySpecs.values) {
      expect(spec.nameEn, isNotEmpty, reason: spec.nameTr);
      expect(spec.descriptionEn, isNotEmpty, reason: spec.nameTr);
    }
    for (final spec in unitSpecs.values) {
      expect(spec.nameEn, isNotEmpty, reason: spec.nameTr);
    }
    for (final m in [...allMaps, tutorialMap]) {
      expect(m.nameEn, isNotEmpty, reason: m.id);
    }
    for (final c in campaigns) {
      expect(c.nameEn, isNotEmpty, reason: c.nameTr);
      expect(c.taglineEn, isNotEmpty, reason: c.nameTr);
      for (final mis in c.missions) {
        expect(mis.titleEn, isNotEmpty, reason: mis.titleTr);
        expect(mis.briefEn, isNotEmpty, reason: mis.titleTr);
        expect(mis.map?.nameEn ?? 'x', isNotEmpty, reason: mis.titleTr);
      }
    }
  });
}
