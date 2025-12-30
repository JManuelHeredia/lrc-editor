import 'dart:io';
import '../models/lyric_line.dart';

class LrcHeader {
  String? title;
  String? artist;
  String? album;
  String? year;
  String? composer;
  String? lyricist;
  String? genre;

  LrcHeader({
    this.title,
    this.artist,
    this.album,
    this.year,
    this.composer,
    this.lyricist,
    this.genre,
  });
}

class LrcParser {
  static Future<(List<LyricLine>, LrcHeader)> lrcTextParser(String text) async {
    List<String> rawLines = text.split('\n');
    List<LyricLine> parsedLyrics = [];
    LrcHeader header = LrcHeader();

    // Regex para detectar encabezados LRC [key:value]
    RegExp headerRegExp = RegExp(r'^\[(\w+):(.*)\]');
    RegExp timeRegExp = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\]$');
    // Regex para detectar formato LRC [00:12.34]
    RegExp regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    // Procesar encabezados, maximo 10 lineas
    for (var line in rawLines.take(4)) {
      if (line.trim().isEmpty) continue;

      var match = headerRegExp.firstMatch(line);
      var timeMatch = timeRegExp.firstMatch(line);
      if (timeMatch != null) {
        // Es un tiempo LRC
        continue; // Saltar a la siguiente linea
      }

      if (match != null) {
        // Es un encabezado LRC
        String key = match.group(1)!;
        String value = match.group(2)!.trim();
        switch (key) {
          case 'ti':
            header.title = value;
            break;
          case 'ar':
            header.artist = value;
            break;
          case 'al':
            header.album = value;
            break;
          case 'year':
            header.year = value;
            break;
          case 'composer':
            header.composer = value;
            break;
          case 'lyricist':
            header.lyricist = value;
            break;
          case 'genre':
            header.genre = value;
            break;
        }
        continue; // Saltar a la siguiente linea
      }
    }

    for (var line in rawLines) {
      if (line.trim().isEmpty) continue;
      if (headerRegExp.hasMatch(line) && !regExp.hasMatch(line)) continue;
      // Saltar lineas que no contienen tiempo o texto
      if (!timeRegExp.hasMatch(line) && !regExp.hasMatch(line)) {
        // Es texto plano sin tiempo
        parsedLyrics.add(LyricLine(timestamp: null, text: line.trim()));
        continue; // Saltar a la siguiente linea
      }

      var match = regExp.firstMatch(line);
      if (match != null) {
        // Es una linea LRC existente
        int minutes = int.parse(match.group(1)!);
        int seconds = int.parse(match.group(2)!);
        int millis = int.parse(match.group(3)!);
        if (match.group(3)!.length == 2) {
          millis *= 10; // Ajuste formato centésimas
        }

        Duration time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        parsedLyrics.add(
          LyricLine(timestamp: time, text: match.group(4)!.trim()),
        );
      } else {
        // Es texto plano sin tiempo
        parsedLyrics.add(LyricLine(timestamp: null, text: line.trim()));
      }
    }
    return (parsedLyrics, header);
  }

  static Future<(List<LyricLine>, LrcHeader)> parseFile(File file) async {
    String content = await file.readAsString();
    final (parsedLyrics, header) = await lrcTextParser(content);

    return (parsedLyrics, header);
  }
}

class LrcSaveParser {
  static Future<String> parseLrcSave(
    List<LyricLine> lrcs,
    LrcHeader header,
  ) async {
    String lrcSave = "";
    // Add headers
    lrcSave += header.title != null ? "[ti:${header.title}]\n" : "";
    lrcSave += header.artist != null ? "[ar:${header.artist}]\n" : "";
    lrcSave += header.album != null ? "[al:${header.album}]\n" : "";
    lrcSave += header.year != null ? "[year:${header.year}]\n" : "";
    lrcSave += header.composer != null ? "[composer:${header.composer}]\n" : "";
    lrcSave += header.lyricist != null ? "[lyricist:${header.lyricist}]\n" : "";
    lrcSave += header.genre != null ? "[genre:${header.genre}]\n" : "";
    // Add lyrics
    for (var line in lrcs) {
      lrcSave += line.timestamp != null
          ? "[${line.timestamp!.inMinutes.toString().padLeft(2, '0')}:${line.timestamp!.inSeconds.remainder(60).toString().padLeft(2, '0')}.${line.timestamp!.inMilliseconds.remainder(100).toString().padLeft(2, '0')}]${line.text}\n"
          : "${line.text}\n";
    }
    return lrcSave;
  }
}
