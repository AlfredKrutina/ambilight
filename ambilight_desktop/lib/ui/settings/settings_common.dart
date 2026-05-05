import 'package:flutter/material.dart';

Widget paddedSettingsColumn(Iterable<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children
        .map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w))
        .toList(),
  );
}
