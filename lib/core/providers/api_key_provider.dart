import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcq_test_app/core/services/supabase_service.dart';
import 'package:mcq_test_app/models/api_key.dart';

final apiKeysProvider = FutureProvider<List<ApiKey>>((ref) async {
  return await SupabaseService().getApiKeys();
});

final selectedApiKeyProvider = StateProvider<ApiKey?>((ref) {
  // We can initialize it with null or the first available key after fetching
  return null;
});
