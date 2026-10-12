import '../../models/component.dart';

/// Applies the existing inventory search and namespace/domain rules in one
/// reusable, presentation-independent place.
class ComponentFilter {
  const ComponentFilter._();

  static List<Component> apply({
    required Iterable<Component> items,
    ComponentNamespace? namespace,
    String query = '',
    String domain = 'all',
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedDomain = domain.trim().toLowerCase();

    return items
        .where((item) {
          if (namespace != null && item.namespace != namespace) return false;
          final category = item.category.toLowerCase();
          if (normalizedDomain == 'others' &&
              (category == 'mechanical' || category == 'electrical')) {
            return false;
          }
          if (normalizedDomain.isNotEmpty &&
              normalizedDomain != 'all' &&
              normalizedDomain != 'others' &&
              category != normalizedDomain) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return [
            item.name,
            item.id,
            item.desc,
            item.specs,
            item.location,
            item.category,
            item.subcategory,
            ...item.tags,
          ].any((value) => value.toLowerCase().contains(normalizedQuery));
        })
        .toList(growable: false);
  }
}
