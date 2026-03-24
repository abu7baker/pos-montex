import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../../core/constants/app_config.dart';
import '../../../core/database/app_db.dart';
import '../../../core/database/db_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/payment_methods.dart';
import '../../../core/settings/branch_option.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/data/auth_api_service.dart';

final productsSyncServiceProvider = Provider<ProductsSyncService>((ref) {
  return ProductsSyncService(
    ref.watch(appDbProvider),
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
    ref.watch(authApiServiceProvider),
  );
});

class ProductsSyncService {
  ProductsSyncService(this._db, this._dio, this._storage, this._authApiService);

  final AppDb _db;
  final Dio _dio;
  final SecureStorage _storage;
  final AuthApiService _authApiService;

  Future<int> syncProducts() async {
    final items = await _fetchAllProductsWithSessionRecovery();
    final extractedBranches = _extractBranchOptions(items);
    final businessLocations =
        await _tryFetchBusinessLocationsWithSessionRecovery();
    final syncedBranches = businessLocations.branches.isNotEmpty
        ? businessLocations.branches
        : extractedBranches;
    final branchPaymentMethods = businessLocations.paymentMethodsByBranch;
    final productBranchSelections = _extractProductBranchSelections(items);
    final productBranchStocks = _extractProductBranchStocks(
      items,
      syncedBranches,
    );

    final parsedProducts = items
        .map(_ParsedProduct.fromDynamic)
        .where((product) => product.serverId > 0 && product.name.isNotEmpty)
        .toList();

    if (parsedProducts.isEmpty) {
      await _persistBranchOptions(
        syncedBranches,
        paymentMethodsByBranch: branchPaymentMethods,
      );
      await _db.setApiMeta(
        'last_products_sync_at',
        DateTime.now().toIso8601String(),
      );
      return 0;
    }

    final existingCategories = await (_db.select(_db.productCategories)).get();
    final existingBrands = await (_db.select(_db.brands)).get();
    final existingProducts = await (_db.select(_db.products)).get();

    final categoryState = _CategoryResolverState(existingCategories);
    final brandState = _BrandResolverState(existingBrands);
    final productState = _ProductResolverState(existingProducts);

    final categoriesToUpsert = <int, ProductCategoriesCompanion>{};
    final brandsToUpsert = <int, BrandsCompanion>{};
    final productsToUpsert = <int, ProductsCompanion>{};

    final syncedAt = DateTime.now();

    for (final parsed in parsedProducts) {
      final categoryId = categoryState.resolve(parsed.category);
      if (categoryId != null) {
        categoriesToUpsert[categoryId] = ProductCategoriesCompanion(
          id: drift.Value(categoryId),
          serverId: drift.Value(parsed.category.serverId),
          name: drift.Value(
            parsed.category.name?.trim().isNotEmpty == true
                ? parsed.category.name!.trim()
                : 'قسم #${parsed.category.serverId ?? categoryId}',
          ),
          description: drift.Value(parsed.category.description),
          isActive: const drift.Value(true),
          isDeleted: const drift.Value(false),
          updatedAtServer: drift.Value(parsed.category.updatedAtServer),
          updatedAtLocal: drift.Value(syncedAt),
        );
      }

      final brandId = brandState.resolve(parsed.brand);
      if (brandId != null) {
        brandsToUpsert[brandId] = BrandsCompanion(
          id: drift.Value(brandId),
          serverId: drift.Value(parsed.brand.serverId),
          name: drift.Value(
            parsed.brand.name?.trim().isNotEmpty == true
                ? parsed.brand.name!.trim()
                : 'علامة #${parsed.brand.serverId ?? brandId}',
          ),
          description: drift.Value(parsed.brand.description),
          isActive: const drift.Value(true),
          isDeleted: const drift.Value(false),
          updatedAtServer: drift.Value(parsed.brand.updatedAtServer),
          updatedAtLocal: drift.Value(syncedAt),
        );
      }

      final localProductId = productState.resolve(parsed.serverId, parsed.name);
      productsToUpsert[localProductId] = ProductsCompanion(
        id: drift.Value(localProductId),
        serverId: drift.Value(parsed.serverId),
        name: drift.Value(parsed.name),
        description: drift.Value(parsed.description),
        price: drift.Value(parsed.price),
        stock: drift.Value(parsed.stock),
        categoryId: drift.Value(categoryId),
        brandId: drift.Value(brandId),
        stationCode: drift.Value(parsed.stationCode ?? ''),
        imagePath: drift.Value(null),
        isActive: drift.Value(parsed.isActive),
        isDeleted: drift.Value(parsed.isDeleted),
        deletedAtServer: drift.Value(parsed.deletedAtServer),
        updatedAtServer: drift.Value(parsed.updatedAtServer),
        updatedAt: drift.Value(syncedAt),
      );
    }

    await _db.transaction(() async {
      if (categoriesToUpsert.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(
            _db.productCategories,
            categoriesToUpsert.values.toList(),
          );
        });
      }

      if (brandsToUpsert.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(
            _db.brands,
            brandsToUpsert.values.toList(),
          );
        });
      }

      if (productsToUpsert.isNotEmpty) {
        await _db.upsertProducts(productsToUpsert.values.toList());
      }

      final duplicateProductIds = productState.idsToArchive;
      if (duplicateProductIds.isNotEmpty) {
        await _db.archiveProductsByIds(duplicateProductIds);
      }
    });

    await _persistBranchOptions(
      syncedBranches,
      paymentMethodsByBranch: branchPaymentMethods,
    );
    await _db.setSetting(
      'product_branch_keys_json',
      jsonEncode(productBranchSelections),
    );
    await _db.setSetting(
      'product_branch_stock_json',
      jsonEncode(productBranchStocks),
    );
    await _db.setApiMeta('last_products_sync_at', syncedAt.toIso8601String());
    return productsToUpsert.length;
  }

  Future<void> _persistBranchOptions(
    List<BranchOption> branches, {
    Map<String, List<PaymentMethodOption>> paymentMethodsByBranch = const {},
  }) async {
    if (branches.isEmpty) return;

    final existingSelectionKey =
        (await _db.getSetting('branch_selection_key'))?.trim() ?? '';
    final existingServerId =
        (await _db.getSetting('branch_server_id'))?.trim() ?? '';
    final existingCode = (await _db.getSetting('branch_code'))?.trim() ?? '';
    final existingName = (await _db.getSetting('branch_name'))?.trim() ?? '';

    BranchOption? selected;

    if (existingSelectionKey.isNotEmpty) {
      for (final branch in branches) {
        if (branch.selectionKey == existingSelectionKey) {
          selected = branch;
          break;
        }
      }
    }

    if (selected == null && existingServerId.isNotEmpty) {
      for (final branch in branches) {
        if ('${branch.serverId ?? ''}' == existingServerId) {
          selected = branch;
          break;
        }
      }
    }

    if (selected == null && existingCode.isNotEmpty) {
      for (final branch in branches) {
        if (branch.code == existingCode) {
          selected = branch;
          break;
        }
      }
    }

    if (selected == null && existingName.isNotEmpty) {
      for (final branch in branches) {
        if (branch.name == existingName) {
          selected = branch;
          break;
        }
      }
    }

    selected ??= branches.first;

    await _db.setSetting(
      'branch_options_json',
      BranchOption.encodeList(branches),
    );
    await _db.setSetting(
      'branch_payment_methods_json',
      encodeBranchPaymentMethodsMap(paymentMethodsByBranch),
    );
    await _db.setSetting('branch_selection_key', selected.selectionKey);
    await _db.setSetting('branch_server_id', '${selected.serverId ?? ''}');
    await _db.setSetting('branch_code', selected.code);
    await _db.setSetting('branch_name', selected.name);
    await _db.setSetting('branch_address', selected.address);
    await _db.setSetting('branch_phone', selected.phone);
  }

  Future<List<dynamic>> _fetchAllProductsWithSessionRecovery() async {
    try {
      return await _fetchAllProducts();
    } on DioException catch (error) {
      if (!_isUnauthorized(error)) {
        rethrow;
      }

      final restored = await _restoreServerSession();
      if (!restored) {
        throw Exception(
          'انتهت جلسة المزامنة أو أن بيانات الدخول المحفوظة لم تعد صالحة. أعد تسجيل الدخول ثم حاول مرة أخرى.',
        );
      }

      try {
        return await _fetchAllProducts();
      } on DioException catch (retryError) {
        if (_isUnauthorized(retryError)) {
          throw Exception(
            'تعذر اعتماد جلسة المزامنة مع الخادم. أعد تسجيل الدخول ثم حاول مرة أخرى.',
          );
        }
        rethrow;
      }
    }
  }

  Future<_BusinessLocationsSnapshot>
  _tryFetchBusinessLocationsWithSessionRecovery() async {
    try {
      return await _fetchBusinessLocationsWithSessionRecovery();
    } catch (_) {
      return const _BusinessLocationsSnapshot.empty();
    }
  }

  Future<_BusinessLocationsSnapshot>
  _fetchBusinessLocationsWithSessionRecovery() async {
    try {
      return await _fetchBusinessLocations();
    } on DioException catch (error) {
      if (!_isUnauthorized(error)) {
        rethrow;
      }

      final restored = await _restoreServerSession();
      if (!restored) {
        rethrow;
      }
      return _fetchBusinessLocations();
    }
  }

  Future<_BusinessLocationsSnapshot> _fetchBusinessLocations() async {
    final response = await _dio.get<dynamic>(
      AppConfig.connectorBusinessLocationsPath,
    );
    return _BusinessLocationsSnapshot.fromPayload(response.data);
  }

  Future<List<dynamic>> _fetchAllProducts() async {
    DioException? lastError;

    for (final endpoint in AppConfig.productEndpointCandidates) {
      try {
        final firstResponse = await _fetchPageWithRetry(endpoint, 1);
        final firstPayload = firstResponse.data;
        final firstItems = _extractItems(firstPayload);
        if (firstItems.isEmpty) {
          continue;
        }

        final lastPage = _extractLastPage(firstPayload);
        if (lastPage <= 1) {
          return firstItems;
        }

        final allItems = <dynamic>[...firstItems];
        for (var page = 2; page <= lastPage; page++) {
          final response = await _fetchPageWithRetry(endpoint, page);
          allItems.addAll(_extractItems(response.data));
        }
        return allItems;
      } on DioException catch (error) {
        lastError = error;
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw Exception(
      'تعذر العثور على endpoint صالح للمنتجات. راجع المسارات في AppConfig.',
    );
  }

  Future<bool> _restoreServerSession() async {
    final username = (await _storage.readSavedUsername())?.trim() ?? '';
    final password = await _storage.readSavedPassword() ?? '';
    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    final baseUrl = await _resolveBaseUrl();
    final clientId = await _resolveClientId();
    final clientSecret = await _resolveClientSecret();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      return false;
    }

    try {
      final tokens = await _authApiService.loginWithPassport(
        baseUrl: baseUrl,
        clientId: clientId,
        clientSecret: clientSecret,
        username: username,
        password: password,
      );

      await _storage.saveToken(tokens.accessToken);
      if (tokens.refreshToken.trim().isNotEmpty) {
        await _storage.saveRefreshToken(tokens.refreshToken);
      }
      return true;
    } catch (_) {
      await _storage.clearSession();
      return false;
    }
  }

  Future<Response<dynamic>> _fetchPageWithRetry(
    String endpoint,
    int page,
  ) async {
    DioException? lastError;

    var transientAttempts = 0;

    for (var attempt = 1; attempt <= 5; attempt++) {
      try {
        return await _dio.get<dynamic>(
          endpoint,
          queryParameters: {'page': page},
        );
      } on DioException catch (error) {
        lastError = error;
        final statusCode = error.response?.statusCode;
        final isRateLimited = statusCode == 429;
        final isTransientNetworkIssue =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError;

        if (!isRateLimited && !isTransientNetworkIssue) {
          rethrow;
        }

        if (isTransientNetworkIssue) {
          transientAttempts++;
        }

        final reachedRetryLimit = isRateLimited
            ? attempt == 5
            : transientAttempts >= 2;

        if (reachedRetryLimit) {
          rethrow;
        }

        await Future<void>.delayed(
          _resolveRetryDelay(
            error.response,
            isRateLimited ? attempt : transientAttempts,
            isRateLimited,
          ),
        );
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(
            path: endpoint,
            queryParameters: {'page': page},
          ),
        );
  }

  Duration _resolveRetryDelay(
    Response<dynamic>? response,
    int attempt,
    bool isRateLimited,
  ) {
    if (isRateLimited) {
      final retryAfterHeader = response?.headers.value('retry-after');
      final retryAfterSeconds = int.tryParse((retryAfterHeader ?? '').trim());
      if (retryAfterSeconds != null && retryAfterSeconds > 0) {
        return Duration(seconds: retryAfterSeconds);
      }

      return Duration(seconds: attempt * 2);
    }

    return Duration(seconds: attempt);
  }

  Future<String> _resolveBaseUrl() async {
    final storedBaseUrl = (await _storage.readApiBaseUrl())?.trim();
    if (storedBaseUrl != null && storedBaseUrl.isNotEmpty) {
      return storedBaseUrl;
    }
    return AppConfig.defaultBaseUrl;
  }

  Future<String> _resolveClientId() async {
    final storedClientId = (await _storage.readOauthClientId())?.trim();
    if (storedClientId != null && storedClientId.isNotEmpty) {
      return storedClientId;
    }
    return '';
  }

  Future<String> _resolveClientSecret() async {
    final storedClientSecret = (await _storage.readOauthClientSecret())?.trim();
    if (storedClientSecret != null && storedClientSecret.isNotEmpty) {
      return storedClientSecret;
    }
    return '';
  }

  bool _isUnauthorized(DioException error) {
    return error.response?.statusCode == 401;
  }

  int _extractLastPage(dynamic payload) {
    if (payload is! Map) return 1;
    final meta = payload['meta'];
    if (meta is Map) {
      return _readInt(meta['last_page']) ?? 1;
    }
    return 1;
  }

  List<dynamic> _extractItems(dynamic payload) {
    if (payload is List) return payload;
    if (payload is! Map) return const <dynamic>[];

    final data = payload['data'];
    if (data is List) return data;
    if (data is Map) return [data];

    final products = payload['products'];
    if (products is List) return products;
    if (products is Map) return [products];

    final result = payload['result'];
    if (result is List) return result;
    if (result is Map) return [result];

    return const <dynamic>[];
  }
}

class _CategoryResolverState {
  _CategoryResolverState(List<ProductCategoryDb> rows)
    : _byServerId = {
        for (final row in rows)
          if (row.serverId != null && row.serverId! > 0) row.serverId!: row.id,
      },
      _byName = {for (final row in rows) _normalizeName(row.name): row.id},
      _usedIds = rows.map((row) => row.id).toSet(),
      _nextId =
          rows.fold<int>(0, (maxId, row) => row.id > maxId ? row.id : maxId) +
          1;

  final Map<int, int> _byServerId;
  final Map<String, int> _byName;
  final Set<int> _usedIds;
  int _nextId;

  int? resolve(_RelatedEntity related) {
    final normalizedName = _normalizeName(related.name);
    if ((related.serverId == null || related.serverId! <= 0) &&
        normalizedName.isEmpty) {
      return null;
    }

    if (related.serverId != null &&
        related.serverId! > 0 &&
        _byServerId.containsKey(related.serverId)) {
      return _byServerId[related.serverId];
    }

    if (normalizedName.isNotEmpty && _byName.containsKey(normalizedName)) {
      final localId = _byName[normalizedName]!;
      if (related.serverId != null && related.serverId! > 0) {
        _byServerId[related.serverId!] = localId;
      }
      return localId;
    }

    final preferredId = related.serverId;
    final localId =
        preferredId != null &&
            preferredId > 0 &&
            !_usedIds.contains(preferredId)
        ? preferredId
        : _allocateNextId();

    _usedIds.add(localId);
    if (related.serverId != null && related.serverId! > 0) {
      _byServerId[related.serverId!] = localId;
    }
    if (normalizedName.isNotEmpty) {
      _byName[normalizedName] = localId;
    }
    return localId;
  }

  int _allocateNextId() {
    while (_usedIds.contains(_nextId)) {
      _nextId++;
    }
    return _nextId++;
  }
}

class _BrandResolverState {
  _BrandResolverState(List<BrandDb> rows)
    : _byServerId = {
        for (final row in rows)
          if (row.serverId != null && row.serverId! > 0) row.serverId!: row.id,
      },
      _byName = {for (final row in rows) _normalizeName(row.name): row.id},
      _usedIds = rows.map((row) => row.id).toSet(),
      _nextId =
          rows.fold<int>(0, (maxId, row) => row.id > maxId ? row.id : maxId) +
          1;

  final Map<int, int> _byServerId;
  final Map<String, int> _byName;
  final Set<int> _usedIds;
  int _nextId;

  int? resolve(_RelatedEntity related) {
    final normalizedName = _normalizeName(related.name);
    if ((related.serverId == null || related.serverId! <= 0) &&
        normalizedName.isEmpty) {
      return null;
    }

    if (related.serverId != null &&
        related.serverId! > 0 &&
        _byServerId.containsKey(related.serverId)) {
      return _byServerId[related.serverId];
    }

    if (normalizedName.isNotEmpty && _byName.containsKey(normalizedName)) {
      final localId = _byName[normalizedName]!;
      if (related.serverId != null && related.serverId! > 0) {
        _byServerId[related.serverId!] = localId;
      }
      return localId;
    }

    final preferredId = related.serverId;
    final localId =
        preferredId != null &&
            preferredId > 0 &&
            !_usedIds.contains(preferredId)
        ? preferredId
        : _allocateNextId();

    _usedIds.add(localId);
    if (related.serverId != null && related.serverId! > 0) {
      _byServerId[related.serverId!] = localId;
    }
    if (normalizedName.isNotEmpty) {
      _byName[normalizedName] = localId;
    }
    return localId;
  }

  int _allocateNextId() {
    while (_usedIds.contains(_nextId)) {
      _nextId++;
    }
    return _nextId++;
  }
}

class _ProductResolverState {
  _ProductResolverState(List<ProductDb> rows)
    : _byServerId = <int, int>{},
      _pendingNameMatches = <String, List<int>>{},
      _idsToArchive = <int>{},
      _usedIds = rows.map((row) => row.id).toSet(),
      _nextId =
          rows.fold<int>(0, (maxId, row) => row.id > maxId ? row.id : maxId) +
          1 {
    final sortedRows = [...rows]..sort(_compareRowsForCanonicalChoice);
    final serverLinkedNames = <String>{};

    for (final row in sortedRows) {
      final normalizedName = _normalizeName(row.name);
      final serverId = row.serverId;

      if (serverId != null && serverId > 0) {
        final existingId = _byServerId[serverId];
        if (existingId == null) {
          _byServerId[serverId] = row.id;
          if (normalizedName.isNotEmpty) {
            serverLinkedNames.add(normalizedName);
          }
        } else if (existingId != row.id) {
          _idsToArchive.add(row.id);
        }
        continue;
      }

      if (normalizedName.isEmpty) continue;
      (_pendingNameMatches[normalizedName] ??= <int>[]).add(row.id);
    }

    for (final name in serverLinkedNames) {
      final duplicateIds = _pendingNameMatches.remove(name);
      if (duplicateIds != null && duplicateIds.isNotEmpty) {
        _idsToArchive.addAll(duplicateIds);
      }
    }
  }

  final Map<int, int> _byServerId;
  final Map<String, List<int>> _pendingNameMatches;
  final Set<int> _idsToArchive;
  final Set<int> _usedIds;
  int _nextId;

  List<int> get idsToArchive => _idsToArchive.toList(growable: false);

  int resolve(int serverId, String name) {
    if (_byServerId.containsKey(serverId)) {
      return _byServerId[serverId]!;
    }

    final normalizedName = _normalizeName(name);
    final pendingIds = normalizedName.isEmpty
        ? null
        : _pendingNameMatches.remove(normalizedName);

    if (pendingIds != null && pendingIds.isNotEmpty) {
      final localId = pendingIds.first;
      if (pendingIds.length > 1) {
        _idsToArchive.addAll(pendingIds.skip(1));
      }
      _byServerId[serverId] = localId;
      return localId;
    }

    final localId = !_usedIds.contains(serverId) ? serverId : _allocateNextId();
    _usedIds.add(localId);
    _byServerId[serverId] = localId;
    return localId;
  }

  int _allocateNextId() {
    while (_usedIds.contains(_nextId)) {
      _nextId++;
    }
    return _nextId++;
  }
}

int _compareRowsForCanonicalChoice(ProductDb a, ProductDb b) {
  if (a.isDeleted != b.isDeleted) {
    return a.isDeleted ? 1 : -1;
  }
  if (a.isActive != b.isActive) {
    return a.isActive ? -1 : 1;
  }

  final updatedAtServerComparison = _compareDateTimeDesc(
    a.updatedAtServer,
    b.updatedAtServer,
  );
  if (updatedAtServerComparison != 0) {
    return updatedAtServerComparison;
  }

  final updatedAtComparison = _compareDateTimeDesc(a.updatedAt, b.updatedAt);
  if (updatedAtComparison != 0) {
    return updatedAtComparison;
  }

  return a.id.compareTo(b.id);
}

int _compareDateTimeDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

class _ParsedProduct {
  const _ParsedProduct({
    required this.serverId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
    required this.brand,
    required this.stationCode,
    required this.isActive,
    required this.isDeleted,
    required this.updatedAtServer,
    required this.deletedAtServer,
  });

  final int serverId;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final _RelatedEntity category;
  final _RelatedEntity brand;
  final String? stationCode;
  final bool isActive;
  final bool isDeleted;
  final DateTime? updatedAtServer;
  final DateTime? deletedAtServer;

  factory _ParsedProduct.fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return const _ParsedProduct(
        serverId: 0,
        name: '',
        description: null,
        price: 0,
        stock: 0,
        category: _RelatedEntity.empty,
        brand: _RelatedEntity.empty,
        stationCode: null,
        isActive: true,
        isDeleted: false,
        updatedAtServer: null,
        deletedAtServer: null,
      );
    }

    final map = raw.cast<dynamic, dynamic>();
    final categoryMap = _asMap(map['category']);
    final brandMap = _asMap(map['brand']);
    final firstVariation = _extractFirstVariation(map);

    final category = _RelatedEntity(
      serverId:
          _readInt(categoryMap?['id']) ??
          _readInt(categoryMap?['category_id']) ??
          _readInt(map['category_id']),
      name:
          _readString(categoryMap?['name']) ??
          _readString(map['category_name']) ??
          _readString(map['category']),
      description: _readString(categoryMap?['description']),
      updatedAtServer: _readDateTime(categoryMap?['updated_at']),
    );

    final brand = _RelatedEntity(
      serverId:
          _readInt(brandMap?['id']) ??
          _readInt(brandMap?['brand_id']) ??
          _readInt(map['brand_id']),
      name:
          _readString(brandMap?['name']) ??
          _readString(map['brand_name']) ??
          _readString(map['brand']),
      description: _readString(brandMap?['description']),
      updatedAtServer: _readDateTime(brandMap?['updated_at']),
    );

    final isInactive = _readBool(map['is_inactive'], fallback: false);
    final notForSelling = _readBool(map['not_for_selling'], fallback: false);
    final hidePos = _readBool(map['hide_pos'], fallback: false);

    return _ParsedProduct(
      serverId:
          _readInt(map['id']) ??
          _readInt(map['product_id']) ??
          _readInt(firstVariation?['product_id']) ??
          0,
      name:
          _readString(map['name']) ??
          _readString(map['product_name']) ??
          _readString(map['display_name']) ??
          '',
      description:
          _readString(map['description']) ??
          _readString(map['product_description']),
      price:
          _readDouble(map['price']) ??
          _readDouble(map['default_sell_price']) ??
          _readDouble(map['sell_price_inc_tax']) ??
          _readDouble(firstVariation?['default_sell_price']) ??
          _readDouble(firstVariation?['sell_price_inc_tax']) ??
          _readDouble(firstVariation?['dpp_inc_tax']) ??
          _readDouble(map['unit_price']) ??
          0,
      stock:
          _sumVariationLocationQty(firstVariation) ??
          _readInt(map['stock']) ??
          _readInt(map['current_stock']) ??
          _readInt(map['qty_available']) ??
          _readInt(map['quantity']) ??
          0,
      category: category,
      brand: brand,
      stationCode:
          _readString(map['station_code']) ??
          _readString(map['kitchen_station']) ??
          _readString(map['department_code']) ??
          _readString(categoryMap?['printer_id']),
      isActive:
          !isInactive &&
          !notForSelling &&
          !hidePos &&
          !_readBool(map['is_deleted'], fallback: false),
      isDeleted: _readDateTime(map['deleted_at']) != null,
      updatedAtServer:
          _readDateTime(map['updated_at']) ??
          _readDateTime(firstVariation?['updated_at']) ??
          _readDateTime(map['created_at']),
      deletedAtServer: _readDateTime(map['deleted_at']),
    );
  }
}

