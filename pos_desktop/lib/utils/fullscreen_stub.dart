import 'package:window_manager/window_manager.dart';

void toggleFullScreen() async {
  bool isFull = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!isFull);
}
