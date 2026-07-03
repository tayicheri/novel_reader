import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../services/novel_extractor.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.chapter});

  final NovelChapter chapter;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _isDarkMode = false;
  ReaderFontSize _fontSize = ReaderFontSize.medium;

  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.chapter.sourceUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = _isDarkMode ? AppTheme.dark() : AppTheme.light();
    final bodyStyle = GoogleFonts.inter(
      fontSize: 16 * _fontSize.scale,
      height: 1.7,
      color: baseTheme.textTheme.bodyMedium?.color,
    );

    return Theme(
      data: baseTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.chapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: _isDarkMode ? 'Mode clair' : 'Mode sombre',
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: 'Ouvrir la source',
              onPressed: _openSource,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Taille',
                    style: baseTheme.textTheme.labelLarge,
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<ReaderFontSize>(
                    segments: ReaderFontSize.values
                        .map(
                          (size) => ButtonSegment(
                            value: size,
                            label: Text(size.label),
                          ),
                        )
                        .toList(),
                    selected: {_fontSize},
                    onSelectionChanged: (selection) {
                      setState(() => _fontSize = selection.first);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapter.title,
                        style: baseTheme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        widget.chapter.content,
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
