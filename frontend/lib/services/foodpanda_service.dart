import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class FoodpandaCatalogInfo {
  final String city;
  final String catalogUrl;
  final String note;

  const FoodpandaCatalogInfo({
    required this.city,
    required this.catalogUrl,
    required this.note,
  });

  factory FoodpandaCatalogInfo.fromJson(Map<String, dynamic> json) {
    return FoodpandaCatalogInfo(
      city: json['city']?.toString() ?? 'Dhaka',
      catalogUrl: json['catalog_url']?.toString() ?? 'https://www.foodpanda.com.bd/city/dhaka',
      note: json['note']?.toString() ?? 'Browse Foodpanda and add your selection to SideQuest.',
    );
  }
}

class FoodpandaService {
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return {'detail': response.body.isEmpty ? 'Empty response from SideQuest API.' : response.body};
  }

  static Future<FoodpandaCatalogInfo> getDhakaCatalog() async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/foodpanda/dhaka'));
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load Foodpanda information.');
    }
    return FoodpandaCatalogInfo.fromJson(data);
  }

  static Future<String> validateRestaurantLink(String restaurantUrl) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/foodpanda/validate-link'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'restaurant_url': restaurantUrl.trim()}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Enter a valid Foodpanda restaurant URL.');
    }
    return data['restaurant_url']?.toString() ?? restaurantUrl.trim();
  }
}
