import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/book.dart'; // Using the package name from pubspec.yaml

void main() {
  group('Book Model Tests', () {
    test('fromJson() should correctly parse JSON into a Book object', () {
      final json = {
        'isbn': '1234567890',
        'titre': 'Test Title',
        'auteur': 'Test Author',
        'categorie': 'Fiction',
        'image_petite': 'http://example.com/image.jpg',
        'resume': 'A summary',
        'editeur': 'Test Publisher',
        'langue': 'French',
      };

      final book = Book.fromJson(json);

      expect(book.isbn, '1234567890');
      expect(book.titre, 'Test Title');
      expect(book.auteur, 'Test Author');
      expect(book.categorie, 'Fiction');
      expect(book.imagePetite, 'http://example.com/image.jpg');
      expect(book.resume, 'A summary');
      expect(book.editeur, 'Test Publisher');
      expect(book.langue, 'French');
    });

    test('toJson() should properly serialize Book to JSON', () {
      final book = Book(
        isbn: '1234567890',
        titre: 'Test Title',
        auteur: 'Test Author',
        categorie: 'Fiction',
        imagePetite: 'http://example.com/image.jpg',
        resume: 'A summary',
        editeur: 'Test Publisher',
        langue: 'French',
      );

      final json = book.toJson();

      expect(json['isbn'], '1234567890');
      expect(json['titre'], 'Test Title');
      expect(json['auteur'], 'Test Author');
      expect(json['categorie'], 'Fiction');
      expect(json['image_petite'], 'http://example.com/image.jpg');
      expect(json['resume'], 'A summary');
      expect(json['editeur'], 'Test Publisher');
      expect(json['langue'], 'French');
    });

    test('Equality operator (==) should return true for books with the same isbn', () {
      final book1 = Book(isbn: '111', titre: 'A', auteur: 'B');
      final book2 = Book(isbn: '111', titre: 'A', auteur: 'B');
      final book3 = Book(isbn: '222', titre: 'A', auteur: 'B');

      expect(book1 == book2, true);
      expect(book1 == book3, false);
    });

    test('hashCode should evaluate to isbn.hashCode', () {
      final book = Book(isbn: '123', titre: 'Titre', auteur: 'Auteur');
      expect(book.hashCode, '123'.hashCode);
    });
  });
}
