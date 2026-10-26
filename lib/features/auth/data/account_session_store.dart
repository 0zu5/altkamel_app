import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A locally saved sign-in. Passwords are never retained. Tokens are kept in
/// FlutterSecureStorage under a random account ID; this JSON list only holds
/// display metadata and the active-account selection.
class SavedAccount {
  final String id;
  final String username;
  final DateTime lastUsedAt;

  const SavedAccount({
    required this.id,
    required this.username,
    required this.lastUsedAt,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    id: json['id']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    lastUsedAt: DateTime.tryParse(json['last_used_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'last_used_at': lastUsedAt.toUtc().toIso8601String(),
  };
}

class AccountSessionStore {
  static const _accountsKey = 'saved_accounts_v1';
  static const _activeAccountKey = 'active_saved_account_id';
  static const _accessTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage storage;

  AccountSessionStore({required this.storage});

  Future<List<SavedAccount>> accounts() async {
    final raw = await storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final values = decoded
          .whereType<Map>()
          .map((value) => SavedAccount.fromJson(Map<String, dynamic>.from(value)))
          .where((account) => account.id.isNotEmpty && account.username.isNotEmpty)
          .toList();
      values.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return values;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> activeAccountId() => storage.read(key: _activeAccountKey);

  /// Persists the tokens currently used by the API client as a saved account.
  /// Logging in to the same username updates its existing secure session.
  Future<void> rememberCurrentSession(String username) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) return;
    final accessToken = await storage.read(key: _accessTokenKey);
    final refreshToken = await storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return;

    final entries = await accounts();
    final existing = entries.where(
      (account) => account.username.toLowerCase() == trimmedUsername.toLowerCase(),
    );
    final id = existing.isEmpty ? _randomId() : existing.first.id;
    final updated = SavedAccount(
      id: id,
      username: trimmedUsername,
      lastUsedAt: DateTime.now(),
    );
    final next = [
      updated,
      ...entries.where((account) => account.id != id),
    ];
    await storage.write(key: _accountAccessKey(id), value: accessToken);
    await storage.write(key: _accountRefreshKey(id), value: refreshToken);
    await storage.write(key: _activeAccountKey, value: id);
    await _writeAccounts(next);
  }

  /// Copies a refreshed active token back to its account record. This keeps a
  /// later account switch valid when the API rotates refresh tokens.
  Future<void> syncActiveSession() async {
    final id = await activeAccountId();
    if (id == null || id.isEmpty) return;
    final accessToken = await storage.read(key: _accessTokenKey);
    final refreshToken = await storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) return;
    await storage.write(key: _accountAccessKey(id), value: accessToken);
    await storage.write(key: _accountRefreshKey(id), value: refreshToken);
  }

  Future<bool> activate(String id) async {
    await syncActiveSession();
    final accessToken = await storage.read(key: _accountAccessKey(id));
    final refreshToken = await storage.read(key: _accountRefreshKey(id));
    if (accessToken == null || refreshToken == null) return false;
    await storage.write(key: _accessTokenKey, value: accessToken);
    await storage.write(key: _refreshTokenKey, value: refreshToken);
    await storage.write(key: _activeAccountKey, value: id);
    final updated = (await accounts()).map((account) {
      return account.id == id
          ? SavedAccount(
              id: account.id,
              username: account.username,
              lastUsedAt: DateTime.now(),
            )
          : account;
    }).toList();
    await _writeAccounts(updated);
    return true;
  }

  Future<void> remove(String id) async {
    await storage.delete(key: _accountAccessKey(id));
    await storage.delete(key: _accountRefreshKey(id));
    await _writeAccounts((await accounts()).where((item) => item.id != id).toList());
    if (await activeAccountId() == id) {
      await storage.delete(key: _activeAccountKey);
      await storage.delete(key: _accessTokenKey);
      await storage.delete(key: _refreshTokenKey);
    }
  }

  Future<void> _writeAccounts(List<SavedAccount> values) => storage.write(
    key: _accountsKey,
    value: jsonEncode(values.map((value) => value.toJson()).toList()),
  );

  String _accountAccessKey(String id) => 'saved_account.$id.access';
  String _accountRefreshKey(String id) => 'saved_account.$id.refresh';

  String _randomId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
