import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/lyric_line.dart';
import '../utils/lrc_parser.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../widgets/player_controls.dart';
import '../widgets/lyric_item.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Estado
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<LyricLine> _lyrics = [];
  LrcHeader _headers = LrcHeader();
  String _lrcPath = "";
  AudioMetadata? _audioMetadata;

  String? _mp3Path;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  // Control de scroll para seguir la letra
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Listeners del Audio Player
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _currentPosition = p);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _totalDuration = d);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    for (var line in _lyrics) {
      line.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _clearState() async {
    await _audioPlayer.stop();
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _isPlaying = false;
    _lrcPath = "";
    _headers = LrcHeader();
    _audioMetadata = null;
    _audioPlayer.stop();
    // Reset source
    _resetLyrics();
    setState(() {});
  }

  Future<void> _globalOffset(Duration offset, bool isAdd) async {
    for (var line in _lyrics) {
      if (line.timestamp == null) continue;

      line.timestamp = isAdd
          ? line.timestamp! + offset
          : line.timestamp! - offset;
    }
    setState(() {});
  }

  Future<void> _pickFile() async {
    // Solicitar permisos de almacenamiento si es necesario (Android 10-)
    await Permission.storage.request();

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'txt', 'mp3'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String extension = result.files.single.extension!;

      if (extension == 'mp3') {
        _loadMp3(file.path);
      } else {
        _loadTextOrLrc(file);
      }
    }
  }

  void _loadMp3(String path) async {
    // Resetear letras y metadatos
    _resetLyrics();

    setState(() {
      _mp3Path = path;
    });
    _audioPlayer.setSource(DeviceFileSource(path));

    // Intentar leer letras de los tags
    final track = File(path);

    // Fetching images can slow down metadata reading
    final metadata = readMetadata(track, getImage: true);
    _audioMetadata = metadata;
    if (metadata.lyrics != null && metadata.lyrics!.isNotEmpty) {
      // Eliminar saltos de línea extra al inicio
      final cleanedLyrics = metadata.lyrics!.trimLeft();

      final (parsedLyrics, header) = await LrcParser.lrcTextParser(
        cleanedLyrics,
      );

      if (header.title?.isEmpty == true || header.title == null) {
        header.title = metadata.title;
      }
      if (header.artist?.isEmpty == true || header.artist == null) {
        header.artist = metadata.artist;
      }

      if (parsedLyrics.isNotEmpty) {
        setState(() {
          _lyrics = parsedLyrics;
          _headers = header;
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("MP3 Cargado. Ahora carga un TXT o escribe la letra."),
      ),
    );
  }

  void _resetLyrics() {
    setState(() {
      _lyrics = [];
      _headers = LrcHeader();
      _lrcPath = "";
      _audioMetadata = null;
    });
  }

  Future<void> _loadTextOrLrc(File file) async {
    // List<LyricLine> parsedLyrics = await LrcParser.parseFile(file);
    final parsed = await LrcParser.parseFile(file);
    final List<LyricLine> parsedLyrics = parsed.$1;
    // final LrcHeader header = parsed.$2;
    _headers = parsed.$2;
    _lrcPath = file.absolute.path;

    setState(() {
      _lyrics = parsedLyrics;
    });
  }

  Future<void> _copyLrcToClipboard() async {
    var lrcContent = await LrcSaveParser.parseLrcSave(_lyrics, _headers);
    await Clipboard.setData(ClipboardData(text: lrcContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Letra copiada al portapapeles")),
    );
  }

  Future<void> _saveLrcFile() async {
    if (_lyrics.isEmpty) return;

    // Generar contenido LRC
    String buffer = await LrcSaveParser.parseLrcSave(_lyrics, _headers);

    // Si es solo el archivo mp3, guardar sobre el mismo
    // Guardado simple: sobreescribe si cargaste un LRC o crea uno nuevo solicitando el path
    String? path = _lrcPath.isNotEmpty
        ? _lrcPath
        : await FilePicker.platform.saveFile(
            dialogTitle: "Guardar letra sincronizada",
            fileName: "letra_sincronizada.lrc",
            initialDirectory: Directory.current.path,
            allowedExtensions: ['lrc', 'txt'],
          );

    if (path != null) {
      var newPath = path;
      // Si es un txt, guardar como lrc
      if (newPath.endsWith(".txt")) {
        newPath = newPath.replaceAll(".txt", ".lrc");
      }
      print('newPath: $newPath');
      File(newPath).writeAsStringSync(buffer);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Archivo generado (Ver consola para output)"),
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor LRC Flutter"),
        actions: [
          // Botón para restar 1 segundo
          IconButton(
            onPressed: () => _globalOffset(const Duration(seconds: 1), false),
            icon: const Icon(Icons.remove),
            tooltip: "Restar 1 segundo",
          ),
          // Botón para agregar 1 segundo
          IconButton(
            onPressed: () => _globalOffset(const Duration(seconds: 1), true),
            icon: const Icon(Icons.add),
            tooltip: "Agregar 1 segundo",
          ),
          IconButton(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_open),
            tooltip: "Abrir Archivo",
          ),
          IconButton(
            onPressed: _saveLrcFile,
            icon: const Icon(Icons.save),
            tooltip: "Guardar/Exportar",
          ),
          IconButton(
            onPressed: _copyLrcToClipboard,
            icon: const Icon(Icons.copy),
            tooltip: "Copiar Letra al Portapapeles",
          ),
          IconButton(
            onPressed: _clearState,
            icon: const Icon(Icons.delete_forever),
            tooltip: "Limpiar Letra",
          ),
        ],
      ),
      body: Column(
        children: [
          Column(
            children: [
              PlayerControls(
                mp3Path: _mp3Path,
                isPlaying: _isPlaying,
                currentPosition: _currentPosition,
                totalDuration: _totalDuration,
                audioTags: _audioMetadata,
                headers: _headers,
                onPlayPause: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else if (_mp3Path != null) {
                    _audioPlayer.resume();
                  }
                },
                onSeek: (v) {
                  _audioPlayer.seek(Duration(seconds: v.toInt()));
                },
              ),
            ],
          ),
          // Lista de Letras
          Expanded(
            child: _lyrics.isEmpty
                ? const Center(
                    child: Text("Carga un archivo .txt o .lrc para comenzar"),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _lyrics.length,
                    itemBuilder: (context, index) {
                      final line = _lyrics[index];
                      final bool isCurrent =
                          line.timestamp != null &&
                          _currentPosition >= line.timestamp! &&
                          (index == _lyrics.length - 1 ||
                              _lyrics[index + 1].timestamp == null ||
                              _currentPosition < _lyrics[index + 1].timestamp!);

                      return LyricItem(
                        line: line,
                        onLineEdit: (String val) {
                          setState(() {
                            _lyrics[index].text = val;
                          });
                        },
                        isCurrent: isCurrent,
                        onTimestamp: () {
                          setState(() {
                            line.timestamp = _currentPosition;
                          });
                        },
                        onDeleteLine: () {
                          setState(() {
                            _lyrics.removeAt(index);
                          });
                        },
                        onSeek: () => _audioPlayer.seek(line.timestamp!),
                        onAddLine: () {
                          setState(() {
                            _lyrics.insert(
                              index + 1,
                              LyricLine(text: "", timestamp: _currentPosition),
                            );
                          });
                        },
                        onTimeChanged: (newTime) {
                          setState(() {
                            line.timestamp = newTime;
                          });
                        },
                        onResetTime: () {
                          setState(() {
                            line.resetTimestamp();
                          });
                        },
                      );
                    },
                  ),
          ),

          // 3. Área de pegado si está vacío (Manejo de tags simples)
          if (_lyrics.isEmpty && _mp3Path != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
                  final text = await Clipboard.getData(Clipboard.kTextPlain);
                  // Simulación de pegar desde portapapeles o tags
                  if (text?.text != null && text!.text!.isNotEmpty) {
                    final clipbd = text.text;
                    final (parsedLyrics, header) =
                        await LrcParser.lrcTextParser(clipbd!);
                    if (parsedLyrics.isNotEmpty) {
                      setState(() {
                        _lyrics = parsedLyrics;
                        _headers = header;
                      });
                    }
                  }
                },
                child: const Text("Pegar letra o Crear Nueva"),
              ),
            ),
        ],
      ),
    );
  }
}
