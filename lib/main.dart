import 'package:flutter/material.dart';
import 'screens/editor_screen.dart';

void main() {
  runApp(const LrcEditorApp());
}

class LrcEditorApp extends StatelessWidget {
  const LrcEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: EditorScreen(), title: 'LRC Editor');
  }
}
