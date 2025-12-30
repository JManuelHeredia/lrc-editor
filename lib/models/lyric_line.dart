import 'package:flutter/material.dart';

class LyricLine {
  Duration? timestamp;
  Duration? originalTimestamp;
  String text;
  TextEditingController controller;

  LyricLine({this.timestamp, required this.text}) 
      : controller = TextEditingController(text: text),
        originalTimestamp = timestamp;

  bool get isModified => timestamp != originalTimestamp;

  void resetTimestamp() {
    timestamp = originalTimestamp;
  }
}
