import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/brand.dart';
import 'package:flutter/material.dart';

/// About screen — origin story as historical record, deadpan. No comedy bit.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FlatchWordmark(fontSize: 30),
              const SizedBox(height: 24),
              const Text(
                'Flatulations are not funny.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              const _Para(
                'I was accused of a crime I did not commit - or emit. After a '
                'brief defense against the bus driver, I was called into the '
                "Assistant Principal's office one morning in middle school "
                'for... flatulating. Passing gas. Cutting the cheese. Dropping '
                'an air biscuit, crop dusting, bottom burping. FARTING. The '
                "only problem? It wasn't me. It was a kid in the back of the "
                'bus who released a stink bomb.',
              ),
              const _Para(
                'My Asst. Principal struggled with words as she enforced what '
                'can only have been a policy from the Cold War. I wrestled with '
                'the comedic value of the situation and getting a citation on '
                'my record. The Principal collected herself, looked me in the '
                'eye, and said these words that I\'ll never forget: '
                '"Flatulations are not funny."',
              ),
              const _Para(
                "Why did she say that? I wasn't even laughing. HOW could she "
                'say it? Farts are totally funny. But then again, maybe farts '
                "aren't funny for everyone? It was a confusing time of life.",
              ),
              const _Para(
                "So here's the Flatch. It's a serious device with a funny "
                "feature that's not for everyone. But for people like you and "
                "me, it's a gas - a blast, sometimes.",
              ),
              const SizedBox(height: 8),
              Text(
                '-Evan',
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: AppColors.warmGray,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Para extends StatelessWidget {
  final String text;
  const _Para(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5)),
  );
}
