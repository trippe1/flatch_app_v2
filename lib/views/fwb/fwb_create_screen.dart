import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/fwb_service.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class FwbCreateScreen extends StatefulWidget {
  const FwbCreateScreen({super.key});

  @override
  State<FwbCreateScreen> createState() => _FwbCreateScreenState();
}

class _FwbCreateScreenState extends State<FwbCreateScreen> {
  final _name = TextEditingController();
  bool _anonymous = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(
        context: context,
        message: 'Give your group a name.',
        type: ToastificationType.error,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await FwbService.createGroup(name, _anonymous);
      final me = await FwbService.displayName(FwbService.uid!);
      final link = FwbService.linkFor(id);
      // Share the invite. Text as specified.
      await SharePlus.instance.share(
        ShareParams(
          text: "Join $me's $name group on Farts with Buddies!\n$link",
        ),
      );
      if (!mounted) return;
      // Replace the create screen with the new group's chat.
      context.pushReplacementNamed(AppRoute.fwbChat.name, extra: id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(
        context: context,
        message: 'Could not create the group. $e',
        type: ToastificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Anonymous — No Names'),
                subtitle: const Text(
                  "Posts show as \"Anonymous\" so no one can tell who shared "
                  "what. You can still see who's in the group. This can't be "
                  'changed later.',
                ),
                value: _anonymous,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _anonymous = v),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _create,
                  icon:
                      _busy
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.ios_share_rounded),
                  label: Text(_busy ? 'Creating…' : 'Create & invite buddies'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
