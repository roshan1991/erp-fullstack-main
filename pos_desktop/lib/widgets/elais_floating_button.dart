import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pos_provider.dart';
import '../screens/elais_screen.dart';

class ElaisFloatingButton extends StatefulWidget {
  const ElaisFloatingButton({Key? key}) : super(key: key);

  @override
  _ElaisFloatingButtonState createState() => _ElaisFloatingButtonState();
}

class _ElaisFloatingButtonState extends State<ElaisFloatingButton> {
  bool _isOpen = false;
  Offset _buttonPosition = const Offset(20, 20);

  void _toggleOverlay() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    if (!provider.isLoggedIn) return const SizedBox.shrink();

    return Stack(
      children: [
        if (_isOpen)
          Positioned(
            right: _buttonPosition.dx,
            bottom: _buttonPosition.dy + 70,
            child: Material(
              elevation: 20,
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF1E1E2C),
              child: Container(
                width: 400,
                height: 600,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.3), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      const ElaisScreen(isOverlay: true),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          hoverColor: Colors.white10,
                          splashRadius: 20,
                          onPressed: _toggleOverlay,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: _buttonPosition.dx,
          bottom: _buttonPosition.dy,
          child: Draggable(
            feedback: FloatingActionButton(
              onPressed: null,
              backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.7),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            childWhenDragging: const SizedBox.shrink(),
            onDragEnd: (details) {
              final screenSize = MediaQuery.of(context).size;
              setState(() {
                // Calculate position from bottom-right
                double newRight = screenSize.width - details.offset.dx - 56; // 56 is FAB size
                double newBottom = screenSize.height - details.offset.dy - 56;
                // Constraints
                _buttonPosition = Offset(
                  newRight.clamp(10, screenSize.width - 66),
                  newBottom.clamp(10, screenSize.height - 66),
                );
              });
            },
            child: FloatingActionButton(
              onPressed: _toggleOverlay,
              backgroundColor: const Color(0xFFFF6B6B),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  if (provider.elaisAlerts.isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
