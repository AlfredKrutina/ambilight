import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Převod řetězců z PyQt / `keyboard` stylu (`ctrl+shift+l`) na [HotKey] pro `hotkey_manager`.
HotKey? hotKeyFromConfigString(
  String raw, {
  required String identifier,
}) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty || cleaned.toLowerCase() == '<none>') {
    return null;
  }
  final parts = cleaned
      .split('+')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  final keyToken = parts.removeLast();
  final mods = <HotKeyModifier>[];
  for (final p in parts) {
    switch (p) {
      case 'ctrl':
      case 'control':
        mods.add(HotKeyModifier.control);
        break;
      case 'shift':
        mods.add(HotKeyModifier.shift);
        break;
      case 'alt':
      case 'menu':
        mods.add(HotKeyModifier.alt);
        break;
      case 'meta':
      case 'win':
      case 'windows':
      case 'super':
      case 'cmd':
      case 'command':
        mods.add(HotKeyModifier.meta);
        break;
      case 'fn':
        mods.add(HotKeyModifier.fn);
        break;
      case 'caps':
      case 'capslock':
        mods.add(HotKeyModifier.capsLock);
        break;
      default:
        return null;
    }
  }
  final key = _logicalKeyForToken(keyToken);
  if (key == null) return null;
  return HotKey(
    identifier: identifier,
    key: key,
    modifiers: mods.isEmpty ? null : mods,
    scope: HotKeyScope.system,
  );
}

LogicalKeyboardKey? _logicalKeyForToken(String t) {
  const letters = {
    'a': LogicalKeyboardKey.keyA,
    'b': LogicalKeyboardKey.keyB,
    'c': LogicalKeyboardKey.keyC,
    'd': LogicalKeyboardKey.keyD,
    'e': LogicalKeyboardKey.keyE,
    'f': LogicalKeyboardKey.keyF,
    'g': LogicalKeyboardKey.keyG,
    'h': LogicalKeyboardKey.keyH,
    'i': LogicalKeyboardKey.keyI,
    'j': LogicalKeyboardKey.keyJ,
    'k': LogicalKeyboardKey.keyK,
    'l': LogicalKeyboardKey.keyL,
    'm': LogicalKeyboardKey.keyM,
    'n': LogicalKeyboardKey.keyN,
    'o': LogicalKeyboardKey.keyO,
    'p': LogicalKeyboardKey.keyP,
    'q': LogicalKeyboardKey.keyQ,
    'r': LogicalKeyboardKey.keyR,
    's': LogicalKeyboardKey.keyS,
    't': LogicalKeyboardKey.keyT,
    'u': LogicalKeyboardKey.keyU,
    'v': LogicalKeyboardKey.keyV,
    'w': LogicalKeyboardKey.keyW,
    'x': LogicalKeyboardKey.keyX,
    'y': LogicalKeyboardKey.keyY,
    'z': LogicalKeyboardKey.keyZ,
  };
  const digits = {
    '0': LogicalKeyboardKey.digit0,
    '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2,
    '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4,
    '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6,
    '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8,
    '9': LogicalKeyboardKey.digit9,
  };
  const fKeys = {
    'f1': LogicalKeyboardKey.f1,
    'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3,
    'f4': LogicalKeyboardKey.f4,
    'f5': LogicalKeyboardKey.f5,
    'f6': LogicalKeyboardKey.f6,
    'f7': LogicalKeyboardKey.f7,
    'f8': LogicalKeyboardKey.f8,
    'f9': LogicalKeyboardKey.f9,
    'f10': LogicalKeyboardKey.f10,
    'f11': LogicalKeyboardKey.f11,
    'f12': LogicalKeyboardKey.f12,
  };
  if (letters.containsKey(t)) return letters[t];
  if (digits.containsKey(t)) return digits[t];
  if (fKeys.containsKey(t)) return fKeys[t];
  switch (t) {
    case 'space':
      return LogicalKeyboardKey.space;
    case 'escape':
    case 'esc':
      return LogicalKeyboardKey.escape;
    case 'tab':
      return LogicalKeyboardKey.tab;
    case 'enter':
    case 'return':
      return LogicalKeyboardKey.enter;
    case 'backspace':
      return LogicalKeyboardKey.backspace;
    case 'delete':
    case 'del':
      return LogicalKeyboardKey.delete;
    case 'insert':
      return LogicalKeyboardKey.insert;
    case 'home':
      return LogicalKeyboardKey.home;
    case 'end':
      return LogicalKeyboardKey.end;
    case 'pageup':
    case 'pgup':
      return LogicalKeyboardKey.pageUp;
    case 'pagedown':
    case 'pgdn':
      return LogicalKeyboardKey.pageDown;
    case 'up':
      return LogicalKeyboardKey.arrowUp;
    case 'down':
      return LogicalKeyboardKey.arrowDown;
    case 'left':
      return LogicalKeyboardKey.arrowLeft;
    case 'right':
      return LogicalKeyboardKey.arrowRight;
    default:
      return null;
  }
}
