import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/models/auth/login_response.model.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/repositories/api.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';

final authApiRepositoryProvider = Provider((ref) => AuthApiRepository(ref.watch(apiServiceProvider)));

class AuthApiRepository extends ApiRepository {
  final ApiService _apiService;
  final _log = Logger('AuthApiRepository');

  AuthApiRepository(this._apiService);

  Future<void> changePassword(String newPassword) async {
    await _apiService.usersApi.updateMyUser(UserUpdateMeDto(password: Optional.present(newPassword)));
  }

  Future<LoginResponse> login(String email, String password) async {
    _log.info('[AuthApiRepository] login() called with email: $email');
    _log.info('[AuthApiRepository] basePath: ${_apiService.apiClient.basePath}');
    
    try {
      _log.info('[AuthApiRepository] Creating LoginCredentialDto');
      final credential = LoginCredentialDto(email: email, password: password);
      
      _log.info('[AuthApiRepository] Calling authenticationApi.login()');
      final loginResponseDto = await checkNull(
        _apiService.authenticationApi.login(credential),
      );
      
      _log.info('[AuthApiRepository] Login response received: userId=${loginResponseDto.userId}');
      return _mapLoginReponse(loginResponseDto);
    } catch (e, stackTrace) {
      _log.severe('[AuthApiRepository] Login API call failed: $e');
      _log.severe('[AuthApiRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> logout() async {
    _log.info('[AuthApiRepository] logout() called');
    if (_apiService.apiClient.basePath.isEmpty) {
      _log.warning('[AuthApiRepository] basePath is empty, skipping logout');
      return;
    }

    try {
      await _apiService.authenticationApi.logout().timeout(const Duration(seconds: 7));
      _log.info('[AuthApiRepository] Logout successful');
    } catch (e, stackTrace) {
      _log.severe('[AuthApiRepository] Logout failed: $e');
      _log.severe('[AuthApiRepository] Stack trace: $stackTrace');
      rethrow;
    }
  }

  LoginResponse _mapLoginReponse(LoginResponseDto dto) {
    _log.info('[AuthApiRepository] Mapping LoginResponseDto to LoginResponse');
    return LoginResponse(
      accessToken: dto.accessToken,
      isAdmin: dto.isAdmin,
      name: dto.name,
      profileImagePath: dto.profileImagePath,
      shouldChangePassword: dto.shouldChangePassword,
      userEmail: dto.userEmail,
      userId: dto.userId,
    );
  }

  Future<bool> unlockPinCode(String pinCode) async {
    try {
      await _apiService.authenticationApi.unlockAuthSession(SessionUnlockDto(pinCode: Optional.present(pinCode)));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setupPinCode(String pinCode) {
    return _apiService.authenticationApi.setupPinCode(PinCodeSetupDto(pinCode: pinCode));
  }

  Future<void> lockPinCode() {
    return _apiService.authenticationApi.lockAuthSession();
  }
}