import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:tayi_whisper/services/novel_extractor.dart';

void main() {
  final parser = ChapterNavigationParser();
  final currentUrl = Uri.parse('https://exemple.com/novel/chapitre-5');

  group('ChapterNavigationParser', () {
    test('détecte link rel prev et next', () {
      final document = html_parser.parse('''
        <html>
          <head>
            <link rel="prev" href="/novel/chapitre-4">
            <link rel="next" href="/novel/chapitre-6">
          </head>
        </html>
      ''');

      final navigation = parser.parse(document, currentUrl);

      expect(navigation.previousUrl, 'https://exemple.com/novel/chapitre-4');
      expect(navigation.nextUrl, 'https://exemple.com/novel/chapitre-6');
    });

    test('détecte les classes CSS courantes', () {
      final document = html_parser.parse('''
        <html>
          <body>
            <a class="prev-chapter" href="/novel/chapitre-4">Précédent</a>
            <a class="next-chapter" href="/novel/chapitre-6">Suivant</a>
          </body>
        </html>
      ''');

      final navigation = parser.parse(document, currentUrl);

      expect(navigation.previousUrl, 'https://exemple.com/novel/chapitre-4');
      expect(navigation.nextUrl, 'https://exemple.com/novel/chapitre-6');
    });

    test('détecte les liens par texte FR et EN', () {
      final document = html_parser.parse('''
        <html>
          <body>
            <a href="/novel/chapitre-4">Chapitre précédent</a>
            <a href="/novel/chapitre-6">Next Chapter</a>
          </body>
        </html>
      ''');

      final navigation = parser.parse(document, currentUrl);

      expect(navigation.previousUrl, 'https://exemple.com/novel/chapitre-4');
      expect(navigation.nextUrl, 'https://exemple.com/novel/chapitre-6');
    });

    test('ignore les URLs externes et identiques', () {
      final document = html_parser.parse('''
        <html>
          <body>
            <a href="https://autre.com/chapitre-4">Précédent</a>
            <a href="/novel/chapitre-5">Suivant</a>
          </body>
        </html>
      ''');

      final navigation = parser.parse(document, currentUrl);

      expect(navigation.previousUrl, isNull);
      expect(navigation.nextUrl, isNull);
    });
  });
}
