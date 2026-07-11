import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/posts/data/tag_catalog.dart';
import 'package:cyanzone_mobile/src/features/posts/data/tags_repository.dart';

void main() {
  test('fallback catalog contains the requested categories and tags', () {
    expect(
      TagCatalog.fallback.map((category) => category.name),
      ['Academic Subjects', 'Sports', 'Music', 'Creative Arts'],
    );

    final academic = TagCatalog.fallback.first;
    expect(academic.tags.map((tag) => tag.name), contains('Mathematics'));
    expect(academic.tags.map((tag) => tag.name), contains('Additional Mathematics'));

    final sports = TagCatalog.fallback[1];
    expect(sports.tags.map((tag) => tag.name), contains('Silat'));
    expect(sports.tags.map((tag) => tag.name), contains('Chess'));
  });

  test('fallback catalog has exact tag counts per category', () {
    final academic = TagCatalog.fallback.first;
    expect(academic.tags.length, 17);

    final sports = TagCatalog.fallback[1];
    expect(sports.tags.length, 11);

    final music = TagCatalog.fallback[2];
    expect(music.tags.length, 4);

    final creative = TagCatalog.fallback[3];
    expect(creative.tags.length, 4);
  });

  test('fallback catalog has all required academic subjects', () {
    final academic = TagCatalog.fallback.first;
    final tagNames = academic.tags.map((t) => t.name).toSet();

    expect(tagNames, containsAll([
      'English', 'Malay', 'Chinese', 'Tamil', 'Mathematics',
      'Additional Mathematics', 'Physics', 'Chemistry', 'Biology',
      'General Science', 'History', 'Geography', 'Visual Arts',
      'Accounting', 'Economics', 'Business Studies', 'Marketing'
    ]));
  });

  test('fallback catalog has all required sports tags', () {
    final sports = TagCatalog.fallback[1];
    final tagNames = sports.tags.map((t) => t.name).toSet();

    expect(tagNames, containsAll([
      'Basketball', 'Football', 'Badminton', 'Volleyball', 'Tennis',
      'Ping Pong', 'Fitness', 'Taekwondo', 'Karate', 'Silat', 'Chess'
    ]));
  });

  test('fallback catalog has all required music tags', () {
    final music = TagCatalog.fallback[2];
    final tagNames = music.tags.map((t) => t.name).toSet();

    expect(tagNames, containsAll([
      'Guitar', 'Piano', 'Singing', 'Vocal Training'
    ]));
  });

  test('fallback catalog has all required creative arts tags', () {
    final creative = TagCatalog.fallback[3];
    final tagNames = creative.tags.map((t) => t.name).toSet();

    expect(tagNames, containsAll([
      'Photography', 'Videography', 'Graphic Design', 'Animation'
    ]));
  });

  test('tag slugs are lowercase with hyphens', () {
    for (final category in TagCatalog.fallback) {
      for (final tag in category.tags) {
        expect(tag.slug, matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
          reason: 'Tag "${tag.name}" has invalid slug "${tag.slug}"');
      }
    }
  });

  test('tag slugs do not contain spaces', () {
    for (final category in TagCatalog.fallback) {
      for (final tag in category.tags) {
        expect(tag.slug.contains(' '), isFalse,
          reason: 'Tag "${tag.name}" slug contains space');
      }
    }
  });

  test('tag category parser sorts tags by position', () {
    final category = TagCategory.fromMap({
      'name': 'Sports',
      'tags': [
        {'name': 'Football', 'slug': 'football', 'position': 2},
        {'name': 'Basketball', 'slug': 'basketball', 'position': 1},
      ],
    });

    expect(category.tags.map((tag) => tag.slug), ['basketball', 'football']);
  });

  test('tag option fromMap extracts name and slug correctly', () {
    final tag = TagOption.fromMap({
      'name': 'Additional Mathematics',
      'slug': 'additional-mathematics',
    });

    expect(tag.name, 'Additional Mathematics');
    expect(tag.slug, 'additional-mathematics');
  });

  test('tags repository selects only catalog fields needed by the app', () {
    expect(TagsRepository.selectColumns, contains('tags(name, slug, position'));
    expect(TagsRepository.selectColumns, isNot(contains('requester_id')));
  });
}
