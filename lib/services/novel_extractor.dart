import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class NovelChapter {
  const NovelChapter({
    required this.title,
    required this.content,
    required this.sourceUrl,
  });

  final String title;
  final String content;
  final String sourceUrl;
}

class NovelExtractionException implements Exception {
  NovelExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NovelExtractorService {
  Future<NovelChapter> extract(String rawUrl) async {
    final url = _normalizeUrl(rawUrl);
    final response = await http.get(
      url,
      headers: {'User-Agent': AppConstants.mobileUserAgent},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NovelExtractionException(
        'Impossible de charger la page (code ${response.statusCode}).',
      );
    }

    final document = html_parser.parse(response.body);
    final title = _extractTitle(document) ?? 'Sans titre';
    final content = _extractContent(document);

    if (content.trim().length < 80) {
      throw NovelExtractionException(
        'Contenu introuvable ou trop court. Le site peut nécessiter JavaScript.',
      );
    }

    return NovelChapter(
      title: title.trim(),
      content: content.trim(),
      sourceUrl: url.toString(),
    );
  }

  Uri _normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw NovelExtractionException('Veuillez saisir une URL.');
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw NovelExtractionException('URL invalide.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw NovelExtractionException('Seules les URLs http/https sont supportées.');
    }
    return uri;
  }

  String? _extractTitle(dom.Document document) {
    final ogTitle = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (ogTitle != null && ogTitle.trim().isNotEmpty) {
      return ogTitle;
    }

    final h1 = document.querySelector('h1')?.text;
    if (h1 != null && h1.trim().isNotEmpty) {
      return h1;
    }

    final title = document.querySelector('title')?.text;
    if (title != null && title.trim().isNotEmpty) {
      return title;
    }

    return null;
  }

  String _extractContent(dom.Document document) {
    _removeNoise(document);

    const selectors = [
      'article',
      '[class*="chapter-content"]',
      '[class*="chapter_content"]',
      '[id*="chapter-content"]',
      '[class*="chapter"]',
      '[id*="chapter"]',
      '.entry-content',
      '.post-content',
      '.article-content',
      '.reading-content',
      '.text-content',
      '#content',
      '#main-content',
      'main',
      '[role="main"]',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final text = _textFromElement(element);
        if (text.length >= 120) {
          return text;
        }
      }
    }

    return _bestParagraphBlock(document);
  }

  void _removeNoise(dom.Document document) {
    const noiseSelectors = [
      'script',
      'style',
      'noscript',
      'nav',
      'footer',
      'header',
      'aside',
      '.sidebar',
      '.comments',
      '.comment',
      '.advertisement',
      '.ad',
      '[class*="cookie"]',
    ];

    for (final selector in noiseSelectors) {
      for (final node in document.querySelectorAll(selector)) {
        node.remove();
      }
    }
  }

  String _textFromElement(dom.Element element) {
    final paragraphs = element.querySelectorAll('p');
    if (paragraphs.isNotEmpty) {
      final joined = paragraphs
          .map((p) => _cleanText(p.text))
          .where((text) => text.length > 20)
          .join('\n\n');
      if (joined.length >= 80) {
        return joined;
      }
    }

    return _cleanText(element.text);
  }

  String _bestParagraphBlock(dom.Document document) {
    final candidates = <dom.Element>[
      ...document.querySelectorAll('div'),
      ...document.querySelectorAll('section'),
    ];

    var bestText = '';
    for (final candidate in candidates) {
      final text = _textFromElement(candidate);
      if (text.length > bestText.length) {
        bestText = text;
      }
    }

    if (bestText.length >= 80) {
      return bestText;
    }

    final fallback = document.querySelectorAll('p').map((p) => _cleanText(p.text));
    return fallback.where((text) => text.length > 20).join('\n\n');
  }

  String _cleanText(String input) {
    return input
        .replaceAll(RegExp(r'[\t\r]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }
}
