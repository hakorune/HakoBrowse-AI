part of 'bookmarks_panel.dart';

class _MiddleClickListener extends StatelessWidget {
  final Widget child;
  final VoidCallback onMiddleClick;

  const _MiddleClickListener({
    required this.child,
    required this.onMiddleClick,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if ((event.buttons & kMiddleMouseButton) == 0) return;
        onMiddleClick();
      },
      child: child,
    );
  }
}
