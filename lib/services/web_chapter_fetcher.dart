import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/cloudflare_detector.dart';
import '../core/constants.dart';
import '../core/novel_extraction_exception.dart';

bool get _supportsHeadlessWebView {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

class WebChapterFetcher {
  static const _pollInterval = Duration(milliseconds: 500);
  static const _timeout = Duration(seconds: 45);

  static Future<String> fetchHtml(Uri url) async {
    if (!_supportsHeadlessWebView) {
      throw NovelExtractionException(
        'Ce site est protégé par Cloudflare. WebView indisponible sur cette plateforme.',
      );
    }

    HeadlessInAppWebView? headless;
    InAppWebViewController? controller;
    final ready = Completer<void>();

    headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(url.toString()),
        headers: AppConstants.novelPageRequestHeaders,
      ),
      initialSettings: InAppWebViewSettings(
        userAgent: AppConstants.browserUserAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onWebViewCreated: (c) => controller = c,
      onLoadStop: (c, _) async {
        if (ready.isCompleted) return;
        try {
          await _waitForRealContent(c);
          ready.complete();
        } catch (error) {
          if (!ready.isCompleted) ready.completeError(error);
        }
      },
      onReceivedError: (c, request, error) {
        if (request.isForMainFrame != true) return;
        if (!ready.isCompleted) {
          ready.completeError(
            NovelExtractionException('Erreur WebView: ${error.description}'),
          );
        }
      },
    );

    try {
      await headless.run();
      await ready.future.timeout(
        _timeout,
        onTimeout: () => throw NovelExtractionException(
          'Délai dépassé en attendant la page (Cloudflare).',
        ),
      );

      final html = await controller?.getHtml();
      final stillCloudflare =
          html == null || html.isEmpty || isCloudflareChallengePage(html);

      if (html == null || html.isEmpty) {
        throw NovelExtractionException('Page vide après chargement WebView.');
      }
      if (stillCloudflare) {
        throw NovelExtractionException(
          'Cloudflare n\'a pas pu être contourné. Réessayez dans quelques instants.',
        );
      }
      return html;
    } finally {
      await headless.dispose();
    }
  }

  static Future<void> _waitForRealContent(InAppWebViewController controller) async {
    final deadline = DateTime.now().add(_timeout);
    while (DateTime.now().isBefore(deadline)) {
      final title = await controller.getTitle() ?? '';
      final html = await controller.getHtml() ?? '';
      if (!isCloudflareChallengePage(html) &&
          !title.toLowerCase().contains('just a moment') &&
          html.length > 3000) {
        return;
      }
      await Future<void>.delayed(_pollInterval);
    }
    throw NovelExtractionException(
      'Délai dépassé en attendant la fin du challenge Cloudflare.',
    );
  }
}
