import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iot_smarthome/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  // 사용자 정보 저장
  Future<bool> saveUser(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toFirestore());
      return true;
    } catch (e) {
      print('사용자 정보 저장 오류: $e');
      return false;
    }
  }

  // UID로 사용자 정보 가져오기
  Future<UserModel?> getUserByUid(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('사용자 정보 가져오기 오류: $e');
      return null;
    }
  }

  // 사용자 아이디로 이메일 찾기
  Future<String?> getEmailByUserId(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.get('email');
      }
      return null;
    } catch (e) {
      print('아이디로 이메일 찾기 오류: $e');
      return null;
    }
  }

  // 전화번호로 이메일 찾기
  Future<String?> getEmailByPhoneNumber(String phoneNumber) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.get('email');
      }
      return null;
    } catch (e) {
      print('전화번호로 이메일 찾기 오류: $e');
      return null;
    }
  }

  // 사용자 아이디 중복 확인
  Future<bool> isUserIdAvailable(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      return query.docs.isEmpty;
    } catch (e) {
      print('아이디 중복 확인 오류: $e');
      return false;
    }
  }

  // 전화번호 중복 확인
  Future<bool> isPhoneNumberAvailable(String phoneNumber) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      return query.docs.isEmpty;
    } catch (e) {
      print('전화번호 중복 확인 오류: $e');
      return false;
    }
  }

  // 사용자 정보 업데이트 (Map 사용)
  Future<bool> updateUser(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update(updates);
      return true;
    } catch (e) {
      print('사용자 정보 업데이트 오류: $e');
      return false;
    }
  }

  // 사용자 정보 업데이트 (UserModel 사용)
  Future<bool> updateUserModel(UserModel user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(user.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (e) {
      print('사용자 정보 업데이트 오류: $e');
      return false;
    }
  }

  // 사용자 정보 삭제
  Future<bool> deleteUser(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .delete();
      return true;
    } catch (e) {
      print('사용자 정보 삭제 오류: $e');
      return false;
    }
  }

  // 이름과 전화번호로 아이디 찾기
  Future<String?> findUserIdByNameAndPhone(String name, String phoneNumber) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('name', isEqualTo: name)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.get('userId');
      }
      return null;
    } catch (e) {
      print('이름과 전화번호로 아이디 찾기 오류: $e');
      return null;
    }
  }

  // 아이디와 전화번호로 이메일 찾기
  Future<String?> getEmailByUserIdAndPhone(String userId, String phoneNumber) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('userId', isEqualTo: userId)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.get('email');
      }
      return null;
    } catch (e) {
      print('아이디와 전화번호로 이메일 찾기 오류: $e');
      return null;
    }
  }
} 