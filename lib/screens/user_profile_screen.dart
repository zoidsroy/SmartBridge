import 'package:flutter/material.dart';
import 'package:iot_smarthome/models/user_model.dart';
import 'package:iot_smarthome/services/auth_service.dart';
import 'package:iot_smarthome/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:country_picker/country_picker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  UserModel? _userInfo;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmNewPasswordVisible = false;
  bool _isEditing = false;
  bool _isGettingLocation = false;
  String _selectedGender = '남성';
  String _selectedCountry = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    final userInfo = await _authService.getCurrentUserInfo();
    if (userInfo != null) {
      setState(() {
        _userInfo = userInfo;
        _nameController.text = userInfo.name;
        _ageController.text = userInfo.age.toString();
        _selectedGender = userInfo.gender;
        _countryController.text = userInfo.country;
        _selectedCountry = userInfo.country;
        _cityController.text = userInfo.city;
        _phoneController.text = userInfo.phoneNumber;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _authenticateUser() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 비밀번호를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증이 완료되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 일치하지 않습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateUserInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedUser = UserModel(
        uid: _userInfo!.uid,
        userId: _userInfo!.userId,
        email: _userInfo!.email,
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        gender: _selectedGender,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        createdAt: _userInfo!.createdAt,
      );

      bool success = await _userService.updateUserModel(updatedUser);
      
      if (success) {
        // 비밀번호 변경이 요청된 경우
        if (_newPasswordController.text.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await user.updatePassword(_newPasswordController.text);
          }
        }

        setState(() {
          _userInfo = updatedUser;
          _isEditing = false;
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원정보가 성공적으로 업데이트되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원정보 업데이트에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // 위치 서비스 재확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화해주세요.');
      }

      // 권한 재확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // 15초 제한
      );

      print('📍 위치 확인됨: ${position.latitude}, ${position.longitude}');

      // 주소 변환
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        print('📍 주소 정보: ${place.toString()}');
        
        String country = place.country ?? '';
        String city = place.locality ?? place.administrativeArea ?? place.subAdministrativeArea ?? '';
        
        if (country.isEmpty && city.isEmpty) {
          throw Exception('위치 정보를 주소로 변환할 수 없습니다. 네트워크 연결을 확인해주세요.');
        }

        setState(() {
          _selectedCountry = country;
          _countryController.text = _selectedCountry;
          _cityController.text = city;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('현재 위치가 설정되었습니다: $country, $city'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('주소 정보를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('❌ 위치 확인 오류: $e');
      
      String errorMessage;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timeLimit')) {
        errorMessage = '위치 확인 시간이 초과되었습니다. 다시 시도해주세요.';
      } else if (e.toString().contains('network') || e.toString().contains('Network')) {
        errorMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
      } else if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        errorMessage = '위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
      } else if (e.toString().contains('service') || e.toString().contains('Service')) {
        errorMessage = '위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.';
      } else {
        errorMessage = '위치를 가져올 수 없습니다. 수동으로 국가와 도시를 선택해주세요.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 4),
                             Text(
                 '수동으로 국가와 도시를 선택할 수 있습니다.',
                 style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
               ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.displayName;
          _countryController.text = _selectedCountry;
        });
      },
    );
  }

  Widget _buildAuthenticationScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '본인 확인',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '회원정보를 확인하기 위해\n현재 비밀번호를 입력해주세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: '현재 비밀번호',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _authenticateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileScreen() {
    if (_userInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userInfo!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userInfo!.email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${_userInfo!.userId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 편집 모드 토글 버튼
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isEditing = !_isEditing;
                        if (!_isEditing) {
                          // 편집 모드 취소 시 원래 값으로 복원
                          _nameController.text = _userInfo!.name;
                          _ageController.text = _userInfo!.age.toString();
                          _selectedGender = _userInfo!.gender;
                          _countryController.text = _userInfo!.country;
                          _selectedCountry = _userInfo!.country;
                          _cityController.text = _userInfo!.city;
                          _phoneController.text = _userInfo!.phoneNumber;
                          _newPasswordController.clear();
                          _confirmNewPasswordController.clear();
                        }
                      });
                    },
                    icon: Icon(_isEditing ? Icons.cancel : Icons.edit),
                    label: Text(_isEditing ? '편집 취소' : '정보 수정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEditing ? Colors.grey : const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateUserInfo,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('저장'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 회원 정보 폼
            _buildInfoField('이름', _nameController, Icons.person_outlined),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildInfoField('나이', _ageController, Icons.cake_outlined, 
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGenderField(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_isEditing) ...[
              // 위치 정보 업데이트 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '위치 정보 업데이트',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      icon: _isGettingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: Text(_isGettingLocation ? '위치 확인 중...' : '현재 위치로 업데이트'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: _buildCountryField(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoField('도시', _cityController, Icons.location_city_outlined),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildInfoField('전화번호', _phoneController, Icons.phone_outlined,
                keyboardType: TextInputType.phone),

            if (_isEditing) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              Text(
                '비밀번호 변경 (선택사항)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                  hintText: '변경하지 않으려면 비워두세요',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return '비밀번호는 6자 이상이어야 합니다.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmNewPasswordController,
                obscureText: !_isConfirmNewPasswordVisible,
                enabled: _isEditing,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmNewPasswordVisible = !_isConfirmNewPasswordVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: _isEditing ? Colors.white : Colors.grey[100],
                ),
                validator: (value) {
                  if (_newPasswordController.text.isNotEmpty) {
                    if (value == null || value.isEmpty) {
                      return '새 비밀번호 확인을 입력해주세요.';
                    }
                    if (value != _newPasswordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 32),

            // 계정 정보
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '계정 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadOnlyInfo('아이디', _userInfo!.userId),
                  const SizedBox(height: 8),
                  _buildReadOnlyInfo('이메일', _userInfo!.email),
                  const SizedBox(height: 8),
                  _buildReadOnlyInfo('가입일', 
                      '${_userInfo!.createdAt.year}.${_userInfo!.createdAt.month.toString().padLeft(2, '0')}.${_userInfo!.createdAt.day.toString().padLeft(2, '0')}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, IconData icon, 
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey[100],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label을(를) 입력해주세요.';
        }
        if (label == '나이') {
          int? age = int.tryParse(value);
          if (age == null || age < 1 || age > 120) {
            return '올바른 나이를 입력해주세요.';
          }
        }
        if (label == '전화번호') {
          if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(value.replaceAll('-', ''))) {
            return '올바른 휴대폰 번호를 입력해주세요.';
          }
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: InputDecoration(
        labelText: '성별',
        prefixIcon: const Icon(Icons.people_outlined),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey[100],
      ),
      items: ['남성', '여성', '기타'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: _isEditing ? (String? newValue) {
        setState(() {
          _selectedGender = newValue!;
        });
      } : null,
    );
  }

  Widget _buildCountryField() {
    return GestureDetector(
      onTap: _isEditing ? _selectCountry : null,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _countryController,
          decoration: InputDecoration(
            labelText: '나라',
            prefixIcon: const Icon(Icons.public_outlined),
            suffixIcon: _isEditing ? const Icon(Icons.arrow_drop_down) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey[100],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '나라를 선택해주세요.';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildReadOnlyInfo(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('회원정보'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2196F3),
        centerTitle: true,
      ),
      body: _isLoading && _userInfo == null
          ? const Center(child: CircularProgressIndicator())
          : !_isAuthenticated
              ? _buildAuthenticationScreen()
              : _buildProfileScreen(),
    );
  }
} 