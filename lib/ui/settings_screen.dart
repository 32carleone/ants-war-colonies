import 'package:flutter/material.dart';

import '../data/constants.dart';
import '../data/i18n.dart';
import '../data/settings.dart';
import 'game_back_button.dart';
import '../game/audio_controller.dart';

/// Ayarlar — oyun menüsü stilinde: koyu yeşil panel, ikonlu satırlar,
/// oyunvari anahtar/kaydırıcılar. Web görünümlü bileşen yok. Kalıcı kayıt.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _update(void Function() change) {
    setState(change);
    appSettings.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16200F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16200F),
        leading: const GameBackButton(),
        leadingWidth: 52,
        title:
            Text(loc('Ayarlar', 'Settings'),
                style: const TextStyle(color: Color(0xFFD8C9A3))),
        iconTheme: const IconThemeData(color: Color(0xFFD8C9A3)),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 560,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xE6223019),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4A6130)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(
                  icon: Icons.volume_up,
                  label: loc('Ses efektleri', 'Sound effects'),
                  trailing: _GameSwitch(
                    value: appSettings.soundOn,
                    onChanged: (v) => _update(() => appSettings.soundOn = v),
                  ),
                ),
                if (appSettings.soundOn)
                  _volumeRow(
                    appSettings.soundVolume,
                    (v) => _update(() => appSettings.soundVolume = v),
                  ),
                _divider(),
                _row(
                  icon: Icons.music_note,
                  label: loc('Müzik', 'Music'),
                  trailing: _GameSwitch(
                    value: appSettings.musicOn,
                    onChanged: (v) => _update(() => appSettings.musicOn = v),
                  ),
                ),
                if (appSettings.musicOn)
                  _volumeRow(
                    appSettings.musicVolume,
                    (v) => _update(() => appSettings.musicVolume = v),
                  ),
                _divider(),
                _row(
                  icon: Icons.vibration,
                  label: loc('Titreşim', 'Vibration'),
                  subtitle: loc('Yuvan saldırı altındayken uyarır',
                      'Buzzes when your nest is under attack'),
                  trailing: _GameSwitch(
                    value: appSettings.vibration,
                    onChanged: (v) => _update(() => appSettings.vibration = v),
                  ),
                ),
                _divider(),
                _row(
                  icon: Icons.healing,
                  label: loc('Yaralı geri çekilme', 'Wounded retreat'),
                  subtitle: loc(
                      'Canı %20 altına düşen askerin yuvaya kaçıp iyileşir',
                      'Soldiers under 20% HP flee home and recover'),
                  trailing: _GameSwitch(
                    value: appSettings.autoRetreat,
                    onChanged: (v) =>
                        _update(() => appSettings.autoRetreat = v),
                  ),
                ),
                _divider(),
                _row(
                  icon: Icons.auto_awesome,
                  label: loc('Yüksek grafik kalitesi', 'High graphics quality'),
                  subtitle: loc('Düşük cihazlarda kapatın (sis yumuşatması vb.)',
                      'Turn off on low-end devices (fog smoothing etc.)'),
                  trailing: _GameSwitch(
                    value: appSettings.highQuality,
                    onChanged: (v) =>
                        _update(() => appSettings.highQuality = v),
                  ),
                ),
                _divider(),
                // Dil: açılır liste yok — oyunvari seçim kutuları.
                _row(
                  icon: Icons.language,
                  label: loc('Dil', 'Language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _langChip('Türkçe', 'tr', enabled: true),
                      const SizedBox(width: 8),
                      _langChip('English', 'en', enabled: true),
                    ],
                  ),
                ),
                _divider(),
                // Sürüm bilgisi.
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Center(
                    child: Text(
                      'Ants War: Colonies — v$kAppVersion',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFD8C9A3)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFFF2E8D5),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: Colors.white10);

  /// Ses düzeyi: oyunvari ince bar (altın topuz, yeşil dolum).
  Widget _volumeRow(double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 6),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          activeTrackColor: const Color(0xFF8BC34A),
          inactiveTrackColor: Colors.white12,
          thumbColor: const Color(0xFFE8B33C),
          overlayColor: const Color(0x2EE8B33C),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        child: Slider(value: value, onChanged: onChanged),
      ),
    );
  }

  Widget _langChip(String label, String code, {required bool enabled}) {
    final selected = appSettings.language == code;
    return GestureDetector(
      onTap: enabled
          ? () {
              AudioController.uiClick();
              _update(() => appSettings.language = code);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5C7A2E) : const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF9CCC65) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? (selected ? Colors.white : Colors.white70)
                : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Oyunvari anahtar: yeşil dolan hap gövde, kayan altın topuz.
class _GameSwitch extends StatelessWidget {
  const _GameSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioController.uiClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 50,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF5C7A2E) : const Color(0xFF2C3A20),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: value ? const Color(0xFF9CCC65) : Colors.white24,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? const Color(0xFFE8B33C) : Colors.white38,
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
