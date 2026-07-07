// ignore_for_file: avoid_print

import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

class CloudFunctionsService {
  CloudFunctionsService._();
  static final CloudFunctionsService instance = CloudFunctionsService._();

  //! fucntion for the adding user reviews insight bi-monthly

  Future<void> assignUserRole() async {
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'addUserReviewsInsightsTry',
      );
      final results = await callable.call();
      print(results.data);
    } catch (e) {
      print('$e');
    }
  }

  //! send the email
  Future<bool> sendReportEmail({
    required String email,
    required String applicantName,
    required String pdfBase64,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'sendReportEmail',
      );
      final result = await callable.call(<String, dynamic>{
        'email': email,
        'applicantName': applicantName,
        'pdfBase64': pdfBase64,
      });

      print('✅ Email sent successfully: ${result.data}');
      return true;
    } catch (e) {
      print('❌ Failed to send email: $e');
      return false;
    }
  }

  //!check if the email already exists in the firebase

  Future<bool> checkEmailExists(String email) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'checkEmailExists',
      );
      final response = await callable.call(<String, dynamic>{'email': email});

      return response.data['exists'];
    } catch (error) {
      print('Error: $error');
      return false;
    }
  }

  //! payment intent for stripe payment
  Future<String> getPaymentIntent(double price) async {
    double priceToPurchase = 0;
    final String priceString = price.toString();
    if (priceString.contains(".99")) {
      priceToPurchase = (price + .01) * 100;
    } else {
      priceToPurchase = price * 100;
    }

    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
      'createPaymentIntent',
    );
    final results = await callable.call({"amount": priceToPurchase});
    return results.data["paymentIntent"];
  }

  Future<void> deleteUserAccount(String uid) async {
    try {
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUser',
      );
      final results = await callable.call({"uid": uid});
      Logger logger = Logger();
      logger.i("Delete user account ${results.data}");
    } catch (e) {
      Logger logger = Logger();
      logger.e("Error deleting user account : $e");
    }
  }
}
