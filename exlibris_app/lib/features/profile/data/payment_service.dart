import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/env.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  final String stripeSecretKey = Env.stripeSecretKey;

  Future<String?> createPaymentIntent(int amount, String currency) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'amount': amount.toString(), 'currency': currency},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['client_secret'];
      } else {
        return null;
      }
    } catch (e) {
      print('Erreur createPaymentIntent: $e');
      return null;
    }
  }

  Future<bool> makePayment(int amount, String currency) async {
    try {
      final clientSecret = await createPaymentIntent(amount, currency);

      if (clientSecret == null) {
        return false;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'ExLibris',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeConfigException catch (e) {
      print('Erreur makePayment: ${e.message}');
      print(e.hashCode);
      return false;
    } catch (e) {
      print('Erreur makePayment: $e');
      return false;
    }
  }
}
