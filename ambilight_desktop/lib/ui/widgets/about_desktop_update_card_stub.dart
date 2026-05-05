import 'package:flutter/material.dart';

/// Na platformách bez `dart:io` se sekce aktualizace nezobrazuje.
class AboutDesktopUpdateCard extends StatelessWidget {
  const AboutDesktopUpdateCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
