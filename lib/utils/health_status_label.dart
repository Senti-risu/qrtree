/// Display normalization for known health statuses; missing or unrecognized
/// health data is surfaced as Needs Attention.
String healthStatusLabel(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return switch (text.toLowerCase()) {
    'alive' || 'healthy' => 'Healthy',
    'dying' || 'at risk' || 'needs attention' => 'Needs Attention',
    'dead' || 'deceased' => 'Dead',
    _ => 'Needs Attention',
  };
}
