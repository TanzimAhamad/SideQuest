import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class ToggiProduct {
  final String id;
  final String name;
  final String category;
  final String url;
  final double? priceBdt;
  final String? priceText;
  final String? description;
  final String type;

  const ToggiProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.url,
    required this.type,
    this.priceBdt,
    this.priceText,
    this.description,
  });

  factory ToggiProduct.fromJson(Map<String, dynamic> json, {bool package = false}) {
    return ToggiProduct(
      id: (package ? json['package_id'] : json['product_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? 'Toggi activity',
      category: json['category']?.toString() ?? (package ? 'Package' : 'Games & Rides'),
      url: (package ? json['package_url'] : json['product_url'])?.toString() ?? 'https://www.toggifunworld.com/',
      priceBdt: (json['price_bdt'] as num?)?.toDouble(),
      priceText: json['price_text']?.toString(),
      description: json['description']?.toString(),
      type: package ? 'package' : (json['product_type']?.toString() ?? 'activity'),
    );
  }

  int get estimatedPrice => priceBdt?.round() ?? 0;
}

class ToggiProductDetails {
  final String name;
  final String category;
  final String url;
  final String? priceText;
  final String? description;

  const ToggiProductDetails({
    required this.name,
    required this.category,
    required this.url,
    this.priceText,
    this.description,
  });

  factory ToggiProductDetails.fromJson(Map<String, dynamic> json) {
    return ToggiProductDetails(
      name: json['name']?.toString() ?? 'Toggi activity',
      category: json['category']?.toString() ?? 'Games & Rides',
      url: json['product_url']?.toString() ?? 'https://www.toggifunworld.com/',
      priceText: json['price_text']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class ToggiService {
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return {'detail': response.body.isEmpty ? 'Empty response from SideQuest API.' : response.body};
  }

  static Future<List<ToggiProduct>> getActivities({String query = '', bool refresh = false}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/toggi/activities').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (refresh) 'refresh': 'true',
      },
    );
    final response = await http.get(uri);
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load Toggi activities.');
    }
    final raw = data['products'] as List? ?? const [];
    return raw.whereType<Map>().map((item) => ToggiProduct.fromJson(
      Map<String, dynamic>.from(item),
    )).toList();
  }

  static Future<List<ToggiProduct>> getPackages({bool refresh = false}) async {
    final uri = Uri.parse('${ApiService.baseUrl}/toggi/packages').replace(
      queryParameters: {if (refresh) 'refresh': 'true'},
    );
    final response = await http.get(uri);
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load Toggi packages.');
    }
    final raw = data['packages'] as List? ?? const [];
    return raw.whereType<Map>().map((item) => ToggiProduct.fromJson(
      Map<String, dynamic>.from(item), package: true,
    )).toList();
  }

  static Future<ToggiProductDetails> getDetails(String productUrl) async {
    final uri = Uri.parse('${ApiService.baseUrl}/toggi/product').replace(
      queryParameters: {'product_url': productUrl},
    );
    final response = await http.get(uri);
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load Toggi product details.');
    }
    return ToggiProductDetails.fromJson(data);
  }
}
