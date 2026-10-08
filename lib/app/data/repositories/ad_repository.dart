import '../providers/ad_provider.dart';
import '../models/ad.dart';

class AdRepository {
  final AdProvider _adProvider;

  AdRepository({required AdProvider adProvider}) : _adProvider = adProvider;

  Future<List<Ad>> getAds() async {
    try {
      final response = await _adProvider.getAds();
      return (response.data as List).map((item) => Ad.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
