import 'package:armoury_flutter/core/filters/component_filter.dart';
import 'package:armoury_flutter/models/component.dart';
import 'package:flutter_test/flutter_test.dart';

Component item({
  required String id,
  required String name,
  ComponentNamespace namespace = ComponentNamespace.crate,
  String category = 'Mechanical',
  String subcategory = 'Motor',
  String desc = '',
  String specs = '',
  String location = '',
  List<String> tags = const [],
}) => Component(
  id: id,
  namespace: namespace,
  category: category,
  subcategory: subcategory,
  name: name,
  qty: 1,
  desc: desc,
  pic: '',
  image: 'none',
  location: location,
  specs: specs,
  status: ComponentStatusType.available,
  tags: tags,
  created: '2026-01-01T00:00:00Z',
  updated: '2026-01-01T00:00:00Z',
);

void main() {
  final components = [
    item(id: 'A', name: 'Drive motor', tags: ['spare']),
    item(
      id: 'B',
      name: 'Terminal block',
      category: 'Electrical',
      namespace: ComponentNamespace.cupboard,
      location: 'Box 4',
    ),
    item(id: 'C', name: 'Bench vise', category: 'Tools'),
  ];

  test('search is case-insensitive across existing searchable fields', () {
    expect(
      ComponentFilter.apply(items: components, query: 'SPARE').map((x) => x.id),
      ['A'],
    );
    expect(
      ComponentFilter.apply(items: components, query: 'box 4').map((x) => x.id),
      ['B'],
    );
    expect(
      ComponentFilter.apply(items: components, query: 'c').map((x) => x.id),
      containsAll(['A', 'B', 'C']),
    );
  });

  test('namespace and domain filters compose', () {
    expect(
      ComponentFilter.apply(
        items: components,
        namespace: ComponentNamespace.cupboard,
        domain: 'electrical',
      ).map((x) => x.id),
      ['B'],
    );
  });

  test('others includes categories outside mechanical and electrical', () {
    expect(
      ComponentFilter.apply(
        items: components,
        domain: 'others',
      ).map((x) => x.id),
      ['C'],
    );
  });
}
