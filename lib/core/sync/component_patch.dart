import '../../models/component.dart';

Map<String, dynamic> changedComponentFields(
  Component original,
  Map<String, dynamic> supplied,
) {
  const supported = {
    'namespace',
    'category',
    'subcategory',
    'name',
    'qty',
    'desc',
    'specs',
    'location',
    'status',
    'image',
    'tags',
  };
  final patch = <String, dynamic>{};
  for (final key in supported) {
    if (!supplied.containsKey(key)) continue;
    final value = switch (key) {
      'namespace' =>
        supplied[key] is ComponentNamespace
            ? (supplied[key] as ComponentNamespace).keyName
            : supplied[key]?.toString(),
      'status' => supplied[key]?.toString(),
      'qty' => (supplied[key] as num?)?.toInt(),
      'tags' =>
        supplied[key] is List
            ? (supplied[key] as List).map((tag) => tag.toString()).toList()
            : const <String>[],
      _ => supplied[key]?.toString(),
    };
    final current = switch (key) {
      'namespace' => original.namespace.keyName,
      'category' => original.category,
      'subcategory' => original.subcategory,
      'name' => original.name,
      'qty' => original.qty,
      'desc' => original.desc,
      'specs' => original.specs,
      'location' => original.location,
      'status' => original.status.name,
      'image' => original.image,
      'tags' => original.tags,
      _ => null,
    };
    final equal = key == 'tags'
        ? _sameList(current as List<String>, value as List<String>)
        : current == value;
    if (!equal) patch[key] = value;
  }
  return patch;
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
