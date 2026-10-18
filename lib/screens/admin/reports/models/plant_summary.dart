class PlantSummary {
  final String name;
  final int total;
  final int alive;
  final int dying;
  final int dead;

  const PlantSummary({
    required this.name,
    required this.total,
    required this.alive,
    required this.dying,
    required this.dead,
  });

  List<String> toRow() => [name, '$total', '$alive', '$dying', '$dead'];
}
