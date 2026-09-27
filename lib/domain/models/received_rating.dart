class ReceivedRating {
  const ReceivedRating({
    required this.id,
    required this.rideId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String rideId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory ReceivedRating.fromJson(Map<String, dynamic> json) {
    return ReceivedRating(
      id: '${json['ratingId'] ?? json['id'] ?? ''}',
      rideId: '${json['rideId'] ?? ''}',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: '${json['comment'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ??
          DateTime.now(),
    );
  }
}
