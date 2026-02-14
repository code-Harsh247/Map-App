import 'package:flutter/material.dart';

class PulsingLocationMarker extends StatefulWidget {
  final Color color;
  const PulsingLocationMarker({super.key, required this.color});

  @override
  State<PulsingLocationMarker> createState() => _PulsingLocationMarkerState();
}

class _PulsingLocationMarkerState extends State<PulsingLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing circles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 80 * _controller.value,
              height: 80 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.3 * (1 - _controller.value)),
              ),
            );
          },
        ),
        // Inner solid dot
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
