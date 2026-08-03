import 'package:flutter/material.dart';

class FartDetailsForm extends StatelessWidget {
  final TextEditingController titleController;
  final GlobalKey<FormState> formKey;

  const FartDetailsForm({
    super.key,
    required this.titleController,
    required this.formKey,
  });

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

            ],
          ),
        ),
      ),
    );
  }
}
