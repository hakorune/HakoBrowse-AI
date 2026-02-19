import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

class BrowserTabState {
  final String id;
  final WebviewController controller;
  final String title;
  final String url;
  StreamSubscription<String>? urlSubscription;
  StreamSubscription<String>? titleSubscription;
  StreamSubscription<dynamic>? webMessageSubscription;

  BrowserTabState({
    required this.id,
    required this.controller,
    required this.title,
    required this.url,
    this.urlSubscription,
    this.titleSubscription,
    this.webMessageSubscription,
  });

  BrowserTabState copyWith({
    String? id,
    WebviewController? controller,
    String? title,
    String? url,
    StreamSubscription<String>? urlSubscription,
    StreamSubscription<String>? titleSubscription,
    StreamSubscription<dynamic>? webMessageSubscription,
  }) {
    return BrowserTabState(
      id: id ?? this.id,
      controller: controller ?? this.controller,
      title: title ?? this.title,
      url: url ?? this.url,
      urlSubscription: urlSubscription ?? this.urlSubscription,
      titleSubscription: titleSubscription ?? this.titleSubscription,
      webMessageSubscription:
          webMessageSubscription ?? this.webMessageSubscription,
    );
  }
}