class _RelatedEntity {
  const _RelatedEntity({
    required this.serverId,
    required this.name,
    this.description,
    this.updatedAtServer,
  });

  static const empty = _RelatedEntity(serverId: null, name: null);

  final int? serverId;
  final String? name;
  final String? description;
  final DateTime? updatedAtServer;
}

Map<dynamic, dynamic>? _asMap(dynamic value) {
  if (value is Map) return value.cast<dynamic, dynamic>();
  return null;
}

Map<dynamic, dynamic>? _extractFirstVariation(Map<dynamic, dynamic> product) {
  final productVariations = product['product_variations'];
  if (productVariations is! List || productVariations.isEmpty) return null;

  for (final item in productVariations) {
    final productVariation = _asMap(item);
    final variations = productVariation?['variations'];
    if (variations is! List || variations.isEmpty) continue;
    final firstVariation = _asMap(variations.first);
    if (firstVariation != null) return firstVariation;
  }

  return null;
}

int? _sumVariationLocationQty(Map<dynamic, dynamic>? variation) {
  if (variation == null) return null;
  final details = variation['variation_location_details'];
  if (details is! List || details.isEmpty) {
    return _readInt(variation['qty_available']);
  }

  double total = 0;
  var found = false;
  for (final item in details) {
    final row = _asMap(item);
    final qty = _readDouble(row?['qty_available']);
    if (qty == null) continue;
    total += qty;
    found = true;
  }

  if (!found) return null;
  return total.round();
}

