import 'package:cloud_firestore/cloud_firestore.dart';

// The user's rating and review of one book: users/{uid}/ratings/{readingKey}.
// Kept off the reading log so friends who can read logs can't see them.
class BookRatingModel {
  final String id; // the readingKey
  final int? rating; // 1–10; null = not rated
  final String? review; // null = no review
  final DateTime? updatedAt;

  const BookRatingModel({
    required this.id,
    this.rating,
    this.review,
    this.updatedAt,
  });

  factory BookRatingModel.fromMap(String id, Map<String, dynamic> map) {
    return BookRatingModel(
      id: id,
      rating: (map['rating'] as num?)?.toInt(),
      review: map['review'] as String?,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'rating': rating,
    'review': review,
    'updatedAt': Timestamp.now(),
  };

  BookRatingModel copyWith({int? rating, String? review}) {
    return BookRatingModel(
      id: id,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      updatedAt: updatedAt,
    );
  }
}
