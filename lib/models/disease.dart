class Disease {
  final String id;
  final String name;
  final String nameMarathi;
  final String nameHindi;
  final String description;
  final String descriptionMarathi;
  final String descriptionHindi;
  final List<String> causes;
  final List<String> causesMarathi;
  final List<String> symptoms;
  final List<String> symptomsMarathi;
  final List<String> treatments;
  final List<String> treatmentsMarathi;
  final List<String> prevention;
  final List<String> preventionMarathi;
  final String severity;
  final String affectedCrops;

  const Disease({
    required this.id,
    required this.name,
    required this.nameMarathi,
    required this.nameHindi,
    required this.description,
    required this.descriptionMarathi,
    required this.descriptionHindi,
    required this.causes,
    required this.causesMarathi,
    required this.symptoms,
    required this.symptomsMarathi,
    required this.treatments,
    required this.treatmentsMarathi,
    required this.prevention,
    required this.preventionMarathi,
    required this.severity,
    required this.affectedCrops,
  });
}
