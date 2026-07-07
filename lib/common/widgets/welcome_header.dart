import 'package:flatch/common/models/app_user.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeHeader extends StatelessWidget {
  final AppUser appUser;
  final String imagePath;
  final bool showNotificationDot;

  const WelcomeHeader({
    super.key,
    required this.appUser,
    required this.imagePath,
    this.showNotificationDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 25,
              backgroundImage:
                  imagePath.startsWith('http')
                      ? NetworkImage(imagePath)
                      : AssetImage(imagePath) as ImageProvider,
            ),

            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: appUser.name,
                  color: Colors.black87,
                  weight: FontWeight.bold,
                  size: 16,
                ),

                const Text(
                  "Welcome back!",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, size: 28),
              onPressed:
                  () => GoRouter.of(context).pushNamed(
                    appUser.role.toLowerCase() == 'student'
                        ? AppRoute.notifications.name
                        : AppRoute.consultantNotification.name,
                  ),
            ),
            if (showNotificationDot)
              const Positioned(
                right: 10,
                top: 10,
                child: CircleAvatar(backgroundColor: Colors.orange, radius: 4),
              ),
          ],
        ),
      ],
    );
  }
}
