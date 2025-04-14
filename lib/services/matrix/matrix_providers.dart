import 'package:ai_chat_chat_client/services/matrix/matrix_service.dart';
import 'package:ai_chat_chat_client/services/providers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:matrix/matrix.dart';
import 'package:riverpod/riverpod.dart';

/// Provider for Matrix clients list
final matrixClientsProvider = StateProvider<List<Client>>((ref) => []);

/// Provider for the active client index
final activeClientIndexProvider = StateProvider<int>((ref) => -1);

/// Provider for the active bundle name
final activeBundleProvider = StateProvider<String?>((ref) => null);

/// Provider for the MatrixService
final matrixServiceProvider = Provider<MatrixService>((ref) {
  return MatrixService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(matrixClientsProvider.notifier),
    ref.watch(activeBundleProvider.notifier),
    ref.watch(activeClientIndexProvider.notifier),
  );
});

/// Provider for the active client
final clientProvider = Provider<Client>((ref) {
  final service = ref.watch(matrixServiceProvider);
  return service.client;
});

/// Provider for the account bundles
final accountBundlesProvider = Provider<Map<String?, List<Client?>>>((ref) {
  final service = ref.watch(matrixServiceProvider);
  return service.accountBundles;
});

/// Provider for the current bundle
final currentBundleProvider = Provider<List<Client?>?>((ref) {
  final service = ref.watch(matrixServiceProvider);
  return service.currentBundle;
});

//? FEATURE SPECIFIC PROVIDERS

// TODO: Implement background push and voip functionality
/// Provider for background push functionality
// final backgroundPushProvider = Provider<BackgroundPush?>((ref) {
//   if (!PlatformInfos.isMobile) return null;
//   return BackgroundPush(ref);
// });

/// Provider for VoIP functionality
// final voipServiceProvider = Provider<VoipService?>((ref) {
//   final store = ref.watch(sharedPreferencesProvider);
//   final client = ref.watch(clientProvider);

//   if (store.getBool('experimental_voip') == false) return null;
//   return VoipService(ref, client);
// });

//? LOGIN STATE PROVIDERS

/// Provider for the login avatar
final loginAvatarProvider = StateProvider<XFile?>((ref) => null);

/// Provider for the login username
final loginUsernameProvider = StateProvider<String?>((ref) => null);

/// Provider for the login registration supported status
final loginRegistrationSupportedProvider = StateProvider<bool?>((ref) => null);

//? UI STATE PROVIDERS
final
/// Provider for the display chat details column
displayChatDetailsColumnProvider = StateProvider<bool>((ref) {
  final store = ref.watch(sharedPreferencesProvider);
  return store.getBool('display_chat_details_column') ?? false;
});
