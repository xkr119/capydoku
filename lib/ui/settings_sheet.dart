/// 소리·진동 설정.
///
/// 조용한 자리에서 소리가 나면 앱을 지운다. 끄는 길은 눈에 보이는 곳에 있어야 한다.
library;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../core/lang.dart';

class SettingsSheet extends StatefulWidget {
  /// 이름 바꾸기. 홈에서만 넘겨준다 — 게임 화면에서는 이름을 바꿀 일이 없다.
  ///
  /// 이름표에 연필 버튼을 달아 두었더니 이름 옆에 늘 UI 부품이 붙어 있었다.
  /// 이름은 한 번 짓고 거의 안 바꾸는 것이라 설정 안이 제자리다.
  final Future<void> Function()? onRename;

  /// 규칙 설명 다시 보기. **어디서 열든 있어야 한다** — 판을 풀다가 헷갈리는
  /// 일이 더 많고, 그때 홈까지 나가라고 하면 아무도 안 본다.
  final Future<void> Function()? onHelp;

  const SettingsSheet({super.key, this.onRename, this.onHelp});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      title: Text(L.t('설정', 'Settings'),
          style: TextStyle(fontSize: 20, color: Palette.brown)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // 언어. **기기 설정을 따르는 것이 기본**이지만 고를 수 있어야 한다 —
        // 한국에 사는 영어 사용자, 해외에 사는 한국어 사용자가 둘 다 있다.
        ListTile(
          leading: const Icon(Icons.translate_rounded,
              color: Color(0xFFF2802B)),
          title: Text(L.t('언어', 'Language'),
              style: const TextStyle(fontSize: 16, color: Palette.brown)),
          trailing: DropdownButton<Lang>(
            value: L.pick,
            underline: const SizedBox.shrink(),
            onChanged: (v) async {
              if (v == null) return;
              await L.setPick(v);
              if (context.mounted) setState(() {});
            },
            items: [
              DropdownMenuItem(
                  value: Lang.auto,
                  child: Text(L.t('기기 설정', 'System'))),
              const DropdownMenuItem(value: Lang.ko, child: Text('한국어')),
              const DropdownMenuItem(value: Lang.en, child: Text('English')),
            ],
          ),
        ),
        if (widget.onHelp != null)
          ListTile(
            onTap: () async {
              Navigator.pop(context);
              await widget.onHelp!();
            },
            leading:
                const Icon(Icons.help_outline_rounded, color: Color(0xFFF2802B)),
            title: Text(L.t('설명', 'How to play'),
                style: TextStyle(fontSize: 16, color: Palette.brown)),
            subtitle: Text(L.t('규칙과 조작법 다시 보기', 'Rules and controls again'),
                style: TextStyle(
                    fontSize: 12,
                    color: Palette.brownSoft,
                    fontFamily: 'Apple SD Gothic Neo')),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Palette.brownSoft),
          ),
        if (widget.onRename != null)
          ListTile(
            onTap: () async {
              Navigator.pop(context);
              await widget.onRename!();
            },
            leading: const Icon(Icons.edit_rounded, color: Color(0xFFF2802B)),
            title: Text(L.t('이름 바꾸기', 'Rename'),
                style: TextStyle(fontSize: 16, color: Palette.brown)),
            subtitle: Text(L.t('카피를 뭐라고 부를까요', 'What should we call your capy'),
                style: TextStyle(
                    fontSize: 12,
                    color: Palette.brownSoft,
                    fontFamily: 'Apple SD Gothic Neo')),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Palette.brownSoft),
          ),
        _row(
          icon: Icons.volume_up_rounded,
          label: L.t('소리', 'Sound'),
          hint: L.t('카피 목소리와 효과음', 'Capy voice and effects'),
          value: Settings.sound,
          onChanged: (v) async {
            await Settings.setSound(v);
            if (v) Sfx.place(); // 켜자마자 들려 준다 — 켜졌는지 알 수 있게
            setState(() {});
          },
        ),
        _row(
          icon: Icons.vibration_rounded,
          label: L.t('진동', 'Vibration'),
          hint: L.t('칸을 누를 때의 손맛', 'A nudge when you tap a tile'),
          value: Settings.haptics,
          onChanged: (v) async {
            await Settings.setHaptics(v);
            if (v) Buzz.medium();
            setState(() {});
          },
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L.t('닫기', 'Close')),
        ),
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String hint,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: const Color(0xFFF2802B),
      secondary: Icon(icon,
          color: value ? const Color(0xFFF2802B) : Palette.brownSoft),
      title: Text(label,
          style: const TextStyle(fontSize: 16, color: Palette.brown)),
      subtitle: Text(hint,
          style: const TextStyle(
              fontSize: 12,
              color: Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo')),
    );
  }
}
