import 'package:flutter/material.dart';
import '../data/tag_catalog.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({
    required this.initialSelectedTags,
    required this.tagsFuture,
    this.isSelectionMode = false,
    super.key,
  });

  final Set<String> initialSelectedTags;
  final Future<List<TagCategory>> tagsFuture;
  final bool isSelectionMode;

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.initialSelectedTags);
  }

  void _toggleTag(String slug) {
    setState(() {
      if (_selectedTags.contains(slug)) {
        _selectedTags.remove(slug);
      } else {
        if (widget.isSelectionMode && _selectedTags.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 tags allowed'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedTags.add(slug);
      }
    });
  }

  void _reset() {
    setState(() {
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0B1F3E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isSelectionMode ? 'Select Topics' : 'Filter by Topics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0B1F3E),
          ),
        ),
        actions: [
          if (_selectedTags.isNotEmpty)
            TextButton(
              onPressed: _reset,
              child: Text(
                'Reset',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF4490AD),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<TagCategory>>(
        future: widget.tagsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? TagCatalog.fallback;

          return Column(
            children: [
              if (_selectedTags.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECTED TOPICS (${_selectedTags.length})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF6E828A),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _selectedTags.map((slug) {
                          final tagName = _findTagName(categories, slug);
                          return Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1F3E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tagName ?? slug,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _toggleTag(slug),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      // Special "Others" category
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MISC',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF6E828A),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _TagChip(
                              label: 'Others',
                              slug: 'others',
                              isSelected: _selectedTags.contains('others'),
                              onToggle: _toggleTag,
                            ),
                          ],
                        ),
                      );
                    }

                    final category = categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF6E828A),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: category.tags.map((tag) {
                              return _TagChip(
                                label: tag.name,
                                slug: tag.slug,
                                isSelected: _selectedTags.contains(tag.slug),
                                onToggle: _toggleTag,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _selectedTags),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B1F3E),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.isSelectionMode ? 'Select Tags' : 'Show Results',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _findTagName(List<TagCategory> categories, String slug) {
    if (slug == 'others') return 'Others';
    for (final category in categories) {
      for (final tag in category.tags) {
        if (tag.slug == slug) {
          return tag.name;
        }
      }
    }
    return null;
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.slug,
    required this.isSelected,
    required this.onToggle,
  });

  final String label;
  final String slug;
  final bool isSelected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onToggle(slug),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B1F3E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0B1F3E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