String _normalizeName(String? value) => (value ?? '').trim().toLowerCase();

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().trim());
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString().trim());
}

bool _readBool(dynamic value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'active' ||
      normalized == 'enabled') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'inactive' ||
      normalized == 'disabled') {
    return false;
  }
  return fallback;
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

List<BranchOption> _extractBranchOptions(List<dynamic> items) {
  final branchesByKey = <String, BranchOption>{};

  for (final item in items) {
    final product = _asMap(item);
    final locations = product?['product_locations'];
    if (locations is! List) continue;

    for (final locationItem in locations) {
      final location = _asMap(locationItem);
      if (location == null) continue;

      final serverId = _readInt(location['id']);
      final code = _readString(location['location_id']) ?? '';
      final name = _readString(location['name']) ?? '';
      if (name.isEmpty) continue;

      final addressParts = <String>[
        _readString(location['landmark']) ?? '',
        _readString(location['city']) ?? '',
        _readString(location['state']) ?? '',
        _readString(location['country']) ?? '',
      ].where((part) => part.trim().isNotEmpty).toList(growable: false);

      final candidate = BranchOption(
        selectionKey: BranchOption.makeSelectionKey(
          serverId: serverId,
          code: code,
          name: name,
        ),
        serverId: serverId,
        code: code,
        name: name,
        address: addressParts.join(' - '),
        phone: _readString(location['mobile']) ?? '',
      );

      final existing = branchesByKey[candidate.selectionKey];
      if (existing == null) {
        branchesByKey[candidate.selectionKey] = candidate;
        continue;
      }

      branchesByKey[candidate.selectionKey] = BranchOption(
        selectionKey: candidate.selectionKey,
        serverId: candidate.serverId ?? existing.serverId,
        code: candidate.code.isNotEmpty ? candidate.code : existing.code,
        name: candidate.name.isNotEmpty ? candidate.name : existing.name,
        address: candidate.address.isNotEmpty
            ? candidate.address
            : existing.address,
        phone: candidate.phone.isNotEmpty ? candidate.phone : existing.phone,
      );
    }
  }

  final branches = branchesByKey.values.toList()
    ..sort((a, b) {
      final byCode = a.code.compareTo(b.code);
      if (byCode != 0) return byCode;
      return a.name.compareTo(b.name);
    });
  return branches;
}

