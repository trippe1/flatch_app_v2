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

  static final _choices = [
    {'id': 'record', 'icon': Icons.mic_rounded, 'label': 'Record'},
    {'id': 'audio', 'icon': Icons.audiotrack_rounded, 'label': 'Audio'},
    {'id': 'video', 'icon': Icons.videocam_rounded, 'label': 'Video'},
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
          Row(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
