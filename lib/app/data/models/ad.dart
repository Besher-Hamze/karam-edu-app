class Ad {
  final String id;
  final String title;

  /// Storage key; stable per uploaded image, used as the image cache key.
  final String image;

  /// Signed URL; changes on every request and expires.
  final String imageUrl;
  final String whatsappUrl;
  final String whatsappNumber;
  final String whatsappMessage;

  Ad({
    required this.id,
    required this.title,
    required this.image,
    required this.imageUrl,
    required this.whatsappUrl,
    this.whatsappNumber = '',
    this.whatsappMessage = '',
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['_id'],
      title: json['title'] ?? '',
      image: json['image'] ?? json['_id'],
      imageUrl: json['imageUrl'] ?? '',
      whatsappUrl: json['whatsappUrl'] ?? '',
      whatsappNumber: json['whatsappNumber']?.toString() ?? '',
      whatsappMessage: json['whatsappMessage']?.toString() ?? '',
    );
  }
}
