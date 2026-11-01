import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/driver_document.dart';

class PendingDriverDocumentUpload {
  const PendingDriverDocumentUpload({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.filePath,
    required this.fileName,
    this.expiresAt,
  });

  final String id;
  final String ownerId;
  final DriverDocumentType type;
  final String filePath;
  final String fileName;
  final DateTime? expiresAt;

  factory PendingDriverDocumentUpload.fromJson(Map<String, dynamic> json) {
    final rawType = '${json['type'] ?? ''}';
    final type = DriverDocumentType.values.firstWhere(
      (value) => value.apiValue == rawType,
      orElse: () => DriverDocumentType.nationalId,
    );
    return PendingDriverDocumentUpload(
      id: '${json['id'] ?? ''}',
      ownerId: '${json['ownerId'] ?? ''}',
      type: type,
      filePath: '${json['filePath'] ?? ''}',
      fileName: '${json['fileName'] ?? ''}',
      expiresAt: DateTime.tryParse('${json['expiresAt'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'type': type.apiValue,
        'filePath': filePath,
        'fileName': fileName,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };
}

class PendingDriverDocumentStore {
  static const _key = 'pending_driver_document_uploads_v1';

  Future<List<PendingDriverDocumentUpload>> list({String? ownerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => PendingDriverDocumentUpload.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) =>
              item.id.isNotEmpty &&
              item.filePath.isNotEmpty &&
              (ownerId == null || item.ownerId == ownerId))
          .toList(growable: false);
    } on FormatException {
      await prefs.remove(_key);
      return const [];
    }
  }

  Future<PendingDriverDocumentUpload> add({
    required String ownerId,
    required DriverDocumentType type,
    required String sourcePath,
    required String fileName,
    DateTime? expiresAt,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('could_not_access_document');
    }

    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/pending-driver-documents');
    await directory.create(recursive: true);
    final id = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final storedName = '${id}_${_safeName(fileName)}';
    final storedFile = await source.copy('${directory.path}/$storedName');
    final entry = PendingDriverDocumentUpload(
      id: id,
      ownerId: ownerId,
      type: type,
      filePath: storedFile.path,
      fileName: fileName,
      expiresAt: expiresAt,
    );

    final existing = await list();
    for (final item in existing.where(
      (item) => item.ownerId == ownerId && item.type == type,
    )) {
      await deleteFile(item);
    }
    await _save([
      ...existing.where(
        (item) => item.ownerId != ownerId || item.type != type,
      ),
      entry,
    ]);
    return entry;
  }

  Future<void> remove(PendingDriverDocumentUpload entry) async {
    await deleteFile(entry);
    final remaining = (await list()).where((item) => item.id != entry.id);
    await _save(remaining);
  }

  Future<void> deleteFile(PendingDriverDocumentUpload entry) async {
    final file = File(entry.filePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> _save(Iterable<PendingDriverDocumentUpload> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  String _safeName(String value) {
    final name = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return name.isEmpty ? 'document.upload' : name;
  }
}
