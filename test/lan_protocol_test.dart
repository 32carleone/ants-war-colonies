import 'dart:math' as math;

import 'package:ants_wars/net/lan_protocol.dart';
import 'package:ants_wars/ui/main_menu.dart' show generatePlayerName;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('çerçeveleme', () {
    test('encode/decode gidiş-dönüş', () {
      final msgs = <Map<String, dynamic>>[];
      final decoder = FrameDecoder(msgs.add);
      decoder.add(encodeFrame({'t': 'join', 'n': 'Çekirge 🐜', 'l': [0, 2]}));
      expect(msgs, hasLength(1));
      expect(msgs.first['t'], 'join');
      expect(msgs.first['n'], 'Çekirge 🐜'); // UTF-8 (Türkçe + emoji)
      expect(msgs.first['l'], [0, 2]);
    });

    test('parça parça gelen baytlar ve yapışık çerçeveler', () {
      final msgs = <Map<String, dynamic>>[];
      final decoder = FrameDecoder(msgs.add);
      final a = encodeFrame({'t': 'a', 'v': 1});
      final b = encodeFrame({'t': 'b', 'v': 2});
      final all = [...a, ...b];
      // TCP akışı gibi: 3'er baytlık dilimler halinde ver.
      for (var i = 0; i < all.length; i += 3) {
        decoder.add(all.sublist(i, math.min(i + 3, all.length)));
      }
      expect(msgs, hasLength(2));
      expect(msgs[0]['t'], 'a');
      expect(msgs[1]['v'], 2);
    });

    test('tek seferde çok çerçeve', () {
      final msgs = <Map<String, dynamic>>[];
      final decoder = FrameDecoder(msgs.add);
      decoder.add([
        ...encodeFrame({'t': 'x'}),
        ...encodeFrame({'t': 'y'}),
        ...encodeFrame({'t': 'z'}),
      ]);
      expect([for (final m in msgs) m['t']], ['x', 'y', 'z']);
    });
  });

  group('json modelleri', () {
    test('LanGameInfo gidiş-dönüş (adres alıcı tarafta eklenir)', () {
      const info = LanGameInfo(
        hostName: 'Carleone',
        mapId: 'nile_delta',
        mapName: 'Nil Deltası',
        mode: LanMode.teams2v2,
        playerCount: 4,
        joined: 2,
        port: 47312,
        address: '',
      );
      final back = LanGameInfo.fromJson(info.toJson(), '192.168.1.7')!;
      expect(back.hostName, 'Carleone');
      expect(back.mapId, 'nile_delta');
      expect(back.mode, LanMode.teams2v2);
      expect(back.playerCount, 4);
      expect(back.joined, 2);
      expect(back.address, '192.168.1.7');
    });

    test('bozuk keşif paketi null döner (çökmez)', () {
      expect(LanGameInfo.fromJson({'h': 'x'}, '1.2.3.4'), isNull);
    });

    test('LanPlayerMeta gidiş-dönüş', () {
      const meta = LanPlayerMeta(
          slot: 2, name: 'Oyuncu', team: 1, isBot: false, loadout: [1, 5, 9]);
      final back = LanPlayerMeta.fromJson(meta.toJson());
      expect(back.slot, 2);
      expect(back.team, 1);
      expect(back.isBot, isFalse);
      expect(back.loadout, [1, 5, 9]);
    });
  });

  group('oyuncu adı', () {
    test('Player + 5 hane biçiminde üretilir', () {
      final name = generatePlayerName(math.Random(7));
      expect(RegExp(r'^Player\d{5}$').hasMatch(name), isTrue);
    });

    test('farklı tohumlar farklı adlar verir', () {
      final names = {
        for (var i = 0; i < 50; i++) generatePlayerName(math.Random(i))
      };
      expect(names.length, greaterThan(40)); // makul çeşitlilik
    });
  });
}
