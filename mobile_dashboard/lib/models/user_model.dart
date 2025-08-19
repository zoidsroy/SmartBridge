import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String userId; // 사용자가 만든 아이디
  final String email;
  final String name;
  final int age;
  final String gender;
  final String country;
  final String city;
  final String phoneNumber;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.userId,
    required this.email,
    required this.name,
    required this.age,
    required this.gender,
    required this.country,
    required this.city,
    required this.phoneNumber,
    required this.createdAt,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      gender: data['gender'] ?? '',
      country: data['country'] ?? '',
      city: data['city'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'country': country,
      'city': city,
      'phoneNumber': phoneNumber,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // 복사본 생성
  UserModel copyWith({
    String? uid,
    String? userId,
    String? email,
    String? name,
    int? age,
    String? gender,
    String? country,
    String? city,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      city: city ?? this.city,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 