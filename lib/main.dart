import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'agent_profile_service.dart';
import 'ai_service.dart';
import 'bookmark.dart';
import 'bookmark_service.dart';
import 'chat_controller.dart';
import 'chat_message.dart';
import 'context_manager.dart';
import 'models/browser_tab_state.dart';
import 'models/skill_definition.dart';
import 'models/tool_trace_entry.dart';
import 'services/session_snapshot_codec.dart';
import 'services/skill_service.dart';
import 'services/tool_executor.dart';
import 'services/tool_registry.dart';
import 'session_storage_service.dart';
import 'settings_service.dart';
import 'widgets/bookmarks_panel.dart';
import 'widgets/browser_panel.dart';
import 'widgets/chat_panel.dart';
import 'widgets/message_bubble.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/skills_panel.dart';
import 'widgets/tool_trace_panel.dart';
import 'widgets/tools_panel.dart';

part 'home/home_state_bookmarks.dart';
part 'home/home_state_bootstrap.dart';
part 'home/home_state_chat.dart';
part 'home/home_state_session.dart';
part 'home/home_state_tabs.dart';
part 'home/home_state_widgets.dart';

void main() {
  runApp(const MyApp());
}

String _popupPolicyLabel(WebviewPopupWindowPolicy policy) {
  switch (policy) {
    case WebviewPopupWindowPolicy.allow:
      return 'allow';
    case WebviewPopupWindowPolicy.deny:
      return 'deny';
    case WebviewPopupWindowPolicy.sameWindow:
      return 'sameWindow';
  }
}

IconData _popupPolicyIcon(WebviewPopupWindowPolicy policy) {
  switch (policy) {
    case WebviewPopupWindowPolicy.allow:
      return Icons.open_in_new;
    case WebviewPopupWindowPolicy.deny:
      return Icons.block;
    case WebviewPopupWindowPolicy.sameWindow:
      return Icons.web_asset;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HakoBrowseAI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _bookmarkSearchController =
      TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, ContextManager> _agentContexts = <String, ContextManager>{};
  final AgentProfileService _agentProfileService = AgentProfileService();
  final SkillService _skillService = SkillService();
  final BookmarkService _bookmarkService = BookmarkService();
  final SettingsService _settingsService = SettingsService();
  final SessionStorageService _sessionStorageService = SessionStorageService();
  final ChatController _chatFlow = ChatController();
  final List<String> _debugLogs = [];
  final List<ToolTraceEntry> _toolTraces = [];
  final List<BrowserTabState> _tabs = <BrowserTabState>[];

  AppSettings _settings = const AppSettings(
    provider: ApiProvider.anthropic,
    authMethod: AuthMethod.apiKey,
    experimentalSubscription: false,
    apiKey: '',
    oauthToken: '',
    baseUrl: 'https://api.z.ai/api/anthropic',
    model: 'glm-5',
    maxContentLength: 50000,
    chatMaxMessages: 300,
    leftPanelWidth: 400,
  );
  AiServiceConfig? _config;
  AiService? _aiService;
  AiCancelToken? _activeCancelToken;
  bool _isAiResponding = false;
  bool _isLoading = true;
  bool _showDebug = false;
  bool _isWebViewReady = false;
  bool _enableSafetyGate = true;
  bool _useHtmlContent = false;
  WebviewPopupWindowPolicy _popupWindowPolicy =
      WebviewPopupWindowPolicy.sameWindow;
  int _leftTabIndex = 0;
  int _activeTabIndex = 0;
  List<BookmarkNode> _bookmarks = <BookmarkNode>[];
  List<AgentProfile> _agentProfiles = <AgentProfile>[];
  List<SkillDefinition> _skills = <SkillDefinition>[];
  Set<String> _selectedAgentIds = <String>{};
  int _maxContentLength = 50000;
  int _chatMaxMessages = 300;
  double _leftPanelWidth = 400;
  String _currentUrl = 'https://www.google.com';
  Timer? _sessionSaveDebounce;
  Timer? _layoutSaveDebounce;
  bool _sessionDirty = false;
  bool _browserOnlyExperiment = false;

  WebviewController? get _activeController =>
      _tabs.isEmpty ? null : _tabs[_activeTabIndex].controller;

  AgentProfile? get _activeAgentProfile {
    for (final p in _agentProfiles) {
      if (_selectedAgentIds.contains(p.id)) return p;
    }
    return _agentProfiles.isEmpty ? null : _agentProfiles.first;
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _activeCancelToken?.cancel();
    _sessionSaveDebounce?.cancel();
    _layoutSaveDebounce?.cancel();
    unawaited(_saveSessionNow(force: true));
    _inputController.dispose();
    _urlController.dispose();
    _bookmarkSearchController.dispose();
    _chatScrollController.dispose();
    for (final tab in _tabs) {
      tab.urlSubscription?.cancel();
      tab.titleSubscription?.cancel();
      tab.webMessageSubscription?.cancel();
      tab.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_config == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.key,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text('Please set an API key'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.settings),
                label: const Text('API Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('HakoBrowseAI [${_config!.model}]'),
        actions: [
          PopupMenuButton<WebviewPopupWindowPolicy>(
            tooltip: 'Popup policy: ${_popupPolicyLabel(_popupWindowPolicy)}',
            icon: Icon(_popupPolicyIcon(_popupWindowPolicy)),
            onSelected: (policy) {
              unawaited(_setPopupWindowPolicy(policy));
            },
            itemBuilder: (context) =>
                WebviewPopupWindowPolicy.values.map((policy) {
              final selected = policy == _popupWindowPolicy;
              return PopupMenuItem<WebviewPopupWindowPolicy>(
                value: policy,
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(_popupPolicyLabel(policy)),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
          IconButton(
            icon: Icon(
              _browserOnlyExperiment
                  ? Icons.splitscreen_outlined
                  : Icons.web_outlined,
            ),
            tooltip: _browserOnlyExperiment
                ? 'Switch to split view'
                : 'Switch to browser-only view',
            onPressed: () {
              setState(() {
                _browserOnlyExperiment = !_browserOnlyExperiment;
              });
              _markSessionDirty();
            },
          ),
          IconButton(
            icon:
                Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setState(() => _showDebug = !_showDebug),
            tooltip: _showDebug ? 'Hide debug log' : 'Show debug log',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearConversation,
            tooltip: '会話をクリア',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _browserOnlyExperiment
          ? _buildBrowserPanel()
          : LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  SizedBox(
                    width: _leftPanelWidth.clamp(
                        280.0, constraints.maxWidth * 0.75),
                    child: _buildLeftPanel(),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        _onResizeLeftPanel(
                            details.delta.dx, constraints.maxWidth);
                      },
                      child: Container(
                        width: 6,
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withOpacity(0.25),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildBrowserPanel(),
                  ),
                ],
              ),
            ),
    );
  }
}
