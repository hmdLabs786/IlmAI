class SyllabusSubject {
  final String name;
  final List<String> chapters;

  const SyllabusSubject({
    required this.name,
    required this.chapters,
  });
}

class SyllabusData {
  static const Map<String, List<SyllabusSubject>> bsekSyllabus = {
    '9': [
      SyllabusSubject(
        name: 'Physics',
        chapters: [
          'Physical Quantities & Measurement',
          'Kinematics',
          'Dynamics',
          'Turning Effect of Forces',
          'Gravitation',
          'Work and Energy',
          'Properties of Matter',
        ],
      ),
      SyllabusSubject(
        name: 'Chemistry',
        chapters: [
          'Fundamentals of Chemistry',
          'Structure of Atoms',
          'Periodic Table & Periodicity',
          'Structure of Molecules',
          'Physical States of Matter',
          'Solutions',
        ],
      ),
      SyllabusSubject(
        name: 'Mathematics',
        chapters: [
          'Real & Complex Numbers',
          'Logarithms',
          'Algebraic Expressions & Formulas',
          'Factorization',
          'Algebraic Manipulation',
          'Linear Equations & Inequalities',
        ],
      ),
      SyllabusSubject(
        name: 'Biology',
        chapters: [
          'Introduction to Biology',
          'Solving a Biological Problem',
          'Biodiversity',
          'Cells and Tissues',
          'Cell Cycle',
          'Enzymes',
        ],
      ),
    ],
    '10': [
      SyllabusSubject(
        name: 'Physics',
        chapters: [
          'Simple Harmonic Motion & Waves',
          'Sound',
          'Geometrical Optics',
          'Electrostatics',
          'Current Electricity',
          'Electromagnetism',
          'Introductory Electronics',
        ],
      ),
      SyllabusSubject(
        name: 'Chemistry',
        chapters: [
          'Chemical Equilibrium',
          'Acids, Bases and Salts',
          'Organic Chemistry',
          'Biochemistry',
          'Environmental Chemistry',
          'Chemical Industries',
        ],
      ),
      SyllabusSubject(
        name: 'Mathematics',
        chapters: [
          'Quadratic Equations',
          'Theory of Quadratic Equations',
          'Partial Fractions',
          'Sets and Functions',
          'Basic Statistics',
          'Trigonometry',
        ],
      ),
      SyllabusSubject(
        name: 'Biology',
        chapters: [
          'Gaseous Exchange',
          'Homeostasis',
          'Coordination and Control',
          'Support and Movement',
          'Reproduction',
          'Inheritance',
        ],
      ),
    ],
  };

  static const Map<String, List<SyllabusSubject>> biekSyllabus = {
    '11': [
      SyllabusSubject(
        name: 'Physics',
        chapters: [
          'Scope of Physics',
          'Scalars and Vectors',
          'Motion',
          'Motion in Two Dimensions',
          'Torque, Angular Momentum & Equilibrium',
          'Gravitation',
          'Work, Power and Energy',
        ],
      ),
      SyllabusSubject(
        name: 'Chemistry',
        chapters: [
          'Introduction to Chemical Kinetics',
          'Three States of Matter: Gas, Liquid, Solid',
          'Atomic Structure',
          'Chemical Bonding',
          'Energetics of Chemical Reactions',
          'Chemical Equilibrium',
        ],
      ),
      SyllabusSubject(
        name: 'Mathematics',
        chapters: [
          'Complex Numbers',
          'Matrices and Determinants',
          'Groups and Quadratic Equations',
          'Permutations & Combinations',
          'Mathematical Induction',
          'Trigonometry Identities',
        ],
      ),
    ],
    '12': [
      SyllabusSubject(
        name: 'Physics',
        chapters: [
          'Heat',
          'Electrostatics',
          'Current Electricity',
          'Electromagnetism',
          'Electromagnetic Induction',
          'Atomic Spectra',
          'Nuclear Physics',
        ],
      ),
      SyllabusSubject(
        name: 'Chemistry',
        chapters: [
          'S and P Block Elements',
          'D and F Block Elements',
          'Organic Chemistry Introduction',
          'Hydrocarbons',
          'Alcohols, Phenols and Ethers',
          'Aldehydes and Ketones',
          'Carboxylic Acids',
        ],
      ),
      SyllabusSubject(
        name: 'Mathematics',
        chapters: [
          'Functions and Limits',
          'Differentiation',
          'Integration',
          'Introduction to Analytic Geometry',
          'Linear Inequalities & Linear Programming',
          'Conic Sections',
        ],
      ),
    ],
  };

  static List<SyllabusSubject> getSubjects(String board, String className) {
    if (board == 'BIEK') {
      return biekSyllabus[className] ?? biekSyllabus['11']!;
    } else {
      return bsekSyllabus[className] ?? bsekSyllabus['9']!;
    }
  }
}
