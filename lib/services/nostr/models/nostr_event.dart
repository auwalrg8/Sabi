/// Nostr Event Model
/// Represents any Nostr event (kind 0, 1, 3, 9734, 9735, 30402, etc.)
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;
  final String? relayUrl;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
    this.relayUrl,
  });

  factory NostrEvent.fromJson(Map<String, dynamic> json, {String? relay}) {
    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final tags =
        rawTags.map<List<String>>((tag) {
          if (tag is List) {
            return tag.map((e) => e.toString()).toList();
          }
          return <String>[];
        }).toList();

    return NostrEvent(
      id: json['id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      kind: json['kind'] as int? ?? 0,
      tags: tags,
      content: json['content'] as String? ?? '',
      sig: json['sig'] as String? ?? '',
      relayUrl: relay,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': sig,
    };
  }

  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  /// Get first tag value by tag name
  String? getTagValue(String tagName) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  /// Get all tag values by tag name
  List<String> getTagValues(String tagName) {
    final values = <String>[];
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName && tag.length > 1) {
        values.add(tag[1]);
      }
    }
    return values;
  }

  /// Check if this is a reply to another event
  bool get isReply => getTagValue('e') != null;

  /// Get event ID this is replying to
  String? get replyToEventId => getTagValue('e');

  /// Get mentioned pubkeys
  List<String> get mentionedPubkeys => getTagValues('p');

  @override
  String toString() =>
      'NostrEvent(id: $id, kind: $kind, pubkey: ${pubkey.substring(0, 8)}...)';
}
