import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/student_profile.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  StudentProfile? _profile;
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

  AuthProvider() {
    _init();
  }

  User? get user => _user;
  StudentProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  void _init() {
    _authSubscription = _auth.authStateChanges().listen((User? firebaseUser) async {
      _user = firebaseUser;
      if (firebaseUser != null) {
        await _fetchProfile(firebaseUser.uid);
      } else {
        _profile = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchProfile(String uid) async {
    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Map class string/int to int studentClass
        final classStr = data['className']?.toString() ?? '9';
        final studentClass = int.tryParse(classStr) ?? 9;

        // Map board
        final boardStr = (data['board']?.toString() ?? 'BSEK').toUpperCase();
        final board = boardStr == 'BIEK' ? StudentBoard.biek : StudentBoard.bsek;

        // Map level
        final levelStr = data['learningLevel']?.toString() ?? 'Average';
        StudentLevel level;
        if (levelStr == 'Weak' || levelStr == 'Developing') {
          level = StudentLevel.developing;
        } else if (levelStr == 'Smart' || levelStr == 'Advanced' || levelStr == 'Intelligent') {
          level = StudentLevel.advanced;
        } else {
          level = StudentLevel.average;
        }

        _profile = StudentProfile(
          name: data['fullName'] ?? 'Student',
          studentClass: studentClass,
          board: board,
          level: level,
          subscriptionTier: data['subscriptionTier']?.toString() ?? 'Pending',
        );
      } else {
        // Fallback profile if user was created but firestore doc is missing/not-updated yet
        _profile = StudentProfile(
          name: _user?.displayName ?? 'Student',
          studentClass: 9,
          board: StudentBoard.bsek,
          level: StudentLevel.average,
          subscriptionTier: 'Pending',
        );
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update student name in Firestore and local state
  Future<void> updateName(String newName) async {
    if (_user == null || _profile == null) return;
    try {
      await _db.collection('users').doc(_user!.uid).update({
        'fullName': newName,
      });
      _profile = _profile!.copyWith(name: newName);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating name: $e");
      rethrow;
    }
  }

  String get profileSummary {
    if (_profile == null) return 'Profile not loaded';
    return _profile!.promptSummary;
  }

  String get subscriptionTier => _profile?.subscriptionTier ?? 'Pending';

  bool get isFreeTier => subscriptionTier.toLowerCase() == 'free';

  Future<void> refreshProfile() async {
    if (_user != null) {
      await _fetchProfile(_user!.uid);
    }
  }

  Future<void> setSubscriptionTier(String tier) async {
    if (_user == null) return;
    await _db.collection('users').doc(_user!.uid).set({
      'subscriptionTier': tier,
    }, SetOptions(merge: true));

    _profile = _profile?.copyWith(subscriptionTier: tier) ??
        StudentProfile(
          name: _user?.displayName ?? 'Student',
          studentClass: 9,
          board: StudentBoard.bsek,
          level: StudentLevel.average,
          subscriptionTier: tier,
        );
    notifyListeners();
  }

  // Update complete profile in Firestore
  Future<void> updateProfile({
    required String name,
    required int studentClass,
    required StudentBoard board,
    required StudentLevel level,
  }) async {
    if (_user == null) return;
    try {
      final boardStr = board == StudentBoard.biek ? 'BIEK' : 'BSEK';
      String levelStr = 'Average';
      if (level == StudentLevel.developing) {
        levelStr = 'Weak';
      } else if (level == StudentLevel.advanced) {
        levelStr = 'Intelligent';
      }

      await _db.collection('users').doc(_user!.uid).set({
        'fullName': name,
        'className': studentClass.toString(),
        'board': boardStr,
        'learningLevel': levelStr,
        'email': _user!.email,
      }, SetOptions(merge: true));

      _profile = StudentProfile(
        name: name,
        studentClass: studentClass,
        board: board,
        level: level,
        subscriptionTier: _profile?.subscriptionTier ?? 'Pending',
      );
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    }
  }

  // Log Out
  Future<void> logOut() async {
    await _auth.signOut();
    _profile = null;
    _user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
