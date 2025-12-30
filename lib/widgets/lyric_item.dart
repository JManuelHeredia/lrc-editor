import 'package:flutter/material.dart';
import '../models/lyric_line.dart';
import 'timestamp_input.dart';

class LyricItem extends StatelessWidget {
  final LyricLine line;
  final bool isCurrent;
  final VoidCallback onTimestamp;
  final VoidCallback onSeek;
  final VoidCallback onDeleteLine;
  final VoidCallback onAddLine;
  final ValueChanged<Duration> onTimeChanged;
  final VoidCallback onResetTime;
  final ValueChanged<String> onLineEdit;

  const LyricItem({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.onTimestamp,
    required this.onSeek,
    required this.onDeleteLine,
    required this.onAddLine,
    required this.onTimeChanged,
    required this.onResetTime,
    required this.onLineEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isCurrent ? Colors.blue[50] : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Botón de Timestamp
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: line.timestamp != null
                  ? Colors.green
                  : Colors.grey,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            onPressed: onTimestamp,
            child: const Icon(Icons.timer, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          // Visualización del tiempo guardado (editable)
          TimestampInput(
            timestamp: line.timestamp,
            onChanged: (val) {
              if (val != null) onTimeChanged(val);
            },
            isModified: line.isModified,
          ),
          if (line.isModified)
            IconButton(
              icon: const Icon(Icons.restore, size: 16, color: Colors.orange),
              onPressed: onResetTime,
              tooltip: "Restaurar tiempo original",
            ),
          const SizedBox(width: 8),
          // Campo de texto editable
          Expanded(
            child: TextField(
              controller: line.controller,
              onSubmitted: (val) => onLineEdit(val),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              style: TextStyle(
                color: isCurrent ? Colors.blue : Colors.black,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          // Botón para probar la línea (Seek to this line)
          if (line.timestamp != null)
            IconButton(
              icon: const Icon(Icons.play_circle_outline, size: 20),
              onPressed: onSeek,
            ),
          // Delete line button
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            onPressed: onDeleteLine,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: onAddLine,
          ),
        ],
      ),
    );
  }
}
