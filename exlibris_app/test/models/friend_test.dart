import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/friend.dart';

void main() {
  group('Friend Model Tests', () {
    test('fromJson() should correctly parse JSON into a Friend object', () {
      final json = {
        'id': 1,
        'nom': 'Alice',
        'avatar_url': 'http://example.com/alice.png',
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 1);
      expect(friend.nom, 'Alice');
      expect(friend.avatarUrl, 'http://example.com/alice.png');
    });

    test('toJson() should properly serialize Friend to JSON', () {
      final friend = Friend(
        id: 2,
        nom: 'Bob',
        avatarUrl: 'http://example.com/bob.png',
      );

      final json = friend.toJson();

      expect(json['id'], 2);
      expect(json['nom'], 'Bob');
      expect(json['avatar_url'], 'http://example.com/bob.png');
    });

    test('toJson() should keep null avatarUrl if not provided', () {
      final friend = Friend(id: 3, nom: 'Charlie');
      final json = friend.toJson();

      expect(json['id'], 3);
      expect(json['nom'], 'Charlie');
      expect(json['avatar_url'], isNull);
    });
  });
}
