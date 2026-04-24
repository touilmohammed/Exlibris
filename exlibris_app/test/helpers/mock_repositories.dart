import 'package:flutter_application_1/features/auth/data/auth_repository.dart';
import 'package:flutter_application_1/features/books/data/books_repository.dart';
import 'package:flutter_application_1/features/exchanges/data/exchanges_repository.dart';
import 'package:flutter_application_1/features/friends/data/friends_repository.dart';
import 'package:flutter_application_1/features/profile/data/profile_repository.dart';
import 'package:flutter_application_1/features/ratings/data/ratings_repository.dart';
import 'package:flutter_application_1/features/wishlist/data/wishlist_repository.dart';
import 'package:flutter_application_1/features/profile/domain/user_profile.dart';
import 'package:flutter_application_1/models/book.dart';
import 'package:flutter_application_1/models/friend.dart';
import 'package:flutter_application_1/models/exchange.dart';
import 'package:flutter_application_1/models/rating.dart';

class FakeAuthRepository implements AuthRepository {
  bool signInCalled = false;
  bool signUpCalled = false;
  String? usedEmail;
  String? usedPassword;
  String? usedUsername;
  bool shouldThrowError = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalled = true;
    usedEmail = email;
    usedPassword = password;
    if (shouldThrowError) throw Exception('401 Unauthorized');
  }

  @override
  Future<void> signUp({
    required String email,
    required String username,
    required String password,
  }) async {
    signUpCalled = true;
    usedEmail = email;
    usedUsername = username;
    usedPassword = password;
    if (shouldThrowError) throw Exception('409 Conflict');
  }

  @override
  Future<void> confirmEmail({required String token}) async {}

  @override
  Future<void> signOut() async {}
}

class FakeBooksRepository implements BooksRepository {
  List<Book> collection = [];

  @override
  Future<List<Book>> getCollection() async => collection;

  @override
  Future<List<Book>> getRecommendations() async => [];

  @override
  Future<List<Book>> searchBooks({
    String? query,
    String? auteur,
    String? isbn,
  }) async => [];

  @override
  Future<void> addToCollection(String isbn) async {}

  @override
  Future<void> removeFromCollection(String isbn) async {}
}

class FakeWishlistRepository implements WishlistRepository {
  List<Book> wishlist = [];

  @override
  Future<List<Book>> getWishlist() async => wishlist;

  @override
  Future<void> add(String isbn) async {}

  @override
  Future<void> remove(String isbn) async {}
}

class FakeFriendsRepository implements FriendsRepository {
  List<Friend> friends = [];

  @override
  Future<List<Friend>> getFriends() async => friends;

  @override
  Future<List<Friend>> getIncomingRequests() async => [];

  @override
  Future<List<Friend>> getOutgoingRequests() async => [];

  @override
  Future<void> acceptRequest(int friendId) async {}

  @override
  Future<void> refuseRequest(int friendId) async {}

  @override
  Future<void> removeFriend(int friendId) async {}

  @override
  Future<List<Friend>> search(String q) async => [];

  @override
  Future<void> sendRequest(int friendId) async {}
}

class FakeExchangesRepository implements ExchangesRepository {
  @override
  Future<Exchange> createExchange({
    required int destinataireId,
    required String livreDemandeurIsbn,
    required String livreDestinataireIsbn,
  }) async {
    return Exchange(
      id: 999,
      expediteurId: 1,
      destinataireId: destinataireId,
      livreDemandeurIsbn: livreDemandeurIsbn,
      livreDestinataireIsbn: livreDestinataireIsbn,
      statut: 'demande_envoyee',
      dateEchange: DateTime.now(),
    );
  }

  @override
  Future<List<Exchange>> getMyExchanges() async => [];

  @override
  Future<List<Book>> getFriendCollection(int friendId) async => [];

  @override
  Future<void> acceptExchange(int id) async {}

  @override
  Future<void> refuseExchange(int id) async {}

  @override
  Future<void> cancelExchange(int id) async {}
}

class FakeProfileRepository implements ProfileRepository {
  bool updateCalled = false;

  @override
  Future<UserProfile> getMyProfile() async =>
      UserProfile(id: 1, nomUtilisateur: 'TestUser', email: 'test@test.com');

  @override
  Future<void> updateProfile({
    String? nomUtilisateur,
    String? email,
    String? motDePasse,
    int? age,
    String? sexe,
    String? pays,
  }) async {
    updateCalled = true;
  }
}

class FakeRatingsRepository implements RatingsRepository {
  @override
  Future<List<Rating>> getMyRatings({String? isbn}) async => [];

  @override
  Future<void> addOrUpdateRating({
    required String isbn,
    required int note,
    String? avis,
  }) async {}

  @override
  Future<Rating?> getMyRatingFor(String isbn) async => null;

  @override
  Future<void> saveRating({
    required String isbn,
    required int note,
    String? avis,
  }) async {}
}
