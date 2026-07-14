class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String board;
  final String className;
  final String learningLevel;
  final String subscriptionTier;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.board,
    required this.className,
    required this.learningLevel,
    this.subscriptionTier = 'Pending',
  });

  // Convert object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'board': board,
      'className': className,
      'learningLevel': learningLevel,
      'subscriptionTier': subscriptionTier,
    };
  }

  // Optional: Create object from Firestore Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      board: map['board'] ?? '',
      className: map['className'] ?? '',
      learningLevel: map['learningLevel'] ?? '',
      subscriptionTier: map['subscriptionTier'] ?? 'Pending',
    );
  }
}
