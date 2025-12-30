import 'dart:ui';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:lrc_editor/utils/lrc_parser.dart';
import '../utils/formatters.dart';

class PlayerControls extends StatefulWidget {
  final String? mp3Path;
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final AudioMetadata? audioTags;
  final LrcHeader? headers;

  const PlayerControls({
    super.key,
    required this.mp3Path,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.onSeek,
    this.audioTags,
    this.headers,
  });

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  // Hover state
  bool _isHovering = false;
  double _hoverX = 0.0;
  String _hoverTimeLabel = "";

  Uint8List? get _coverBytes {
    if (widget.audioTags?.pictures.isNotEmpty == true) {
      return widget.audioTags!.pictures.first.bytes;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Determine the slider value
    final double sliderValue = _isDragging
        ? _dragValue
        : widget.currentPosition.inSeconds.toDouble();

    final double maxDuration = widget.totalDuration.inSeconds.toDouble();
    final double maxSliderValue = maxDuration > 0 ? maxDuration : 1.0;

    final cover = _coverBytes;

    return ClipRRect(
      // borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // 1. Blurred Background
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: cover != null
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Image.memory(
                        cover,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        key: ValueKey(cover.hashCode),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      key: const ValueKey("default_bg"),
                    ),
            ),
          ),

          // Overlay for readability (darken if image exists)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(cover != null ? 0.3 : 0.0),
            ),
          ),

          // 2. Content
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 12,
              children: [
                Row(
                  children: [
                    // Cover Image (1:1)
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: cover != null
                              ? Image.memory(
                                  cover,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  key: ValueKey(cover.hashCode),
                                )
                              : const Icon(
                                  Icons.music_note,
                                  size: 40,
                                  color: Colors.grey,
                                  key: ValueKey("default_icon"),
                                ),
                        ),
                      ),
                    ),

                    // Controls
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.mp3Path != null)
                            Text(
                              widget.mp3Path!.split('\\').last,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cover != null
                                    ? Colors.white
                                    : Colors.black87,
                                shadows: cover != null
                                    ? [
                                        const Shadow(
                                          blurRadius: 4,
                                          color: Colors.black45,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  widget.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                ),
                                onPressed: widget.onPlayPause,
                                iconSize: 40,
                                color: cover != null
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              Text(
                                formatDurationDisplay(
                                  _isDragging
                                      ? Duration(seconds: _dragValue.toInt())
                                      : widget.currentPosition,
                                ),
                                style: TextStyle(
                                  color: cover != null
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return MouseRegion(
                                      onHover: (event) {
                                        setState(() {
                                          _isHovering = true;
                                          // Local position relative to the MouseRegion
                                          final dx = event.localPosition.dx;
                                          _hoverX = dx;

                                          // Calculate time
                                          // Ensure we don't divide by zero
                                          final width = constraints.maxWidth > 0
                                              ? constraints.maxWidth
                                              : 1.0;
                                          final ratio = (dx / width).clamp(
                                            0.0,
                                            1.0,
                                          );
                                          final seconds = maxDuration * ratio;
                                          _hoverTimeLabel =
                                              formatDurationDisplay(
                                                Duration(
                                                  seconds: seconds.toInt(),
                                                ),
                                              );
                                        });
                                      },
                                      onExit: (_) {
                                        setState(() {
                                          _isHovering = false;
                                        });
                                      },
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          // Ensure slider takes full width
                                          SizedBox(
                                            width: constraints.maxWidth,
                                            child: Slider(
                                              value: sliderValue.clamp(
                                                0.0,
                                                maxSliderValue,
                                              ),
                                              max: maxSliderValue,
                                              activeColor: cover != null
                                                  ? Colors.white
                                                  : null,
                                              inactiveColor: cover != null
                                                  ? Colors.white30
                                                  : null,
                                              onChanged: (value) {
                                                setState(() {
                                                  _isDragging = true;
                                                  _dragValue = value;
                                                });
                                              },
                                              onChangeEnd: (value) {
                                                setState(() {
                                                  _isDragging = false;
                                                });
                                                widget.onSeek(value);
                                              },
                                            ),
                                          ),
                                          if (_isHovering)
                                            Positioned(
                                              left: (_hoverX - 25).clamp(
                                                0.0,
                                                constraints.maxWidth - 50,
                                              ), // Center tooltip and clamp to bounds
                                              bottom: 35, // Above the slider
                                              child: IgnorePointer(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black87,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _hoverTimeLabel,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Text(
                                formatDurationDisplay(widget.totalDuration),
                                style: TextStyle(
                                  color: cover != null
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  // add gap between items
                  spacing: 16,
                  children: [
                    // Mostrar metadatos como texto editable,
                    // Ancho fijo para mejorar la alineación
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        style: TextStyle(
                          color: cover != null ? Colors.white : Colors.black87,
                        ),
                        initialValue:
                            widget.headers?.title ??
                            widget.audioTags?.title ??
                            "Sin Título",
                        decoration: const InputDecoration(
                          labelText: "Título",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        onChanged: (value) => widget.headers?.title = value,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        style: TextStyle(
                          color: cover != null ? Colors.white : Colors.black87,
                        ),
                        initialValue:
                            widget.headers?.artist ??
                            widget.audioTags?.artist ??
                            "Sin Artista",
                        decoration: const InputDecoration(
                          labelText: "Artista",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        onChanged: (value) => widget.headers?.artist = value,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        style: TextStyle(
                          color: cover != null ? Colors.white : Colors.black87,
                        ),
                        initialValue:
                            widget.headers?.album ??
                            widget.audioTags?.album ??
                            "Sin Álbum",
                        decoration: const InputDecoration(
                          labelText: "Album",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        onChanged: (value) => widget.headers?.album = value,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        style: TextStyle(
                          color: cover != null ? Colors.white : Colors.black87,
                        ),
                        initialValue:
                            widget.headers?.year?.toString() ??
                            widget.audioTags?.year?.toString() ??
                            "Sin Año",
                        decoration: const InputDecoration(
                          labelText: "Año",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        onChanged: (value) => widget.headers?.year = value,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
