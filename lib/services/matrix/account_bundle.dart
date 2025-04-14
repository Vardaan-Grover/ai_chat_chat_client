import 'package:matrix/matrix.dart';
import 'package:logging/logging.dart';

// Set this to the company's official name
const accountBundlesType = 'im.ai_chat_chat.account_bundles';

/// _logger for account bundle operations
final Logger _logger = Logger('ClientAccountBundle');

/// Represents a single account bundle containing a name and priority
class AccountBundle {
  /// The unique name identifier of the account bundle
  String? name;
  
  /// The priority of this bundle (lower numbers have higher priority)
  int? priority;

  /// Creates a new account bundle with optional name and priority
  AccountBundle({this.name, this.priority});

  /// Creates an account bundle from a JSON map
  /// 
  /// Returns null values for missing fields rather than throwing exceptions
  AccountBundle.fromJson(Map<String, dynamic> json)
    : name = json.tryGet<String>('name'),
      priority = json.tryGet<int>('priority');

  /// Converts this account bundle to a JSON map
  /// 
  /// Only includes non-null fields in the output
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (name != null) 'name': name,
    if (priority != null) 'priority': priority,
  };
}

/// Container class for multiple account bundles with a prefix
class AccountBundles {
  /// Optional prefix used in messages
  String? prefix;
  
  /// List of account bundles associated with this container
  List<AccountBundle>? bundles;

  /// Creates a new account bundles container
  AccountBundles({this.prefix, this.bundles});

  /// Creates an account bundles container from a JSON map
  /// 
  /// Safely handles malformed JSON by filtering out invalid entries
  AccountBundles.fromJson(Map<String, dynamic> json)
    : prefix = json.tryGet<String>('prefix'),
      bundles =
          json['bundles'] is List
              ? json['bundles']
                  .map((b) {
                    try {
                      return AccountBundle.fromJson(b);
                    } catch (e) {
                      _logger.warning('Failed to parse bundle: $e');
                      return null;
                    }
                  })
                  .whereType<AccountBundle>()
                  .toList()
              : null;

  /// Converts this account bundles container to a JSON map
  Map<String, dynamic> toJson() => {
    if (prefix != null) 'prefix': prefix,
    if (bundles != null) 'bundles': bundles!.map((v) => v.toJson()).toList(),
  };
}

/// Extension methods for working with account bundles on Matrix clients
extension AccountBundlesExtension on Client {
  /// Retrieves the account bundles associated with this client
  /// 
  /// If no bundles exist, creates a default bundle using the client's userID
  List<AccountBundle> get accountBundles {
    _logger.fine('Retrieving account bundles for user: $userID');
    List<AccountBundle>? ret;
    
    // Try to load existing bundles from account data
    if (accountData.containsKey(accountBundlesType)) {
      try {
        ret = AccountBundles.fromJson(
          accountData[accountBundlesType]!.content,
        ).bundles;
        _logger.fine('Found ${ret?.length ?? 0} existing account bundles');
      } catch (e) {
        _logger.warning('Error parsing account bundles: $e');
      }
    }
    
    // Initialize with empty list if null
    ret ??= [];
    
    // Create default bundle if list is empty
    if (ret.isEmpty) {
      _logger.info('No account bundles found, creating default bundle for $userID');
      ret.add(AccountBundle(name: userID, priority: 0));
    }
    
    return ret;
  }

  /// Adds or updates an account bundle with the specified name and priority
  /// 
  /// @param `name` The name identifier for the bundle
  /// 
  /// @param `priority` Optional priority value (lower values have higher priority)
  /// 
  /// @return A Future that completes when the operation is finished
  Future<void> setAccountBundle(String name, [int? priority]) async {
    _logger.info('Setting account bundle: $name with priority: $priority');
    
    if (name.isEmpty) {
      _logger.warning('Cannot set account bundle with empty name');
      throw ArgumentError('Bundle name cannot be empty');
    }
    
    // Load existing data or create new container
    final data = AccountBundles.fromJson(
      accountData[accountBundlesType]?.content ?? {},
    );
    
    var foundBundle = false;
    final bundles = data.bundles ??= [];
    
    // Update existing bundle if found
    for (final bundle in bundles) {
      if (bundle.name == name) {
        _logger.fine('Updating existing bundle: $name');
        bundle.priority = priority;
        foundBundle = true;
        break;
      }
    }
    
    // Add new bundle if not found
    if (!foundBundle) {
      _logger.fine('Adding new bundle: $name');
      bundles.add(AccountBundle(name: name, priority: priority));
    }
    
    try {
      // Save changes to account data
      await setAccountData(userID!, accountBundlesType, data.toJson());
      _logger.info('Successfully saved account bundle: $name');
    } catch (e) {
      _logger.severe('Failed to save account bundle: $e');
      rethrow;
    }
  }

  /// Removes an account bundle with the specified name
  /// 
  /// @param name The name identifier of the bundle to remove
  /// @return A Future that completes when the operation is finished
  Future<void> removeFromAccountBundle(String name) async {
    _logger.info('Removing from account bundle: $name');
    
    // Nothing to do if no account bundles exist
    if (!accountData.containsKey(accountBundlesType)) {
      _logger.fine('No account bundles exist, nothing to remove');
      return;
    }
    
    final data = AccountBundles.fromJson(
      accountData[accountBundlesType]!.content,
    );
    
    if (data.bundles == null) {
      _logger.fine('No bundles in account data, nothing to remove');
      return;
    }
    
    final initialCount = data.bundles!.length;
    data.bundles!.removeWhere((b) => b.name == name);
    
    // Only update if something was actually removed
    if (data.bundles!.length < initialCount) {
      try {
        await setAccountData(userID!, accountBundlesType, data.toJson());
        _logger.info('Successfully removed bundle: $name');
      } catch (e) {
        _logger.severe('Failed to remove account bundle: $e');
        rethrow;
      }
    } else {
      _logger.fine('Bundle $name not found, nothing removed');
    }
  }

  /// Gets the send prefix for messages from account bundles
  /// 
  /// @return The prefix string or empty string if not set
  String get sendPrefix {
    try {
      final data = AccountBundles.fromJson(
        accountData[accountBundlesType]?.content ?? {},
      );
      
      return data.prefix ?? '';
    } catch (e) {
      _logger.warning('Error retrieving send prefix: $e');
      return '';
    }
  }
}
