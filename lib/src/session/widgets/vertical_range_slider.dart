import 'package:flutter/material.dart';
import '../../home/helpers/color_scheme.dart';

class VerticalScrubRangeSlider extends StatefulWidget {
  final int totalPoints;
  final RangeValues currentRange;
  final ValueChanged<RangeValues> onChanged;

  const VerticalScrubRangeSlider({
    super.key,
    required this.totalPoints,
    required this.currentRange,
    required this.onChanged,
  });

  @override
  State<VerticalScrubRangeSlider> createState() => _VerticalScrubRangeSliderState();
}

enum _ActiveThumb { start, end, none }

class _VerticalScrubRangeSliderState extends State<VerticalScrubRangeSlider> {
  _ActiveThumb _activeThumb = _ActiveThumb.none;
  
  double _startY = 0.0;
  double _startValue = 0.0;
  double _sensitivityMultiplier = 1.0;

  double _calculateSensitivity(double currentY) {
    final double verticalDistance = (_startY - currentY).clamp(0.0, 300.0);
    
    if (verticalDistance < 30) return 1.0;
    if (verticalDistance < 100) return 0.75;
    if (verticalDistance < 200) return 0.5;
    return 0.1;
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    final double localX = details.localPosition.dx;
    final double trackWidth = constraints.maxWidth;

    final double startX = widget.currentRange.start * trackWidth;
    final double endX = widget.currentRange.end * trackWidth;

    final double distToStart = (localX - startX).abs();
    final double distToEnd = (localX - endX).abs();

    if (distToStart < distToEnd && distToStart < 40) {
      _activeThumb = _ActiveThumb.start;
      _startValue = widget.currentRange.start;
    } else if (distToEnd < 40) {
      _activeThumb = _ActiveThumb.end;
      _startValue = widget.currentRange.end;
    } else {
      _activeThumb = _ActiveThumb.none;
      return;
    }

    _startY = details.globalPosition.dy;
    _sensitivityMultiplier = 1.0;
    setState(() {}); // Re-render once to update active thumb visual style
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_activeThumb == _ActiveThumb.none) return;

    final double currentY = details.globalPosition.dy;
    final double trackWidth = constraints.maxWidth;

    // Direct assignment - DO NOT call setState here (parent rebuilds widget anyway)
    _sensitivityMultiplier = _calculateSensitivity(currentY);

    final double deltaNormalized = (details.delta.dx / trackWidth) * _sensitivityMultiplier * 3;

    double newStart = widget.currentRange.start;
    double newEnd = widget.currentRange.end;

    final double minGap = 1.0 / (widget.totalPoints > 1 ? widget.totalPoints - 1 : 1);

    if (_activeThumb == _ActiveThumb.start) {
      newStart = (newStart + deltaNormalized).clamp(0.0, newEnd - minGap);
    } else {
      newEnd = (newEnd + deltaNormalized).clamp(newStart + minGap, 1.0);
    }

    widget.onChanged(RangeValues(newStart, newEnd));
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activeThumb = _ActiveThumb.none;
      _sensitivityMultiplier = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d, constraints),
            onPanUpdate: (d) => _onPanUpdate(d, constraints),
            onPanEnd: _onPanEnd,
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: CustomPaint(
                painter: _RangePainter(
                  range: widget.currentRange,
                  activeThumb: _activeThumb,
                  colorScheme: myColorScheme,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  final RangeValues range;
  final _ActiveThumb activeThumb;
  final ColorScheme colorScheme;

  _RangePainter({required this.range, required this.activeThumb, required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double startX = range.start * size.width;
    final double endX = range.end * size.width;

    final paintBackground = Paint()
      ..color = colorScheme.onPrimary
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paintBackground);

    final paintSelected = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), paintSelected);

    final paintThumb = Paint()..color = colorScheme.primary;
    final paintActive = Paint()..color = colorScheme.tertiary;

    canvas.drawCircle(
      Offset(startX, centerY),
      activeThumb == _ActiveThumb.start ? 12.0 : 8.0,
      activeThumb == _ActiveThumb.start ? paintActive : paintThumb,
    );
    canvas.drawCircle(
      Offset(endX, centerY),
      activeThumb == _ActiveThumb.end ? 12.0 : 8.0,
      activeThumb == _ActiveThumb.end ? paintActive : paintThumb,
    );
  }

  @override
  bool shouldRepaint(covariant _RangePainter oldDelegate) {
    return oldDelegate.range != range || oldDelegate.activeThumb != activeThumb;
  }
}