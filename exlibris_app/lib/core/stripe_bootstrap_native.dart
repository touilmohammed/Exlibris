import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> initializeStripe(String publishableKey) async {
  Stripe.publishableKey = publishableKey;
}
