enum AssetAttachmentTransferState {
  localOnly,
  pendingUpload,
  uploading,
  available,
  pendingDelete,
  failed,
  remoteOnly,
  unavailable,
}

enum AssetCloudStorageState {
  pending,
  available,
  failed,
}

enum AssetAttachmentOperationType {
  upload,
  delete,
}

DateTime _attachmentDateTime(Object? value, {DateTime? fallback}) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

T _attachmentEnumByName<T extends Enum>(
  List<T> values,
  Object? name,
  T fallback,
) {
  final raw = name?.toString();
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

class AssetAttachment {
  const AssetAttachment({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
    required this.updatedAt,
    this.localObjectKey,
    this.cloudFileId,
    this.cloudStorageState,
    this.transferState = AssetAttachmentTransferState.localOnly,
    this.lastError,
  });

  final String id;
  final String ownerType;
  final String ownerId;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String? localObjectKey;
  final String? cloudFileId;
  final AssetCloudStorageState? cloudStorageState;
  final AssetAttachmentTransferState transferState;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isImage => mimeType.toLowerCase().startsWith('image/');
  bool get hidden => transferState == AssetAttachmentTransferState.pendingDelete;
  bool get hasLocalBytes => localObjectKey != null && localObjectKey!.isNotEmpty;

  AssetAttachment copyWith({
    String? id,
    String? ownerType,
    String? ownerId,
    String? originalName,
    String? mimeType,
    int? sizeBytes,
    String? sha256,
    String? localObjectKey,
    bool clearLocalObjectKey = false,
    String? cloudFileId,
    bool clearCloudFileId = false,
    AssetCloudStorageState? cloudStorageState,
    bool clearCloudStorageState = false,
    AssetAttachmentTransferState? transferState,
    String? lastError,
    bool clearLastError = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetAttachment(
      id: id ?? this.id,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      originalName: originalName ?? this.originalName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha256: sha256 ?? this.sha256,
      localObjectKey:
          clearLocalObjectKey ? null : localObjectKey ?? this.localObjectKey,
      cloudFileId: clearCloudFileId ? null : cloudFileId ?? this.cloudFileId,
      cloudStorageState: clearCloudStorageState
          ? null
          : cloudStorageState ?? this.cloudStorageState,
      transferState: transferState ?? this.transferState,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'ownerType': ownerType,
        'ownerId': ownerId,
        'originalName': originalName,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'localObjectKey': localObjectKey,
        'cloudFileId': cloudFileId,
        'cloudStorageState': cloudStorageState?.name,
        'transferState': transferState.name,
        'lastError': lastError,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> toBackupManifestJson() {
    final json = toJson();
    json['localObjectKey'] = null;
    json['transferState'] = cloudFileId == null
        ? AssetAttachmentTransferState.unavailable.name
        : AssetAttachmentTransferState.remoteOnly.name;
    json['lastError'] = cloudFileId == null
        ? 'Binary payload is not included in JSON backup.'
        : null;
    return json;
  }

  factory AssetAttachment.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return AssetAttachment(
      id: json['id']?.toString() ?? '',
      ownerType: json['ownerType']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      originalName: json['originalName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256']?.toString() ?? '',
      localObjectKey: json['localObjectKey']?.toString(),
      cloudFileId: json['cloudFileId']?.toString(),
      cloudStorageState: json['cloudStorageState'] == null
          ? null
          : _attachmentEnumByName(
              AssetCloudStorageState.values,
              json['cloudStorageState'],
              AssetCloudStorageState.pending,
            ),
      transferState: _attachmentEnumByName(
        AssetAttachmentTransferState.values,
        json['transferState'],
        AssetAttachmentTransferState.localOnly,
      ),
      lastError: json['lastError']?.toString(),
      createdAt: _attachmentDateTime(json['createdAt'], fallback: now),
      updatedAt: _attachmentDateTime(json['updatedAt'], fallback: now),
    );
  }
}

class AssetAttachmentOperation {
  const AssetAttachmentOperation({
    required this.id,
    required this.attachmentId,
    required this.type,
    required this.createdAt,
    this.cloudFileId,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String attachmentId;
  final AssetAttachmentOperationType type;
  final String? cloudFileId;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  AssetAttachmentOperation copyWith({
    String? id,
    String? attachmentId,
    AssetAttachmentOperationType? type,
    String? cloudFileId,
    bool clearCloudFileId = false,
    DateTime? createdAt,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
  }) {
    return AssetAttachmentOperation(
      id: id ?? this.id,
      attachmentId: attachmentId ?? this.attachmentId,
      type: type ?? this.type,
      cloudFileId: clearCloudFileId ? null : cloudFileId ?? this.cloudFileId,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'attachmentId': attachmentId,
        'type': type.name,
        'cloudFileId': cloudFileId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  factory AssetAttachmentOperation.fromJson(Map<String, Object?> json) {
    return AssetAttachmentOperation(
      id: json['id']?.toString() ?? '',
      attachmentId: json['attachmentId']?.toString() ?? '',
      type: _attachmentEnumByName(
        AssetAttachmentOperationType.values,
        json['type'],
        AssetAttachmentOperationType.upload,
      ),
      cloudFileId: json['cloudFileId']?.toString(),
      createdAt: _attachmentDateTime(json['createdAt']),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError']?.toString(),
    );
  }
}
