import 'package:flutter/material.dart';

class ZapSlider extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final List<int> presetValues;
  const ZapSlider({
    Key? key,
    required this.initialValue,
    required this.onChanged,
    this.presetValues = const [21, 210, 1000, 10000],
  }) : super(key: key);

  @override
  State<ZapSlider> createState() => _ZapSliderState();
}

class _ZapSliderState extends State<ZapSlider> {
  late int _selectedValue;
  final TextEditingController _customController = TextEditingController();
  bool _customSelected = false;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _customController.text = '';
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectValue(int value) {
    setState(() {
      _selectedValue = value;
      _customSelected = false;
      _customController.text = '';
    });
    widget.onChanged(value);
  }

  void _selectCustom() {
    setState(() {
      _customSelected = true;
      _selectedValue = 0;
    });
  }

  void _onCustomChanged(String value) {
    final intValue = int.tryParse(value) ?? 0;
    setState(() => _selectedValue = intValue);
    widget.onChanged(intValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            for (final value in widget.presetValues)
              ChoiceChip(
                label: Text('$value'),
                selected: !_customSelected && _selectedValue == value,
                onSelected: (_) => _selectValue(value),
              ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _customSelected,
              onSelected: (_) => _selectCustom(),
            ),
          ],
        ),
        if (_customSelected)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _customController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Custom zap amount (sats)',
                border: OutlineInputBorder(),
              ),
              onChanged: _onCustomChanged,
            ),
          ),
      ],
    );
  }
}
