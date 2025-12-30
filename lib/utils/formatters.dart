String formatDurationForLrc(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
  String twoDigitMillis = (d.inMilliseconds.remainder(1000) / 10).floor().toString().padLeft(2, "0");
  return "[$twoDigitMinutes:$twoDigitSeconds.$twoDigitMillis]";
}

String formatDurationDisplay(Duration d) {
  // Formato visual MM:SS
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
}
