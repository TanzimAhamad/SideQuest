import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class BlockbusterMovie {
  final String id;
  final String title;
  final String format;
  final String? rating;
  final String? genre;
  final String? cast;
  final String? price;
  final String? posterUrl;
  final String detailsUrl;

  const BlockbusterMovie({
    required this.id,
    required this.title,
    required this.format,
    required this.detailsUrl,
    this.rating,
    this.genre,
    this.cast,
    this.price,
    this.posterUrl,
  });

  factory BlockbusterMovie.fromJson(Map<String, dynamic> json) {
    return BlockbusterMovie(
      id: json['movie_id']?.toString() ?? json['title']?.toString() ?? 'movie',
      title: json['title']?.toString() ?? 'Untitled movie',
      format: json['format']?.toString() ?? 'Not specified',
      rating: json['rating']?.toString(),
      genre: json['genre']?.toString(),
      cast: json['cast']?.toString(),
      price: json['price']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      detailsUrl: json['details_url']?.toString() ?? 'https://www.blockbusterbd.com/now-showing',
    );
  }

  int get estimatedPrice {
    final match = RegExp(r'[\d,]+').firstMatch(price ?? '');
    return match == null ? 0 : int.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
  }
}

class BlockbusterShowtime {
  final String time;
  final String bookingUrl;

  const BlockbusterShowtime({required this.time, required this.bookingUrl});

  factory BlockbusterShowtime.fromJson(Map<String, dynamic> json) {
    return BlockbusterShowtime(
      time: json['time']?.toString() ?? 'Time not listed',
      bookingUrl: json['booking_url']?.toString() ?? 'https://www.blockbusterbd.com/schedule',
    );
  }
}

class BlockbusterHall {
  final String name;
  final List<BlockbusterShowtime> showtimes;

  const BlockbusterHall({required this.name, required this.showtimes});

  factory BlockbusterHall.fromJson(Map<String, dynamic> json) {
    final raw = json['showtimes'] as List? ?? const [];
    return BlockbusterHall(
      name: json['hall']?.toString() ?? 'Blockbuster Cinemas',
      showtimes: raw.whereType<Map>().map((item) => BlockbusterShowtime.fromJson(
        Map<String, dynamic>.from(item),
      )).toList(),
    );
  }
}

class BlockbusterSchedule {
  final String movieId;
  final String title;
  final String? formatAndGenre;
  final String? posterUrl;
  final String date;
  final List<BlockbusterHall> halls;

  const BlockbusterSchedule({
    required this.movieId,
    required this.title,
    required this.date,
    required this.halls,
    this.formatAndGenre,
    this.posterUrl,
  });

  factory BlockbusterSchedule.fromJson(Map<String, dynamic> json) {
    final raw = json['halls'] as List? ?? const [];
    return BlockbusterSchedule(
      movieId: json['movie_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled movie',
      formatAndGenre: json['format_and_genre']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      date: json['date']?.toString() ?? '',
      halls: raw.whereType<Map>().map((item) => BlockbusterHall.fromJson(
        Map<String, dynamic>.from(item),
      )).toList(),
    );
  }
}

class MovieService {
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {}
    return {'detail': response.body.isEmpty ? 'Empty response from SideQuest API.' : response.body};
  }

  static Future<List<BlockbusterMovie>> getNowShowing() async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/movies/now-showing'));
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load Blockbuster movies.');
    }
    final raw = data['movies'] as List? ?? const [];
    return raw.whereType<Map>().map((item) => BlockbusterMovie.fromJson(
      Map<String, dynamic>.from(item),
    )).toList();
  }

  static Future<List<BlockbusterSchedule>> getSchedule(DateTime date) async {
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('${ApiService.baseUrl}/movies/schedule').replace(
      queryParameters: {'target_date': day},
    );
    final response = await http.get(uri);
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw Exception(data['detail']?.toString() ?? 'Could not load movie showtimes.');
    }
    final raw = data['schedule'] as List? ?? const [];
    return raw.whereType<Map>().map((item) => BlockbusterSchedule.fromJson(
      Map<String, dynamic>.from(item),
    )).toList();
  }
}
