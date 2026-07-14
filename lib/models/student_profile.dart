enum StudentBoard { bsek, biek }

enum StudentLevel { developing, average, advanced }

class StudentProfile {
  final String name;
  final int studentClass;
  final StudentBoard board;
  final StudentLevel level;
  final String subscriptionTier;

  StudentProfile({
    required this.name,
    required this.studentClass,
    required this.board,
    required this.level,
    this.subscriptionTier = 'Pending',
  });

  StudentProfile copyWith({
    String? name,
    int? studentClass,
    StudentBoard? board,
    StudentLevel? level,
    String? subscriptionTier,
  }) {
    return StudentProfile(
      name: name ?? this.name,
      studentClass: studentClass ?? this.studentClass,
      board: board ?? this.board,
      level: level ?? this.level,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
    );
  }

  // String helpers for cleaner UI display
  String get boardName {
    switch (board) {
      case StudentBoard.bsek:
        return 'BSEK';
      case StudentBoard.biek:
        return 'BIEK';
    }
  }

  String get levelName {
    switch (level) {
      case StudentLevel.developing:
        return 'Weak';
      case StudentLevel.average:
        return 'Average';
      case StudentLevel.advanced:
        return 'Intelligent';
    }
  }

  String get boardDescription {
    switch (board) {
      case StudentBoard.bsek:
        return 'BSEK Matric';
      case StudentBoard.biek:
        return 'BIEK Intermediate';
    }
  }

  String get promptSummary {
    return 'Class $studentClass, Board $boardName, Level $levelName';
  }

  bool get isFreeTier => subscriptionTier.toLowerCase() == 'free';
}
