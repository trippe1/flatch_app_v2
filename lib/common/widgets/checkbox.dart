import 'package:flutter/material.dart';

class CCheckBox extends StatelessWidget {
  final bool? isChecked;
  const CCheckBox({super.key, this.isChecked});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isChecked ?? false
                  ? colorScheme
                      .primary // highlighted when checked
                  : colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ), // neutral border
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsets.all((isChecked ?? false) ? 1 : 0),
      child:
          (isChecked ?? false)
              ? Icon(
                Icons.check,
                size: 16,
                color: colorScheme.primary, // check adapts to theme
              )
              : const SizedBox(height: 18, width: 18),
    );
  }
}
