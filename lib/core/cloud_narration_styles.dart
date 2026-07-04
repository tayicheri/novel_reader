enum CloudNarrationStyle {
  audiobook,
  neutral,
  dramatic,
}

class CloudNarrationStyleOption {
  const CloudNarrationStyleOption({
    required this.style,
    required this.label,
  });

  final CloudNarrationStyle style;
  final String label;
}

const cloudNarrationStyleOptions = <CloudNarrationStyleOption>[
  CloudNarrationStyleOption(style: CloudNarrationStyle.audiobook, label: 'Audiobook'),
  CloudNarrationStyleOption(style: CloudNarrationStyle.neutral, label: 'Neutre'),
  CloudNarrationStyleOption(style: CloudNarrationStyle.dramatic, label: 'Dramatique'),
];

const defaultCloudNarrationStyle = CloudNarrationStyle.audiobook;

CloudNarrationStyle normalizeCloudNarrationStyle(String? value) {
  if (value == null || value.trim().isEmpty) {
    return defaultCloudNarrationStyle;
  }
  try {
    return CloudNarrationStyle.values.byName(value.trim());
  } catch (_) {
    return defaultCloudNarrationStyle;
  }
}
