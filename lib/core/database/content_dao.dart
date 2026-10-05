import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/content.dart';

class ContentDao {
  final Future<Database> Function() _database;

  const ContentDao(this._database);

  Future<ContentData?> getContent() async {
    try {
      final rows = await (await _database()).query(
        'app_content',
        where: 'id = ?',
        whereArgs: ['main_content'],
        limit: 1,
      );
      final source = rows.isNotEmpty
          ? rows.first['data'] as String
          : await rootBundle.loadString('assets/data/content.json');
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      return ContentData.fromJson(
        decoded['content'] as Map<String, dynamic>? ?? const {},
      );
    } catch (_) {
      return null;
    }
  }
}
