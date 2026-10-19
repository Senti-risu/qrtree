/// Display-only normalization. Database enum values and IDs stay unchanged.
String healthStatusLabel(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return switch (text.toLowerCase()) {
    'alive' || 'healthy' => 'Healthy',
    'dying' || 'at risk' || 'needs attention' => 'Needs Attention',
    'dead' || 'deceased' => 'Dead',
    '' => 'Unknown',
    _ => text,
  };
}
