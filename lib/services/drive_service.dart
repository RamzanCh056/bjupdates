import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Uploads generated PDFs (invoices, royalty statements) to the signed-in
/// user's own Google Drive, inside a dedicated "BeatJerky" folder.
///
/// Uses the narrow `drive.file` scope: the app can only see and manage the
/// files it creates itself, never the rest of the user's Drive.
class DriveService {
  DriveService._();

  static const String _scope = 'https://www.googleapis.com/auth/drive.file';
  static const String _folderName = 'BeatJerky';

  static final GoogleSignIn _signIn = GoogleSignIn(scopes: [_scope]);

  /// Whether the user has an active Google session with the Drive scope.
  static Future<bool> isConnected() async {
    try {
      return await _signIn.isSignedIn();
    } catch (_) {
      return false;
    }
  }

  /// Signs the user out of the Drive connection.
  static Future<void> disconnect() async {
    try {
      await _signIn.signOut();
    } catch (_) {}
    await _setConnectedFlag(false);
  }

  /// Prompts Google sign-in with the Drive scope, without uploading anything.
  /// Returns true once connected, false if the user cancels or sign-in fails.
  static Future<bool> connect() async {
    final headers = await _authHeaders();
    return headers != null;
  }

  /// Ensures we have a signed-in Google account with the Drive scope and
  /// returns the authenticated HTTP headers. Returns null if the user
  /// cancels or sign-in fails.
  static Future<Map<String, String>?> _authHeaders() async {
    GoogleSignInAccount? account = await _signIn.signInSilently();
    account ??= await _signIn.signIn();
    if (account == null) return null; // user cancelled
    final headers = await account.authHeaders;
    await _setConnectedFlag(true);
    return headers;
  }

  /// Finds the BeatJerky folder id, creating it if missing.
  static Future<String?> _folderId(Map<String, String> headers) async {
    final q = Uri.encodeQueryComponent(
        "mimeType='application/vnd.google-apps.folder' and "
        "name='$_folderName' and trashed=false");
    final findRes = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=$q&spaces=drive&fields=files(id,name)'),
      headers: headers,
    );
    if (findRes.statusCode == 200) {
      final body = jsonDecode(findRes.body) as Map<String, dynamic>;
      final files = (body['files'] as List?) ?? [];
      if (files.isNotEmpty) {
        return (files.first as Map<String, dynamic>)['id'] as String?;
      }
    }
    // Create the folder.
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': _folderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (createRes.statusCode == 200 || createRes.statusCode == 201) {
      final body = jsonDecode(createRes.body) as Map<String, dynamic>;
      return body['id'] as String?;
    }
    return null;
  }

  /// Uploads [bytes] as a PDF named [fileName] into the BeatJerky folder.
  /// Returns a [DriveUploadResult] describing the outcome.
  static Future<DriveUploadResult> uploadPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final headers = await _authHeaders();
    if (headers == null) {
      return const DriveUploadResult(
          ok: false, cancelled: true, message: 'Google sign-in cancelled');
    }

    final folderId = await _folderId(headers);

    final name = fileName.toLowerCase().endsWith('.pdf')
        ? fileName
        : '$fileName.pdf';

    final meta = <String, dynamic>{
      'name': name,
      if (folderId != null) 'parents': [folderId],
    };

    // Multipart upload: JSON metadata part + binary PDF part.
    const boundary = 'beatjerky_drive_boundary';
    final body = <int>[];
    void addString(String s) => body.addAll(utf8.encode(s));

    addString('--$boundary\r\n');
    addString('Content-Type: application/json; charset=UTF-8\r\n\r\n');
    addString(jsonEncode(meta));
    addString('\r\n--$boundary\r\n');
    addString('Content-Type: application/pdf\r\n\r\n');
    body.addAll(bytes);
    addString('\r\n--$boundary--');

    final res = await http.post(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink'),
      headers: {
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final parsed = jsonDecode(res.body) as Map<String, dynamic>;
      return DriveUploadResult(
        ok: true,
        fileId: parsed['id'] as String?,
        webViewLink: parsed['webViewLink'] as String?,
        message: 'Saved to Google Drive',
      );
    }
    return DriveUploadResult(
      ok: false,
      message: 'Drive upload failed (${res.statusCode})',
    );
  }

  static Future<void> _setConnectedFlag(bool connected) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .set({'driveConnected': connected}, SetOptions(merge: true));
    } catch (_) {}
  }
}

class DriveUploadResult {
  final bool ok;
  final bool cancelled;
  final String? fileId;
  final String? webViewLink;
  final String message;

  const DriveUploadResult({
    required this.ok,
    this.cancelled = false,
    this.fileId,
    this.webViewLink,
    this.message = '',
  });
}
