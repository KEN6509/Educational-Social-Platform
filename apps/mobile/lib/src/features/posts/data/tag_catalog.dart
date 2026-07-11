class TagOption {
  const TagOption({
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

  factory TagOption.fromMap(Map<String, dynamic> map) {
    return TagOption(
      name: map['name'] as String,
      slug: map['slug'] as String,
    );
  }
}

class TagCategory {
  const TagCategory({
    required this.name,
    required this.tags,
  });

  final String name;
  final List<TagOption> tags;

  factory TagCategory.fromMap(Map<String, dynamic> map) {
    final tags = (map['tags'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
      ..sort(
        (a, b) => ((a['position'] as int?) ?? 0)
            .compareTo((b['position'] as int?) ?? 0),
      );

    return TagCategory(
      name: map['name'] as String,
      tags: tags.map(TagOption.fromMap).toList(),
    );
  }
}

class TagCatalog {
  const TagCatalog._();

  static const fallback = [
    TagCategory(
      name: 'Academic Subjects',
      tags: [
        TagOption(name: 'English', slug: 'english'),
        TagOption(name: 'Malay', slug: 'malay'),
        TagOption(name: 'Chinese', slug: 'chinese'),
        TagOption(name: 'Tamil', slug: 'tamil'),
        TagOption(name: 'Mathematics', slug: 'mathematics'),
        TagOption(
          name: 'Additional Mathematics',
          slug: 'additional-mathematics',
        ),
        TagOption(name: 'Physics', slug: 'physics'),
        TagOption(name: 'Chemistry', slug: 'chemistry'),
        TagOption(name: 'Biology', slug: 'biology'),
        TagOption(name: 'General Science', slug: 'general-science'),
        TagOption(name: 'History', slug: 'history'),
        TagOption(name: 'Geography', slug: 'geography'),
        TagOption(name: 'Visual Arts', slug: 'visual-arts'),
        TagOption(name: 'Accounting', slug: 'accounting'),
        TagOption(name: 'Economics', slug: 'economics'),
        TagOption(name: 'Business Studies', slug: 'business-studies'),
        TagOption(name: 'Marketing', slug: 'marketing'),
      ],
    ),
    TagCategory(
      name: 'Sports',
      tags: [
        TagOption(name: 'Basketball', slug: 'basketball'),
        TagOption(name: 'Football', slug: 'football'),
        TagOption(name: 'Badminton', slug: 'badminton'),
        TagOption(name: 'Volleyball', slug: 'volleyball'),
        TagOption(name: 'Tennis', slug: 'tennis'),
        TagOption(name: 'Ping Pong', slug: 'ping-pong'),
        TagOption(name: 'Fitness', slug: 'fitness'),
        TagOption(name: 'Taekwondo', slug: 'taekwondo'),
        TagOption(name: 'Karate', slug: 'karate'),
        TagOption(name: 'Silat', slug: 'silat'),
        TagOption(name: 'Chess', slug: 'chess'),
      ],
    ),
    TagCategory(
      name: 'Music',
      tags: [
        TagOption(name: 'Guitar', slug: 'guitar'),
        TagOption(name: 'Piano', slug: 'piano'),
        TagOption(name: 'Singing', slug: 'singing'),
        TagOption(name: 'Vocal Training', slug: 'vocal-training'),
      ],
    ),
    TagCategory(
      name: 'Creative Arts',
      tags: [
        TagOption(name: 'Photography', slug: 'photography'),
        TagOption(name: 'Videography', slug: 'videography'),
        TagOption(name: 'Graphic Design', slug: 'graphic-design'),
        TagOption(name: 'Animation', slug: 'animation'),
      ],
    ),
  ];
}
