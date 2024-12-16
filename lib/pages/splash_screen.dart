import 'package:flutter/cupertino.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: Center(
        child: Image.asset(
          'lib/images/bb_text_image.png',
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
} 