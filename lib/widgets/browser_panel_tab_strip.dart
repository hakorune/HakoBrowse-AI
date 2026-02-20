part of 'browser_panel.dart';

class _BrowserTabStrip extends StatelessWidget {
  final List<BrowserTabState> tabs;
  final int activeTabIndex;
  final bool canScrollLeft;
  final bool canScrollRight;
  final ScrollController tabScrollController;
  final GlobalKey tabViewportKey;
  final void Function(double delta) onScrollTabsBy;
  final void Function(PointerSignalEvent event) onTabStripPointerSignal;
  final Future<void> Function(int tabIndex) onShowTabMenu;
  final void Function(int tabIndex) onSwitchTab;
  final VoidCallback onNewTab;

  const _BrowserTabStrip({
    required this.tabs,
    required this.activeTabIndex,
    required this.canScrollLeft,
    required this.canScrollRight,
    required this.tabScrollController,
    required this.tabViewportKey,
    required this.onScrollTabsBy,
    required this.onTabStripPointerSignal,
    required this.onShowTabMenu,
    required this.onSwitchTab,
    required this.onNewTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Scroll tabs left',
            onPressed: canScrollLeft ? () => onScrollTabsBy(-260) : null,
          ),
          Expanded(
            child: Listener(
              onPointerSignal: onTabStripPointerSignal,
              child: Container(
                key: tabViewportKey,
                child: ListView.builder(
                  controller: tabScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final isActive = index == activeTabIndex;
                    return GestureDetector(
                      onSecondaryTap: () => onShowTabMenu(index),
                      child: InkWell(
                        onTap: () {
                          if (isActive) {
                            onShowTabMenu(index);
                            return;
                          }
                          onSwitchTab(index);
                        },
                        child: Container(
                          width: _BrowserPanelState._tabWidth,
                          margin: const EdgeInsets.only(
                            right: _BrowserPanelState._tabGap,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Theme.of(context).colorScheme.surface
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tab.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => onShowTabMenu(index),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.more_vert, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Scroll tabs right',
            onPressed: canScrollRight ? () => onScrollTabsBy(260) : null,
          ),
          PopupMenuButton<int>(
            tooltip: 'All tabs',
            icon: const Icon(Icons.arrow_drop_down_circle_outlined),
            onSelected: onSwitchTab,
            itemBuilder: (context) {
              return List<PopupMenuEntry<int>>.generate(
                tabs.length,
                (index) {
                  final tab = tabs[index];
                  final isActive = index == activeTabIndex;
                  return PopupMenuItem<int>(
                    value: index,
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New tab',
            onPressed: onNewTab,
          ),
        ],
      ),
    );
  }
}
