class MetaConnectionModel {
  final String ownerId;
  final String facebookPageId;
  final String facebookPageName;
  final String adAccountId;
  final String adAccountName;
  final String currency;
  final String? timezone;
  final String dataSource;
  final bool isConnected;
  final String connectionStatus; // 'Connected', 'Disconnected', 'Reauthorization Required', 'Error'
  final List<String> grantedPermissions;
  final List<String> missingPermissions;
  final DateTime? lastSyncAt;
  final String? lastSyncError;
  final DateTime? tokenExpiresAt;
  final bool isTokenExpired;
  final bool requiresAppReview;
  final DateTime updatedAt;

  const MetaConnectionModel({
    required this.ownerId,
    this.facebookPageId = '',
    this.facebookPageName = '',
    this.adAccountId = '',
    this.adAccountName = '',
    this.currency = 'MYR',
    this.timezone = 'Asia/Kuala_Lumpur',
    this.dataSource = 'REAL_META_API',
    this.isConnected = false,
    this.connectionStatus = 'Disconnected',
    this.grantedPermissions = const [],
    this.missingPermissions = const [
      'ads_read',
      'ads_management',
      'leads_retrieval',
      'pages_manage_metadata',
      'pages_manage_ads',
      'pages_read_engagement',
      'pages_show_list',
    ],
    this.lastSyncAt,
    this.lastSyncError,
    this.tokenExpiresAt,
    this.isTokenExpired = false,
    this.requiresAppReview = true,
    required this.updatedAt,
  });

  factory MetaConnectionModel.initial(String ownerId) {
    return MetaConnectionModel(
      ownerId: ownerId,
      updatedAt: DateTime.now(),
    );
  }

  factory MetaConnectionModel.fromMap(Map<String, dynamic> map) {
    return MetaConnectionModel(
      ownerId: map['ownerId'] as String? ?? '',
      facebookPageId: map['facebookPageId'] as String? ?? '',
      facebookPageName: map['facebookPageName'] as String? ?? '',
      adAccountId: map['adAccountId'] as String? ?? '',
      adAccountName: map['adAccountName'] as String? ?? '',
      currency: map['currency'] as String? ?? 'MYR',
      timezone: map['timezone'] as String? ?? 'Asia/Kuala_Lumpur',
      dataSource: map['dataSource'] as String? ?? 'REAL_META_API',
      isConnected: map['isConnected'] as bool? ?? false,
      connectionStatus: map['connectionStatus'] as String? ?? 'Disconnected',
      grantedPermissions: List<String>.from(map['grantedPermissions'] ?? []),
      missingPermissions: List<String>.from(map['missingPermissions'] ?? []),
      lastSyncAt: map['lastSyncAt'] != null
          ? DateTime.tryParse(map['lastSyncAt'].toString())
          : null,
      lastSyncError: map['lastSyncError'] as String?,
      tokenExpiresAt: map['tokenExpiresAt'] != null
          ? DateTime.tryParse(map['tokenExpiresAt'].toString())
          : null,
      isTokenExpired: map['isTokenExpired'] as bool? ?? false,
      requiresAppReview: map['requiresAppReview'] as bool? ?? true,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'facebookPageId': facebookPageId,
      'facebookPageName': facebookPageName,
      'adAccountId': adAccountId,
      'adAccountName': adAccountName,
      'currency': currency,
      'timezone': timezone,
      'dataSource': dataSource,
      'isConnected': isConnected,
      'connectionStatus': connectionStatus,
      'grantedPermissions': grantedPermissions,
      'missingPermissions': missingPermissions,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'lastSyncError': lastSyncError,
      'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
      'isTokenExpired': isTokenExpired,
      'requiresAppReview': requiresAppReview,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