Map<String, List<String>> _extractProductBranchSelections(List<dynamic> items) {
  final mapping = <String, List<String>>{};

  for (final item in items) {
    final product = _asMap(item);
    final productServerId = _readInt(product?['id']);
    if (productServerId == null || productServerId <= 0) continue;

    final locations = product?['product_locations'];
    if (locations is! List || locations.isEmpty) continue;

    final keys = <String>{};
    for (final locationItem in locations) {
      final location = _asMap(locationItem);
      if (location == null) continue;
      final locationServerId = _readInt(location['id']);
      final code = _readString(location['location_id']) ?? '';
      final name = _readString(location['name']) ?? '';
      if (name.isEmpty) continue;
      keys.add(
        BranchOption.makeSelectionKey(
          serverId: locationServerId,
          code: code,
          name: name,
        ),
      );
    }

    if (keys.isNotEmpty) {
      mapping['$productServerId'] = keys.toList()..sort();
    }
  }

  return mapping;
}

Map<String, Map<String, int>> _extractProductBranchStocks(
  List<dynamic> items,
  List<BranchOption> branches,
) {
  final branchKeyByServerId = <int, String>{
    for (final branch in branches)
      if (branch.serverId != null) branch.serverId!: branch.selectionKey,
  };
  final output = <String, Map<String, int>>{};

  for (final item in items) {
    final product = _asMap(item);
    final productServerId = _readInt(product?['id']);
    if (productServerId == null || productServerId <= 0) continue;

    final firstVariation = _extractFirstVariation(product ?? const {});
    final details = firstVariation?['variation_location_details'];
    final stocks = <String, int>{};

    if (details is List) {
      for (final detailItem in details) {
        final detail = _asMap(detailItem);
        final locationServerId = _readInt(detail?['location_id']);
        final selectionKey = locationServerId == null
            ? null
            : branchKeyByServerId[locationServerId];
        if (selectionKey == null || selectionKey.isEmpty) continue;
        final qty = _readDouble(detail?['qty_available'])?.round();
        if (qty == null) continue;
        stocks[selectionKey] = qty;
      }
    }

    if (stocks.isEmpty) {
      final productLocations = product?['product_locations'];
      if (productLocations is List && productLocations.length == 1) {
        final location = _asMap(productLocations.first);
        final locationServerId = _readInt(location?['id']);
        final code = _readString(location?['location_id']) ?? '';
        final name = _readString(location?['name']) ?? '';
        final selectionKey = BranchOption.makeSelectionKey(
          serverId: locationServerId,
          code: code,
          name: name,
        );
        final qty =
            _sumVariationLocationQty(firstVariation) ??
            _readInt(product?['stock']) ??
            0;
        stocks[selectionKey] = qty;
      }
    }

    if (stocks.isNotEmpty) {
      output['$productServerId'] = stocks;
    }
  }

  return output;
}

