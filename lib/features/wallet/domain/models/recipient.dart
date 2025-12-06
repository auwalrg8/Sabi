class Recipient {
  final String name;
  final String identifier;
  final String? mutuals;
  final RecipientType type;

  const Recipient({
    required this.name,
    required this.identifier,
    this.mutuals,
    required this.type,
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

enum RecipientType {
  sabiName,
  phone,
  npub,
  lnAddress,
  lightning, // bolt11, LNURL, etc.
}
