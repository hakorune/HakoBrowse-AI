// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateWidgetsExt on _HomePageState {
  Widget _buildChatPanel() {
    return ChatPanel(
      agentProfiles: _agentProfiles,
      selectedAgentIds: _selectedAgentIds,
      enableSafetyGate: _enableSafetyGate,
      isAiResponding: _isAiResponding,
      onToggleSafety: () {
        setState(() => _enableSafetyGate = !_enableSafetyGate);
        _markSessionDirty(reason: 'toggle_safety', saveSoon: true);
      },
      onClearChatView: _clearChatViewOnly,
      onReloadAgents: _loadAgentProfiles,
      onEditActiveAgent: _showEditAgentDialog,
      onSelectAgent: _selectAgent,
      messages: _messages,
      messageBuilder: _buildMessageBubble,
      showDebug: _showDebug,
      debugLogs: _debugLogs,
      useHtmlContent: _useHtmlContent,
      onToggleContentMode: () {
        setState(() {
          _useHtmlContent = !_useHtmlContent;
          _syncAllAgentContexts();
        });
        _markSessionDirty(reason: 'toggle_content_mode', saveSoon: true);
      },
      inputController: _inputController,
      scrollController: _chatScrollController,
      slashCommands: _slashCommands,
      onSendMessage: _sendMessage,
      onCancelResponse: _cancelAiResponse,
    );
  }

  Widget _buildLeftPanel() {
    const tabs = <({int value, IconData icon, String label})>[
      (value: 0, icon: Icons.chat_bubble_outline, label: 'Chat'),
      (value: 1, icon: Icons.bookmark_outline, label: 'Bookmarks'),
      (value: 2, icon: Icons.timeline, label: 'Trace'),
      (value: 3, icon: Icons.build_outlined, label: 'Tools'),
      (value: 4, icon: Icons.extension_outlined, label: 'Skills'),
    ];

    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return ChoiceChip(
                avatar: Icon(tab.icon, size: 16),
                label: Text(tab.label),
                selected: _leftTabIndex == tab.value,
                onSelected: (_) {
                  setState(() {
                    _leftTabIndex = tab.value;
                  });
                  if (tab.value == 0) {
                    _ensureChatBottomAfterViewSwitch();
                  }
                  _markSessionDirty(reason: 'left_tab_change');
                },
              );
            },
          ),
        ),
        Expanded(
          child: _leftTabIndex == 0
              ? _buildChatPanel()
              : (_leftTabIndex == 1
                  ? _buildBookmarksPanel()
                  : (_leftTabIndex == 2
                      ? ToolTracePanel(traces: _toolTraces)
                      : (_leftTabIndex == 3
                          ? _buildToolsPanel()
                          : _buildSkillsPanel()))),
        ),
      ],
    );
  }

  Widget _buildBookmarksPanel() {
    return BookmarksPanel(
      searchController: _bookmarkSearchController,
      onSearchChanged: (_) => setState(() {}),
      tree: _bookmarks,
      linkCount: _bookmarkService.countLinks(_bookmarks),
      onOpenBookmark: _openBookmarkFromTree,
      onOpenBookmarkInNewTab: _openBookmarkInNewTabFromTree,
      onSetPinned: _setBookmarkPinned,
      onCreateFolder: (parentFolderId) {
        return _createFolder(parentFolderId: parentFolderId);
      },
      onRenameNode: _renameBookmarkNode,
      onDeleteNode: _deleteBookmarkNode,
      onMoveNode: _moveBookmarkNode,
      onImportJson: _importBookmarksJson,
      onImportHtml: _importBookmarksHtml,
      onExportJson: _exportBookmarksJson,
      onExportHtml: _exportBookmarksHtml,
      onClearAll: _clearAllBookmarks,
    );
  }

  Widget _buildToolsPanel() {
    return const ToolsPanel(tools: ToolRegistry.definitions);
  }

  Widget _buildSkillsPanel() {
    return SkillsPanel(
      skills: _skills,
      availableAuthProfileIds: _toolAuthProfiles.map((p) => p.id).toSet(),
      onToggle: (id, enabled) {
        _toggleSkill(id, enabled);
      },
      onCreateSkill: _showCreateSkillDialog,
      onEditSkill: _showEditSkillDialog,
      onDeleteSkill: _deleteSkillWithConfirm,
      onManageAuthProfiles: _showToolAuthProfilesManager,
      onReloadSkills: _loadSkills,
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return MessageBubble(message: msg);
  }

  Widget _buildBrowserPanel() {
    return BrowserPanel(
      tabs: _tabs,
      activeTabIndex: _activeTabIndex,
      activeController: _activeController,
      isWebViewReady: _isWebViewReady,
      urlController: _urlController,
      currentBookmarked: _bookmarkService.isBookmarked(_bookmarks, _currentUrl),
      onGoBack: () => _activeController?.goBack(),
      onGoForward: () => _activeController?.goForward(),
      onReload: () => _activeController?.reload(),
      onOpenGoogleAccountChooser: _openGoogleAccountChooser,
      onToggleBookmark: _toggleCurrentBookmark,
      onLoadUrl: _loadUrl,
      onNewTab: () =>
          _createTab(initialUrl: 'https://www.google.com', activate: true),
      onShowTabMenu: _showTabMenu,
      onSwitchTab: (index) {
        final tab = _tabs[index];
        setState(() {
          _activeTabIndex = index;
          _currentUrl = tab.url;
          _urlController.text = tab.url;
        });
        _syncAllAgentContexts();
      },
      onWebViewPointerDown: (event) {
        if (!_showDebug) return;
        final local = event.localPosition;
        final global = event.position;
        _log(
          'Flutter pointerdown: btn=${event.buttons}, local=(${local.dx.toStringAsFixed(1)},${local.dy.toStringAsFixed(1)}), global=(${global.dx.toStringAsFixed(1)},${global.dy.toStringAsFixed(1)}), url=$_currentUrl',
        );
      },
      onWebViewPointerUp: (event) {
        if (!_showDebug) return;
        final local = event.localPosition;
        final global = event.position;
        _log(
          'Flutter pointerup: btn=${event.buttons}, local=(${local.dx.toStringAsFixed(1)},${local.dy.toStringAsFixed(1)}), global=(${global.dx.toStringAsFixed(1)},${global.dy.toStringAsFixed(1)}), url=$_currentUrl',
        );
      },
    );
  }
}