class _BusinessLocationsSnapshot {
  const _BusinessLocationsSnapshot({
    required this.branches,
    required this.paymentMethodsByBranch,
  });

  const _BusinessLocationsSnapshot.empty()
    : branches = const <BranchOption>[],
      paymentMethodsByBranch = const <String, List<PaymentMethodOption>>{};

  final List<BranchOption> branches;
  final Map<String, List<PaymentMethodOption>> paymentMethodsByBranch;

  factory _BusinessLocationsSnapshot.fromPayload(dynamic payload) {
    final items = _extractCollectionItems(payload);
    final branches = <BranchOption>[];
    final paymentMethodsByBranch = <String, List<PaymentMethodOption>>{};

    for (final item in items) {
      final row = _asMap(item);
      if (row == null) continue;

      final serverId = _readInt(row['id']);
      final code = _readString(row['location_id']) ?? '';
      final name = _readString(row['name']) ?? '';
      if (name.isEmpty) continue;

      final selectionKey = BranchOption.makeSelectionKey(
        serverId: serverId,
        code: code,
        name: name,
      );

      final addressParts = <String>[
        _readString(row['landmark']) ?? '',
        _readString(row['city']) ?? '',
        _readString(row['state']) ?? '',
        _readString(row['country']) ?? '',
      ].where((part) => part.trim().isNotEmpty).toList(growable: false);

      branches.add(
        BranchOption(
          selectionKey: selectionKey,
          serverId: serverId,
          code: code,
          name: name,
          address: addressParts.join(' - '),
          phone: _readString(row['mobile']) ?? '',
        ),
      );

      final rawMethods = row['payment_methods'];
      if (rawMethods is! List) continue;

      final normalizedMethods = <PaymentMethodOption>[];
      final seenCodes = <String>{};

      for (final methodItem in rawMethods) {
        final methodMap = _asMap(methodItem);
        if (methodMap == null) continue;
        final method = PaymentMethodOption.fromJson(
          methodMap.map((key, value) => MapEntry(key.toString(), value)),
        );
        final codeKey = PaymentMethods.normalizeCode(method.code);
        if (codeKey.isEmpty || seenCodes.contains(codeKey)) continue;
        seenCodes.add(codeKey);
        normalizedMethods.add(
          PaymentMethodOption(
            code: codeKey,
            label: method.label,
            accountId: method.accountId,
          ),
        );
      }

      if (normalizedMethods.isNotEmpty) {
        paymentMethodsByBranch[selectionKey] = normalizedMethods;
      }
    }

    branches.sort((a, b) {
      final byCode = a.code.compareTo(b.code);
      if (byCode != 0) return byCode;
      return a.name.compareTo(b.name);
    });

    return _BusinessLocationsSnapshot(
      branches: branches,
      paymentMethodsByBranch: paymentMethodsByBranch,
    );
  }
}

List<dynamic> _extractCollectionItems(dynamic payload) {
  if (payload is List) return payload;
  if (payload is! Map) return const <dynamic>[];

  final data = payload['data'];
  if (data is List) return data;
  if (data is Map) return [data];

  final result = payload['result'];
  if (result is List) return result;
  if (result is Map) return [result];

  return const <dynamic>[];
}
