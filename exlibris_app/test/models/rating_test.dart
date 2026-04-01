import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/rating.dart';

void main() {
  group('Rating Model Tests', () {
    test('fromJson() should correctly parse JSON into a Rating object', () {
      final json = {
        'isbn': '987654321',
        'note': 5,
        'avis': 'Great book!',
      };

      final rating = Rating.fromJson(json);

      expect(rating.isbn, '987654321');
      expect(rating.note, 5);
      expect(rating.avis, 'Great book!');
    });

    test('toJson() should properly serialize Rating to JSON', () {
      final rating = Rating(
        isbn: '123456789',
        note: 4,
        avis: 'Good read',
      );

      final json = rating.toJson();

      expect(json['isbn'], '123456789');
      expect(json['note'], 4);
      expect(json['avis'], 'Good read');
    });

    test('fromJson() and toJson() should handle null avis', () {
      final json = {
        'isbn': '111222333',
        'note': 3,
        'avis': null,
      };

      final rating = Rating.fromJson(json);

      expect(rating.isbn, '111222333');
      expect(rating.note, 3);
      expect(rating.avis, isNull);

      final outJson = rating.toJson();
      expect(outJson['isbn'], '111222333');
      expect(outJson['note'], 3);
      expect(outJson['avis'], isNull);
    });
  });
}
