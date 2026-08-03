import 'package:flutter/material.dart';
import 'package:flatch/common/color/app_colors.dart';

class InputSelectorWidget extends StatelessWidget {
  final String? selectedChoice;
  final Function(String) onChoiceSelected;

  const InputSelectorWidget({
    super.key,
    required this.selectedChoice,
    required this.onChoiceSelected,
  });

  // Note: 'audio' pulls from the Files app, 'video' from the Photos library —
  // the ids are unchanged (the pickers key off them); only the labels/icons
  // present them as "Upload from Files" / "Upload from Photos". Generic
  // folder/photo glyphs are used rather than Apple's trademarked Files/Photos
  // app icons.
  static final _choices = [
    {'id': 'record', 'icon': Icons.mic_rounded, 'label': 'Record'},
    {'id': 'audio', 'icon': Icons.folder_rounded, 'label': 'Upload from Files'},
    {
      'id': 'video',
      'icon': Icons.photo_library_rounded,
      'label': 'Upload from Photos',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.upload_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Choose Input Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The labels wrap to different line counts ("Record" is one line,
          // the uploads are two), so each box used to size itself. IntrinsicHeight
          // + stretch makes them all match the tallest.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(_choices.length, (i) {
                final choice = _choices[i];
                return Expanded(
                  child: _ChoiceButton(
                    icon: choice['icon'] as IconData,
                    label: choice['label'] as String,
                    isSelected: selectedChoice == choice['id'],
                    onTap: () => onChoiceSelected(choice['id'] as String),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : Colors.grey[600];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color!, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
