import 'package:flutter/material.dart';

class FartDetailsForm extends StatelessWidget {
  final TextEditingController titleController;
  final String? selectedCategory;
  final Function(String) onCategoryChanged;
  final GlobalKey<FormState> formKey;

  const FartDetailsForm({
    super.key,
    required this.titleController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.formKey,
  });

  static const List<String> categories = [
    'Wet',
    'Sneaky',
    'Loud',
    'Quick',
    'Long',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Fart Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: titleController,
                decoration: InputDecoration(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Title'),
                      Text(' *', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  hintText: 'Give your fart a catchy name',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Title is required'
                            : null,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                // Keyed by the controlled value so a programmatic reset (e.g.
                // clearing the form) rebuilds the field with the new
                // initialValue — `initialValue` alone only applies on first build.
                key: ValueKey(selectedCategory),
                initialValue: selectedCategory,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Category'),
                      Text(' *', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  hintText: 'Select a category',
                  prefixIcon: const Icon(Icons.category_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                items:
                    categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            _getCategoryIcon(category),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onCategoryChanged(value);
                  }
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Category is required'
                            : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData icon;
    Color color;

    switch (category) {
      case 'Wet':
        icon = Icons.water_drop_rounded;
        color = Colors.blue;
        break;
      case 'Sneaky':
        icon = Icons.visibility_off_rounded;
        color = Colors.grey;
        break;
      case 'Loud':
        icon = Icons.volume_up_rounded;
        color = Colors.red;
        break;
      case 'Quick':
        icon = Icons.flash_on_rounded;
        color = Colors.orange;
        break;
      case 'Long':
        icon = Icons.timeline_rounded;
        color = Colors.green;
        break;
      case 'Other':
        icon = Icons.more_horiz_rounded;
        color = Colors.purple;
        break;
      default:
        icon = Icons.category_rounded;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 20);
  }
}
