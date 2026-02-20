part of 'browser_panel.dart';

class _BrowserToolbar extends StatelessWidget {
  final bool hasActiveController;
  final bool currentBookmarked;
  final TextEditingController urlController;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onReload;
  final VoidCallback onOpenGoogleAccountChooser;
  final VoidCallback onToggleBookmark;
  final VoidCallback onLoadUrl;

  const _BrowserToolbar({
    required this.hasActiveController,
    required this.currentBookmarked,
    required this.urlController,
    required this.onGoBack,
    required this.onGoForward,
    required this.onReload,
    required this.onOpenGoogleAccountChooser,
    required this.onToggleBookmark,
    required this.onLoadUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: hasActiveController ? onGoBack : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: hasActiveController ? onGoForward : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: hasActiveController ? onReload : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined, size: 20),
            tooltip: 'Google account chooser',
            onPressed: onOpenGoogleAccountChooser,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              currentBookmarked ? Icons.star : Icons.star_border,
              size: 20,
            ),
            tooltip: 'Toggle bookmark',
            onPressed: onToggleBookmark,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onLoadUrl(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            icon: const Icon(Icons.arrow_forward, size: 20),
            onPressed: onLoadUrl,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
