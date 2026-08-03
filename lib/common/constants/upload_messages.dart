import 'dart:math';

/// Deadpan-but-fun confirmations shown when a fart is saved (to the community
/// or the user's own library). Pick one at random each time.
class UploadMessages {
  static const List<String> messages = [
    'Successfully deployed.',
    'Submission not silent, not deadly.',
    'Cleared for takeoff.',
    'Fart received loud and clear.',
    'Uploaded with gusto.',
    "That one's a keeper.",
    'Air mail: delivered.',
    'Gas in the cloud.',
    'Rip received.',
    'Certified fresh.',
    'Boom. Uploaded.',
    'Sound barrier: broken.',
    'Launch successful.',
    'One small toot for man.',
    'Direct hit.',
    "Upload complete. Chef's kiss.",
    "Now that's a contribution.",
    'Signal strong. Smell stronger.',
    'Payload delivered.',
    'Instant classic.',
  ];

  static final Random _rand = Random();

  static String random() => messages[_rand.nextInt(messages.length)];
}
