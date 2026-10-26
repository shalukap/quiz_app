import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../state/app_state.dart';
import 'app_open_ad_manager.dart';
import 'firestore_service.dart';
import 'subscription_service.dart';

/// How the signed-in user must confirm their identity before deletion.
enum ReauthMethod { password, google, apple }

/// Permanent account deletion (required by App Store guideline 5.1.1(v)
/// and Google Play's account deletion policy).
class AccountService {
  AccountService._();

  static ReauthMethod? reauthMethodFor(User user) {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    if (providers.contains('apple.com')) return ReauthMethod.apple;
    if (providers.contains('google.com')) return ReauthMethod.google;
    if (providers.contains('password')) return ReauthMethod.password;
    return null;
  }

  /// Re-authenticates, deletes all of the user's data, then the Firebase
  /// account itself. [password] is required for email/password accounts.
  ///
  /// Throws [FirebaseAuthException] if re-authentication fails or is cancelled.
  static Future<void> deleteAccount({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    // Firebase only allows deleting recently signed-in accounts, so always
    // confirm identity first. This also happens before any data is removed.
    final appleAuthCode = await _reauthenticate(user, password: password);

    await FirestoreService().deleteUserData(
      uid: user.uid,
      username: AppState.currentUsername,
    );
    await _deleteProfilePicture(user.uid);

    // Apple requires revoking the Sign in with Apple token on deletion.
    if (appleAuthCode != null) {
      try {
        await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(appleAuthCode);
      } catch (e) {
        debugPrint('Apple token revoke failed: $e');
      }
    }

    await user.delete();

    await SubscriptionService.instance.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    AppState.currentUid = null;
    AppState.currentUsername = null;
  }

  /// Returns the Apple authorization code when re-authenticated with Apple.
  static Future<String?> _reauthenticate(User user, {String? password}) async {
    switch (reauthMethodFor(user)) {
      case ReauthMethod.apple:
        AppOpenAdManager.instance.suppressNextShow = true;
        final result = await user.reauthenticateWithProvider(AppleAuthProvider());
        return result.additionalUserInfo?.authorizationCode;
      case ReauthMethod.google:
        if (kIsWeb) {
          await user.reauthenticateWithPopup(GoogleAuthProvider());
        } else {
          AppOpenAdManager.instance.suppressNextShow = true;
          final account = await GoogleSignIn.instance.authenticate();
          await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(idToken: account.authentication.idToken),
          );
        }
        return null;
      case ReauthMethod.password:
        if (password == null || user.email == null) {
          throw FirebaseAuthException(code: 'missing-password', message: 'Please enter your password.');
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        return null;
      case null:
        return null;
    }
  }

  static Future<void> _deleteProfilePicture(String uid) async {
    // Uploaded as profile_pictures/<uid><extension>.
    for (final ext in ['.jpg', '.jpeg', '.png', '.heic', '.webp', '']) {
      try {
        await FirebaseStorage.instance.ref('profile_pictures/$uid$ext').delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') debugPrint('Profile picture delete failed: $e');
      }
    }
  }
}
