import '../widgets/status_badge.dart';

enum ComponentNamespace {
  crate,
  toolkit,
  cupboard;

  static ComponentNamespace fromString(String? val) {
    if (val == null) return ComponentNamespace.crate;
    switch (val.toLowerCase().trim()) {
      case 'toolkit':
        return ComponentNamespace.toolkit;
      case 'cupboard':
        return ComponentNamespace.cupboard;
      case 'crate':
      default:
        return ComponentNamespace.crate;
    }
  }

  String get keyName => name;
  String get displayName => name.toUpperCase();
}

class Component {
  final String id;
  final ComponentNamespace namespace;
  final String category;
  final String subcategory;
  final String name;
  final int qty;
  final String desc;
  final String pic;
  final String? image;
  final String location;
  final String specs;
  final ComponentStatusType status;
  final List<String> tags;
  final String created;
  final String updated;

  const Component({
    required this.id,
    required this.namespace,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.qty,
    required this.desc,
    required this.pic,
    this.image,
    required this.location,
    required this.specs,
    required this.status,
    required this.tags,
    required this.created,
    required this.updated,
  });

  factory Component.fromJson(Map<String, dynamic> json) {
    return Component(
      id: json['id']?.toString() ?? '',
      namespace: ComponentNamespace.fromString(json['namespace']?.toString()),
      category: json['category']?.toString() ?? '',
      subcategory: json['subcategory']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      desc: json['desc']?.toString() ?? '',
      pic: json['pic']?.toString() ?? '',
      image: json['image']?.toString(),
      location: json['location']?.toString() ?? '',
      specs: json['specs']?.toString() ?? '',
      status: ComponentStatusType.fromString(json['status']?.toString()),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      created: json['created']?.toString() ?? '',
      updated: json['updated']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'namespace': namespace.keyName,
      'category': category,
      'subcategory': subcategory,
      'name': name,
      'qty': qty,
      'desc': desc,
      'pic': pic,
      if (image != null) 'image': image,
      'location': location,
      'specs': specs,
      'status': status.name,
      'tags': tags,
      'created': created,
      'updated': updated,
    };
  }

  Component copyWith({
    String? id,
    ComponentNamespace? namespace,
    String? category,
    String? subcategory,
    String? name,
    int? qty,
    String? desc,
    String? pic,
    String? image,
    String? location,
    String? specs,
    ComponentStatusType? status,
    List<String>? tags,
    String? created,
    String? updated,
  }) {
    return Component(
      id: id ?? this.id,
      namespace: namespace ?? this.namespace,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      desc: desc ?? this.desc,
      pic: pic ?? this.pic,
      image: image ?? this.image,
      location: location ?? this.location,
      specs: specs ?? this.specs,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }
}
