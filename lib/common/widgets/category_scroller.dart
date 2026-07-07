import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';

class TopFartCategory {
  final String title;
  final String imageAsset;

  TopFartCategory({required this.title, required this.imageAsset});
}

class TopFartScroller extends StatelessWidget {
  final List<TopFartCategory> categories;
  final void Function(String category)? onCategorySelected;
  final String? selectedCategory;

  const TopFartScroller({
    super.key,
    required this.categories,
    this.onCategorySelected,
    this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category.title;

              return GestureDetector(
                onTap: () => onCategorySelected?.call(category.title),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border:
                            isSelected
                                ? Border.all(color: AppColors.primary, width: 3)
                                : null,
                        image: DecorationImage(
                          image: AssetImage(category.imageAsset),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: category.title,
                      weight: FontWeight.w600,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
