import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';

import '../generated/l10n.dart';
import 'utils.dart';

/// display a value with + and - buttons
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.lowerLimit,
    required this.upperLimit,
    required this.value,
    required this.valueChanged,
    required this.formatNumber,
    required this.largeSteps,
  });

  final int lowerLimit;
  final int upperLimit;
  final double iconSize = 16;
  final int value;
  final ValueChanged<int> valueChanged;
  final bool formatNumber;
  final bool largeSteps;

  @override
  CustomStepperState createState() => CustomStepperState();
}

class CustomStepperState extends State<NumberStepper> {
  bool _isEditingText = false;
  late TextEditingController _editingController;
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _editingController = TextEditingController(text: _value.toString());
  }

  @override
  void didUpdateWidget(NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  Widget _editableTextField() {
    if (_isEditingText) {
      _editingController.value = TextEditingValue(text: _value.toString());
      return Center(
        child: SizedBox(
          width: 112,
          child: TextField(
            maxLines: 1,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            keyboardType: TextInputType.number,
            inputFormatters: [
              LengthLimitingTextInputFormatter(5),
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (newValue) {
              setState(() {
                var oldVal = _value;
                try {
                  _value = int.parse(newValue);
                } on FormatException {
                  _value = oldVal;
                } finally {
                  widget.valueChanged(_value);
                  _isEditingText = false;
                }
              });
            },
            autofocus: true,
            controller: _editingController,
            decoration: InputDecoration(suffixText: S.of(context).seconds),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () {
        setState(() {
          _isEditingText = true;
        });
      },
      child: NumberPicker(
        itemHeight: 32,
        value: _value,
        minValue: widget.lowerLimit,
        step: 10,
        itemCount: 3,
        haptics: true,
        zeroPad: false,
        maxValue: widget.upperLimit,
        textMapper: (value) => Utils.formatSeconds(int.parse(value)),
        onChanged: (value) {
          setState(() {
            _value = value;
            widget.valueChanged(value);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.largeSteps
      ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _editableTextField(),
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () {
                setState(() {
                  _value = _value == widget.lowerLimit
                      ? widget.lowerLimit
                      : _value - 1;
                });
                widget.valueChanged(_value);
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${widget.formatNumber ? Utils.formatSeconds(_value) : _value}',
                style: TextStyle(
                  fontSize: widget.iconSize * 1.2,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                setState(() {
                  _value = _value == widget.upperLimit
                      ? widget.upperLimit
                      : _value + 1;
                });
                widget.valueChanged(_value);
              },
            ),
          ],
        );
}
