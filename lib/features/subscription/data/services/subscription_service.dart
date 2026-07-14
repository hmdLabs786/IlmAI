import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  final FirebaseFirestore _db;

  SubscriptionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> activateFreeTier(String uid) async {
    await _db.collection('users').doc(uid).set({
      'subscriptionTier': 'Free',
      'subscriptionActivatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logPremiumGatewayTrigger({
    required String uid,
    required String tierId,
  }) async {
    // Placeholder for EasyPaisa/JazzCash integration hooks.
    // Swap this log with the real payment workflow when the PSP is ready.
    debugPrint('Trigger EasyPaisa/JazzCash Payment Gateway Workflow');
    await _db.collection('payment_events').add({
      'uid': uid,
      'tierId': tierId,
      'message': 'Trigger EasyPaisa/JazzCash Payment Gateway Workflow',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
