import '../../../core/ext/json_utils.dart';

class Category {
  const Category({required this.id, required this.slug, required this.name});

  final String id;
  final String slug;
  final String name;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json.strOr('id', ''),
      slug: json.strOr('slug', ''),
      name: json.strOr('name', ''),
    );
  }
}