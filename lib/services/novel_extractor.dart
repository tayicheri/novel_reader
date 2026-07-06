import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/cloudflare_detector.dart';
import '../core/constants.dart';
import '../core/novel_extraction_exception.dart';
import 'web_chapter_fetcher.dart';

export '../core/novel_extraction_exception.dart';

class NovelChapter {
  const NovelChapter({
    required this.title,
    required this.content,
    required this.sourceUrl,
    this.previousUrl,
    this.nextUrl,
  });

  final String title;
  final String content;
  final String sourceUrl;
  final String? previousUrl;
  final String? nextUrl;
}

class ChapterNavigation {
  const ChapterNavigation({this.previousUrl, this.nextUrl});

  final String? previousUrl;
  final String? nextUrl;
}

class ChapterNavigationParser {
  static final RegExp _nextText = RegExp(
    r'\b(next|suivant|suivante|chapitre\s+suivant|épisode\s+suivant|episode\s+next)\b',
    caseSensitive: false,
  );
  static final RegExp _prevText = RegExp(
    r'\b(prev(ious)?|précédent|précédente|precedent|chapitre\s+précédent|chapitre\s+precedent|épisode\s+précédent)\b',
    caseSensitive: false,
  );
  static final RegExp _nextClass = RegExp(r'next', caseSensitive: false);
  static final RegExp _prevClass = RegExp(r'prev', caseSensitive: false);

  ChapterNavigation parse(dom.Document document, Uri currentUrl) {
    String? previous;
    String? next;

    void assign({String? prev, String? nxt}) {
      if (prev != null && previous == null) previous = prev;
      if (nxt != null && next == null) next = nxt;
    }

    for (final link in document.querySelectorAll('link[rel]')) {
      final rel = link.attributes['rel']?.toLowerCase() ?? '';
      final href = link.attributes['href'];
      if (href == null || href.isEmpty) continue;
      if (rel.contains('prev')) {
        assign(prev: _resolveUrl(currentUrl, href));
      } else if (rel.contains('next')) {
        assign(nxt: _resolveUrl(currentUrl, href));
      }
    }

    for (final anchor in document.querySelectorAll('a[rel]')) {
      final rel = anchor.attributes['rel']?.toLowerCase() ?? '';
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      if (rel.contains('prev')) {
        assign(prev: _resolveUrl(currentUrl, href));
      } else if (rel.contains('next')) {
        assign(nxt: _resolveUrl(currentUrl, href));
      }
    }

    const cssSelectors = [
      '.next-chapter a',
      '.prev-chapter a',
      '.nav-next a',
      '.nav-previous a',
      '.nav-next',
      '.nav-previous',
      '.next-chapter',
      '.prev-chapter',
      '#next a',
      '#prev a',
      '#next',
      '#prev',
    ];

    for (final selector in cssSelectors) {
      final element = document.querySelector(selector);
      if (element == null) continue;
      final href = element.attributes['href'] ??
          element.querySelector('a')?.attributes['href'];
      if (href == null || href.isEmpty) continue;

      final className =
          '${element.className} ${element.id} $selector'.toLowerCase();
      if (_nextClass.hasMatch(className) && !_prevClass.hasMatch(className)) {
        assign(nxt: _resolveUrl(currentUrl, href));
      } else if (_prevClass.hasMatch(className) &&
          !_nextClass.hasMatch(className)) {
        assign(prev: _resolveUrl(currentUrl, href));
      }
    }

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;

      final text = anchor.text.trim();
      final className = '${anchor.className} ${anchor.id}'.toLowerCase();

      if (_nextText.hasMatch(text) || _matchesNextClass(className)) {
        assign(nxt: _resolveUrl(currentUrl, href));
      }
      if (_prevText.hasMatch(text) || _matchesPrevClass(className)) {
        assign(prev: _resolveUrl(currentUrl, href));
      }
    }

    previous = _filterUrl(previous, currentUrl);
    next = _filterUrl(next, currentUrl);

    return ChapterNavigation(previousUrl: previous, nextUrl: next);
  }

  bool _matchesNextClass(String className) {
    return _nextClass.hasMatch(className) && !_prevClass.hasMatch(className);
  }

  bool _matchesPrevClass(String className) {
    return _prevClass.hasMatch(className) && !_nextClass.hasMatch(className);
  }

  String? _resolveUrl(Uri currentUrl, String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('javascript:')) {
      return null;
    }

    final resolved = currentUrl.resolve(trimmed);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') {
      return null;
    }
    return resolved.toString();
  }

  String? _filterUrl(String? url, Uri currentUrl) {
    if (url == null) return null;
    if (url == currentUrl.toString()) return null;

    final parsed = Uri.tryParse(url);
    if (parsed == null) return null;
    if (parsed.host != currentUrl.host) return null;

    return url;
  }
}

Uri normalizeNovelUrl(String rawUrl) {
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

class NovelExtractorService {
  final ChapterNavigationParser _navigationParser = ChapterNavigationParser();

  Future<NovelChapter> extract(String rawUrl) async {
    final url = normalizeNovelUrl(rawUrl);
    final html = await _fetchPageHtml(url);
    return _parseChapter(url, html);
  }

  Future<String> _fetchPageHtml(Uri url) async {
    final response = await http.get(
      url,
      headers: AppConstants.novelPageRequestHeaders,
    );

    final isCloudflare = isCloudflareChallengePage(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        !isCloudflare) {
      return response.body;
    }

    if (isCloudflare || response.statusCode == 403) {
      return WebChapterFetcher.fetchHtml(url);
    }

    throw NovelExtractionException(
      'Impossible de charger la page (code ${response.statusCode}).',
    );
  }

  NovelChapter _parseChapter(Uri url, String html) {
    final document = html_parser.parse(html);
    final title = _extractTitle(document) ?? 'Sans titre';
    final content = _extractContent(document);

    if (content.trim().length < 80) {
      throw NovelExtractionException(
        'Contenu introuvable ou trop court. Le site peut nécessiter JavaScript.',
      );
    }

    final navigation = _navigationParser.parse(document, url);

    return NovelChapter(
      title: title.trim(),
      content: content.trim(),
      sourceUrl: url.toString(),
      previousUrl: navigation.previousUrl,
      nextUrl: navigation.nextUrl,
    );
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
