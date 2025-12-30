import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimestampInput extends StatefulWidget {
  final Duration? timestamp;
  final ValueChanged<Duration?> onChanged;
  final bool isModified;

  const TimestampInput({
    super.key,
    required this.timestamp,
    required this.onChanged,
    this.isModified = false,
  });

  @override
  State<TimestampInput> createState() => _TimestampInputState();
}

class _TimestampInputState extends State<TimestampInput> {
  late TextEditingController _minController;
  late TextEditingController _secController;
  late TextEditingController _msController;

  late FocusNode _minFocus;
  late FocusNode _secFocus;
  late FocusNode _msFocus;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _secController = TextEditingController();
    _msController = TextEditingController();

    _minFocus = FocusNode();
    _secFocus = FocusNode();
    _msFocus = FocusNode();

    _updateControllers();
  }

  @override
  void didUpdateWidget(TimestampInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      // Only update if the value changed externally (not by our own editing ideally, 
      // but here we are stateless regarding the source of truth, so we sync).
      // To avoid cursor jumping, we might need to check focus, but for now simple sync.
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (widget.timestamp == null) {
      if (_minController.text.isNotEmpty) _minController.text = "";
      if (_secController.text.isNotEmpty) _secController.text = "";
      if (_msController.text.isNotEmpty) _msController.text = "";
      return;
    }

    final int totalMs = widget.timestamp!.inMilliseconds;
    final int min = totalMs ~/ 60000;
    final int sec = (totalMs % 60000) ~/ 1000;
    final int ms = (totalMs % 1000) ~/ 10; // Centiseconds (0-99)

    _updateSingleController(_minController, _minFocus, min);
    _updateSingleController(_secController, _secFocus, sec);
    _updateSingleController(_msController, _msFocus, ms);
  }

  void _updateSingleController(TextEditingController controller, FocusNode focus, int value) {
    String formatted = value.toString().padLeft(2, '0');
    
    // If exact match, do nothing
    if (controller.text == formatted) return;

    // If focused, check if semantically equivalent to avoid overwriting user typing "1" -> "01"
    if (focus.hasFocus) {
      int? currentInput = int.tryParse(controller.text);
      if (currentInput != null && currentInput == value) {
        return; // Let the user keep typing (e.g. "1" instead of forcing "01")
      }
      // If values differ (e.g. user typed "65" which normalized to "5"), 
      // we generally want to update, BUT this disrupts typing flow if normalization happens live.
      // However, for +/- buttons (external change), we MUST update.
      // We can distinguish by checking if the change came from _onChanged (internal) or parent (external).
      // But here we are in _updateControllers which is called by didUpdateWidget.
      // The issue is distinguishing "parent update due to my change" vs "parent update due to other factor".
      // Since `widget.timestamp` is the source of truth, if I typed "65", timestamp becomes "1:05".
      // "sec" is 5. "65" != 5.
      // If I overwrite with "05", I lose "65".
      // The user asked to "allow multiple number inputs".
      // Maybe we should allow "65" to stay as "65" as long as it represents the correct duration component?
      // No, "65" seconds is semantically 1m 5s. 5s is the component.
      // So "65" != 5.
      // If we don't update, the field shows "65" but the actual time is "xx:05".
      // If we update, it jumps to "05".
      // Let's stick to the "semantically equivalent" check for now.
    }

    // Update text and preserve cursor if possible (though usually text changes length)
    // For simplicity, set text. If focused, maybe put cursor at end?
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _onChanged() {
    if (_minController.text.isEmpty && 
        _secController.text.isEmpty && 
        _msController.text.isEmpty) {
      // widget.onChanged(null); // Optional: allow clearing timestamp?
      return;
    }

    int min = int.tryParse(_minController.text) ?? 0;
    int sec = int.tryParse(_secController.text) ?? 0;
    int ms = int.tryParse(_msController.text) ?? 0;

    // Validate/Clamp (or allow overflow if requested? "Handle edge cases")
    // "Input validation to prevent invalid time values" -> Clamp?
    // "Adjust each time component... independently"
    
    // Let's clamp for safety, but maybe allow user to type 65 seconds and convert it?
    // "Handle edge cases (e.g., overflow between time units)"
    // This implies 65 seconds SHOULD be valid input that converts to 1:05.
    // So we won't clamp, we will just calculate Duration.
    
    final newDuration = Duration(
      minutes: min,
      seconds: sec,
      milliseconds: ms * 10,
    );

    widget.onChanged(newDuration);
  }

  @override
  void dispose() {
    _minController.dispose();
    _secController.dispose();
    _msController.dispose();
    _minFocus.dispose();
    _secFocus.dispose();
    _msFocus.dispose();
    super.dispose();
  }

  Widget _buildField(TextEditingController controller, FocusNode focusNode, String label, int width) {
    return SizedBox(
      width: width.toDouble(),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 10),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          border: OutlineInputBorder(
            borderSide: widget.isModified 
              ? const BorderSide(color: Colors.orange) 
              : const BorderSide(),
          ),
          enabledBorder: OutlineInputBorder(
             borderSide: widget.isModified 
              ? const BorderSide(color: Colors.orange) 
              : const BorderSide(color: Colors.grey),
          ),
          focusedBorder: const OutlineInputBorder(
             borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        style: TextStyle(
          fontSize: 12,
          color: widget.isModified ? Colors.deepOrange : Colors.black,
          fontWeight: widget.isModified ? FontWeight.bold : FontWeight.normal,
        ),
        onChanged: (_) => _onChanged(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timestamp == null) {
      return const SizedBox(
        width: 120,
        child: Center(child: Text("--:--.--", style: TextStyle(color: Colors.grey))),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildField(_minController, _minFocus, "MM", 32),
        const Text(":", style: TextStyle(fontWeight: FontWeight.bold)),
        _buildField(_secController, _secFocus, "SS", 32),
        const Text(".", style: TextStyle(fontWeight: FontWeight.bold)),
        _buildField(_msController, _msFocus, "ms", 32),
      ],
    );
  }
}
