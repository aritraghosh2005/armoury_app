import 'package:armoury_flutter/core/sync/component_patch.dart';
import 'package:armoury_flutter/core/sync/operation_id.dart';
import 'package:armoury_flutter/models/component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const component = Component(
    id: 'COMP-A',
    namespace: ComponentNamespace.crate,
    category: 'Electrical',
    subcategory: 'Motors',
    name: 'Motor',
    qty: 5,
    desc: 'Current description',
    pic: '',
    location: 'Crate 2',
    specs: '',
    status: ComponentStatusType.available,
    tags: ['robotics'],
    created: '2026-01-01',
    updated: '2026-01-01',
  );

  test('change patch contains only fields changed by the editor', () {
    final patch = changedComponentFields(component, {
      ...component.toJson(),
      'location': 'Toolkit',
    });

    expect(patch, {'location': 'Toolkit'});
  });

  test('independent field edit does not re-send stale values', () {
    final patch = changedComponentFields(component, {'qty': 8});

    expect(patch, {'qty': 8});
    expect(patch.containsKey('location'), isFalse);
    expect(patch.containsKey('desc'), isFalse);
  });

  test('operation IDs are UUID v4 values and independently generated', () {
    final first = newOperationId();
    final second = newOperationId();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(uuidV4.hasMatch(first), isTrue);
    expect(uuidV4.hasMatch(second), isTrue);
    expect(first, isNot(second));
  });
}
