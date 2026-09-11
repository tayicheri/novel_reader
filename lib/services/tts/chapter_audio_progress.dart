/// Progression chapitre pour Kokoro : durée estimée puis réelle, + % de texte TTS.
class ChapterAudioProgress {
  /// Débit parole « lambda » : ~14 caractères par seconde.
  static const double charsPerSecond = 14;

  static Duration estimateDuration(String text) {
    final chars = text.trim().length;
    if (chars == 0) return Duration.zero;
    return Duration(milliseconds: (chars / charsPerSecond * 1000).round());
  }

  static double synthesizedTextFraction({
    required List<String> chunks,
    required int completedChunks,
  }) {
    if (chunks.isEmpty) return 0;
    final total = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    if (total == 0) return 0;
    final doneCount = completedChunks.clamp(0, chunks.length);
    final done = chunks
        .take(doneCount)
        .fold<int>(0, (sum, chunk) => sum + chunk.length);
    return (done / total).clamp(0.0, 1.0);
  }

  static Duration playlistPosition({
    required int currentIndex,
    required List<Duration> itemDurations,
    required Duration itemPosition,
  }) {
    var total = Duration.zero;
    for (var i = 0; i < currentIndex && i < itemDurations.length; i++) {
      total += itemDurations[i];
    }
    return total + itemPosition;
  }

  static Duration loadedDuration(List<Duration> itemDurations) {
    return itemDurations.fold(Duration.zero, (sum, item) => sum + item);
  }

  static ({int index, Duration position}) mapPlaylistSeek({
    required Duration requested,
    required List<Duration> itemDurations,
  }) {
    if (itemDurations.isEmpty) {
      return (index: 0, position: Duration.zero);
    }
    var remaining = requested < Duration.zero ? Duration.zero : requested;
    for (var i = 0; i < itemDurations.length; i++) {
      final item = itemDurations[i];
      final isLast = i == itemDurations.length - 1;
      if (remaining <= item || isLast) {
        final position = remaining > item ? item : remaining;
        return (index: i, position: position);
      }
      remaining -= item;
    }
    return (
      index: itemDurations.length - 1,
      position: itemDurations.last,
    );
  }
}
