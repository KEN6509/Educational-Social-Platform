import 'package:supabase_flutter/supabase_flutter.dart';

import 'tag_catalog.dart';

class TagsRepository {
  TagsRepository(this._client);

  static const selectColumns =
      'name, position, tags(name, slug, position, is_active)';

  final SupabaseClient _client;

  Future<List<TagCategory>> fetchCatalog() async {
    final response = await _client
        .from('tag_categories')
        .select(selectColumns)
        .order('position', ascending: true);

    final categories = response
        .cast<Map<String, dynamic>>()
        .map(TagCategory.fromMap)
        .map(
          (category) => TagCategory(
            name: category.name,
            tags: category.tags.toList(),
          ),
        )
        .where((category) => category.tags.isNotEmpty)
        .toList();

    return categories.isEmpty ? TagCatalog.fallback : categories;
  }
}
