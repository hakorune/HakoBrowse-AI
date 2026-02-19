import '../chat_message.dart';
import '../context_manager.dart';
import '../models/tool_trace_entry.dart';

class SessionSnapshotData {
  final List<ChatMessage> messages;
  final List<ToolTraceEntry> toolTraces;
  final Map<String, Map<String, dynamic>> agentContexts;
  final Set<String> selectedAgentIds;
  final int leftTabIndex;
  final bool showDebug;
  final bool useHtmlContent;
  final bool enableSafetyGate;
  final String currentUrl;
  final String popupPolicy;
  final bool browserOnlyExperiment;

  const SessionSnapshotData({
    required this.messages,
    required this.toolTraces,
    required this.agentContexts,
    required this.selectedAgentIds,
    required this.leftTabIndex,
    required this.showDebug,
    required this.useHtmlContent,
    required this.enableSafetyGate,
    required this.currentUrl,
    required this.popupPolicy,
    required this.browserOnlyExperiment,
  });
}

class SessionSnapshotCodec {
  static Map<String, dynamic> encode({
    required List<ChatMessage> messages,
    required List<ToolTraceEntry> toolTraces,
    required Map<String, ContextManager> agentContexts,
    required Set<String> selectedAgentIds,
    required int leftTabIndex,
    required bool showDebug,
    required bool useHtmlContent,
    required bool enableSafetyGate,
    required String currentUrl,
    required String popupPolicy,
    required bool browserOnlyExperiment,
  }) {
    return {
      'version': 1,
      'saved_at': DateTime.now().toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'tool_traces': toolTraces.map((t) => t.toJson()).toList(),
      'agent_contexts':
          agentContexts.map((key, value) => MapEntry(key, value.toJson())),
      'selected_agent_ids': selectedAgentIds.toList(),
      'left_tab_index': leftTabIndex,
      'show_debug': showDebug,
      'use_html_content': useHtmlContent,
      'enable_safety_gate': enableSafetyGate,
      'current_url': currentUrl,
      'popup_policy': popupPolicy,
      'browser_only_experiment': browserOnlyExperiment,
    };
  }

  static SessionSnapshotData decode(Map<String, dynamic> snapshot) {
    final messages = <ChatMessage>[];
    final rawMessages = snapshot['messages'];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map) {
          messages.add(ChatMessage.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }

    final traces = <ToolTraceEntry>[];
    final rawTraces = snapshot['tool_traces'];
    if (rawTraces is List) {
      for (final item in rawTraces) {
        if (item is Map) {
          traces.add(ToolTraceEntry.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }

    final agentContexts = <String, Map<String, dynamic>>{};
    final contextsRaw = snapshot['agent_contexts'];
    if (contextsRaw is Map) {
      contextsRaw.forEach((k, v) {
        if (v is Map) {
          agentContexts[k.toString()] =
              v.map((kk, vv) => MapEntry(kk.toString(), vv));
        }
      });
    }

    final selected = <String>{};
    final rawSelected = snapshot['selected_agent_ids'];
    if (rawSelected is List) {
      for (final item in rawSelected) {
        final id = item.toString();
        if (id.isNotEmpty) selected.add(id);
      }
    }

    return SessionSnapshotData(
      messages: messages,
      toolTraces: traces,
      agentContexts: agentContexts,
      selectedAgentIds: selected,
      leftTabIndex: (snapshot['left_tab_index'] as num?)?.toInt() ?? 0,
      showDebug: snapshot['show_debug'] == true,
      useHtmlContent: snapshot['use_html_content'] == true,
      enableSafetyGate: snapshot['enable_safety_gate'] == null
          ? true
          : snapshot['enable_safety_gate'] == true,
      currentUrl: snapshot['current_url']?.toString() ?? '',
      popupPolicy: snapshot['popup_policy']?.toString() ?? 'sameWindow',
      browserOnlyExperiment: snapshot['browser_only_experiment'] == true,
    );
  }
}
