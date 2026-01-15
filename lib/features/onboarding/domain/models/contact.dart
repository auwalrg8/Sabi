class Contact {
  final String name;
  final String phone;
  final bool isNostr;

  const Contact({
    required this.name,
    required this.phone,
    this.isNostr = false,
  });

  Contact copyWith({String? name, String? phone, bool? isNostr}) {
    return Contact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isNostr: isNostr ?? this.isNostr,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact &&
        other.name == name &&
        other.phone == phone &&
        other.isNostr == isNostr;
  }

  @override
  int get hashCode => name.hashCode ^ phone.hashCode ^ isNostr.hashCode;
}
