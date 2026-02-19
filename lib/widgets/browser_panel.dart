import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/browser_tab_state.dart';

class BrowserPanel extends StatefulWidget {
  final List<BrowserTabState> tabs;
  final int activeTabIndex;
  final WebviewController? activeController;
  final bool isWebViewReady;
  final TextEditingController urlController;
  final bool currentBookmarked;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onReload;
  final VoidCallback onToggleBookmark;
  final VoidCallback onLoadUrl;
  final VoidCallback onNewTab;
  final VoidCallback onOpenGoogleAccountChooser;
  final Future<void> Function(int tabIndex) onShowTabMenu;
  final void Function(int tabIndex) onSwitchTab;
  final void Function(PointerDownEvent event)? onWebViewPointerDown;
  final void Function(PointerUpEvent event)? onWebViewPointerUp;

  const BrowserPanel({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.activeController,
    required this.isWebViewReady,
    required this.urlController,
    required this.currentBookmarked,
    required this.onGoBack,
    required this.onGoForward,
    required this.onReload,
    required this.onToggleBookmark,
    required this.onLoadUrl,
    required this.onNewTab,
    required this.onOpenGoogleAccountChooser,
    required this.onShowTabMenu,
    required this.onSwitchTab,
    this.onWebViewPointerDown,
    this.onWebViewPointerUp,
  });

  @override
  State<BrowserPanel> createState() => _BrowserPanelState();
}

class _BrowserPanelState extends State<BrowserPanel> {
  static const double _tabWidth = 180.0;
  static const double _tabGap = 6.0;

  final ScrollController _tabScrollController = ScrollController();
  final GlobalKey _tabViewportKey = GlobalKey();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _tabScrollController.addListener(_refreshTabScrollButtons);
    _ensureActiveTabVisible(animated: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTabScrollButtons();
    });
  }

  @override
  void didUpdateWidget(covariant BrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTabIndex != widget.activeTabIndex ||
        oldWidget.tabs.length != widget.tabs.length) {
      _ensureActiveTabVisible(animated: true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTabScrollButtons();
    });
  }

  @override
  void dispose() {
    _tabScrollController.removeListener(_refreshTabScrollButtons);
    _tabScrollController.dispose();
    super.dispose();
  }

  void _refreshTabScrollButtons() {
    if (!mounted) return;
    if (!_tabScrollController.hasClients) {
      if (_canScrollLeft || _canScrollRight) {
        setState(() {
          _canScrollLeft = false;
          _canScrollRight = false;
        });
      }
      return;
    }

    final position = _tabScrollController.position;
    final nextLeft = position.pixels > 1.0;
    final nextRight = position.pixels < position.maxScrollExtent - 1.0;

    if (nextLeft == _canScrollLeft && nextRight == _canScrollRight) return;
    setState(() {
      _canScrollLeft = nextLeft;
      _canScrollRight = nextRight;
    });
  }

  void _scrollTabsBy(double delta) {
    if (!_tabScrollController.hasClients) return;
    final position = _tabScrollController.position;
    final target = (_tabScrollController.offset + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _tabScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  void _onTabStripPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_tabScrollController.hasClients) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final delta = dx.abs() > 0.01 ? dx : dy;
    if (delta.abs() < 0.01) return;
    final position = _tabScrollController.position;
    final next = (_tabScrollController.offset + delta).clamp(
      0.0,
      position.maxScrollExtent,
    );
    _tabScrollController.jumpTo(next);
  }

  void _ensureActiveTabVisible({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_tabScrollController.hasClients) return;

      final viewportContext = _tabViewportKey.currentContext;
      final renderObject = viewportContext?.findRenderObject();
      if (renderObject is! RenderBox) return;

      final viewportWidth = math.max(0.0, renderObject.size.width);
      if (viewportWidth <= 0) return;

      const unit = _tabWidth + _tabGap;
      final tabStart = widget.activeTabIndex * unit;
      final tabEnd = tabStart + _tabWidth;

      final current = _tabScrollController.offset;
      final visibleEnd = current + viewportWidth;

      double target = current;
      if (tabStart < current) {
        target = tabStart - 12;
      } else if (tabEnd > visibleEnd) {
        target = tabEnd - viewportWidth + 12;
      }

      final clamped = target.clamp(
        0.0,
        _tabScrollController.position.maxScrollExtent,
      );
      if ((clamped - current).abs() < 1.0) return;

      if (animated) {
        _tabScrollController.animateTo(
          clamped,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _tabScrollController.jumpTo(clamped);
      }
      _refreshTabScrollButtons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeController;

    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Scroll tabs left',
                onPressed: _canScrollLeft ? () => _scrollTabsBy(-260) : null,
              ),
              Expanded(
                child: Listener(
                  onPointerSignal: _onTabStripPointerSignal,
                  child: Container(
                    key: _tabViewportKey,
                    child: ListView.builder(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.tabs.length,
                      itemBuilder: (context, index) {
                        final tab = widget.tabs[index];
                        final isActive = index == widget.activeTabIndex;
                        return GestureDetector(
                          onSecondaryTap: () => widget.onShowTabMenu(index),
                          child: InkWell(
                            onTap: () {
                              if (isActive) {
                                widget.onShowTabMenu(index);
                                return;
                              }
                              widget.onSwitchTab(index);
                            },
                            child: Container(
                              width: _tabWidth,
                              margin: const EdgeInsets.only(right: _tabGap),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
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
                                    onTap: () => widget.onShowTabMenu(index),
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
                onPressed: _canScrollRight ? () => _scrollTabsBy(260) : null,
              ),
              PopupMenuButton<int>(
                tooltip: 'All tabs',
                icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                onSelected: widget.onSwitchTab,
                itemBuilder: (context) {
                  return List<PopupMenuEntry<int>>.generate(
                    widget.tabs.length,
                    (index) {
                      final tab = widget.tabs[index];
                      final isActive = index == widget.activeTabIndex;
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
                onPressed: widget.onNewTab,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: active == null ? null : widget.onGoBack,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: active == null ? null : widget.onGoForward,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: active == null ? null : widget.onReload,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.manage_accounts_outlined, size: 20),
                tooltip: 'Google account chooser',
                onPressed: widget.onOpenGoogleAccountChooser,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: Icon(
                  widget.currentBookmarked ? Icons.star : Icons.star_border,
                  size: 20,
                ),
                tooltip: 'Toggle bookmark',
                onPressed: widget.onToggleBookmark,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: TextField(
                  controller: widget.urlController,
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
                  onSubmitted: (_) => widget.onLoadUrl(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                icon: const Icon(Icons.arrow_forward, size: 20),
                onPressed: widget.onLoadUrl,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.isWebViewReady && active != null
              ? KeyedSubtree(
                  key: ValueKey(widget.tabs[widget.activeTabIndex].id),
                  child: Listener(
                    onPointerDown: widget.onWebViewPointerDown,
                    onPointerUp: widget.onWebViewPointerUp,
                    child: Webview(active),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}
