/// 소리·진동 설정.
///
/// 조용한 자리에서 소리가 나면 앱을 지운다. 끄는 길은 눈에 보이는 곳에 있어야 한다.
library;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/settings.dart';
import '../core/sfx.dart';

class SettingsSheet extends StatefulWidget {
  /// 이름 바꾸기. 홈에서만 넘겨준다 — 게임 화면에서는 이름을 바꿀 일이 없다.
  ///
  /// 이름표에 연필 버튼을 달아 두었더니 이름 옆에 늘 UI 부품이 붙어 있었다.
  /// 이름은 한 번 짓고 거의 안 바꾸는 것이라 설정 안이 제자리다.
  final Future<void> Function()? onRename;

  const SettingsSheet({super.key, this.onRename});

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
      title: const Text('설정',
          style: TextStyle(fontSize: 20, color: Palette.brown)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.onRename != null)
          ListTile(
            onTap: () async {
              Navigator.pop(context);
              await widget.onRename!();
            },
            leading: const Icon(Icons.edit_rounded, color: Color(0xFFF2802B)),
            title: const Text('이름 바꾸기',
                style: TextStyle(fontSize: 16, color: Palette.brown)),
            subtitle: const Text('카피를 뭐라고 부를까요',
                style: TextStyle(
                    fontSize: 12,
                    color: Palette.brownSoft,
                    fontFamily: 'Apple SD Gothic Neo')),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Palette.brownSoft),
          ),
        _row(
          icon: Icons.volume_up_rounded,
          label: '소리',
          hint: '카피 목소리와 효과음',
          value: Settings.sound,
          onChanged: (v) async {
            await Settings.setSound(v);
            if (v) Sfx.place(); // 켜자마자 들려 준다 — 켜졌는지 알 수 있게
            setState(() {});
          },
        ),
        _row(
          icon: Icons.vibration_rounded,
          label: '진동',
          hint: '칸을 누를 때의 손맛',
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
          child: const Text('닫기'),
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
