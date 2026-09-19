import 'dart:convert';

class DiagnosticFile {
  final int? id;
  final int patientId;
  final String fileName;
  final String category;
  final DateTime uploadDate;
  final String uploadedBy;
  final String fileUrl;
  final String? previewImageUrl;
  final String fileSize;
  final int totalPages;
  final String mimeType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiagnosticFile({
    this.id,
    required this.patientId,
    required this.fileName,
    required this.category,
    required this.uploadDate,
    required this.uploadedBy,
    required this.fileUrl,
    this.previewImageUrl,
    this.fileSize = '2.4 MB',
    this.totalPages = 1,
    this.mimeType = 'application/pdf',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'file_name': fileName,
      'category': category,
      'upload_date': uploadDate.toIso8601String(),
      'uploaded_by': uploadedBy,
      'file_url': fileUrl,
      'preview_image_url': previewImageUrl,
      'file_size': fileSize,
      'total_pages': totalPages,
      'mime_type': mimeType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory DiagnosticFile.fromMap(Map<String, dynamic> map) {
    return DiagnosticFile(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int,
      fileName: map['file_name'] as String,
      category: map['category'] as String,
      uploadDate: DateTime.parse(map['upload_date']),
      uploadedBy: map['uploaded_by'] as String,
      fileUrl: map['file_url'] as String,
      previewImageUrl: map['preview_image_url'] as String?,
      fileSize: map['file_size'] as String? ?? '2.4 MB',
      totalPages: (map['total_pages'] as num?)?.toInt() ?? 1,
      mimeType: map['mime_type'] as String? ?? 'application/pdf',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory DiagnosticFile.fromJson(String source) =>
      DiagnosticFile.fromMap(json.decode(source));
}
