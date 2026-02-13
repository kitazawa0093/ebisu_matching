import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  File? _selectedImageFile; // モバイル用
  Uint8List? _selectedImageBytes; // Web用
  String? _selectedDocumentType; // 'license' or 'myNumber'
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // 書類タイプを選択して画像選択ダイアログを表示
  void _selectDocumentType(String type) {
    setState(() {
      _selectedDocumentType = type;
    });
    _showImageSourceDialog();
  }

  // 画像選択ダイアログ
  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('画像を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ギャラリーから画像を選択
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60, // 圧縮率を上げる（60%）
        maxWidth: 1920, // 最大幅を制限
        maxHeight: 1920, // 最大高さを制限
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final sizeMB = bytes.length / (1024 * 1024);
        print('📷 選択した画像サイズ: ${sizeMB.toStringAsFixed(2)} MB');
        
        setState(() {
          if (kIsWeb) {
            _selectedImageBytes = bytes;
          } else {
            _selectedImageFile = File(image.path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の選択に失敗しました: $e')),
      );
    }
  }

  // カメラで撮影
  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60, // 圧縮率を上げる（60%）
        maxWidth: 1920, // 最大幅を制限
        maxHeight: 1920, // 最大高さを制限
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final sizeMB = bytes.length / (1024 * 1024);
        print('📷 撮影した画像サイズ: ${sizeMB.toStringAsFixed(2)} MB');
        
        setState(() {
          if (kIsWeb) {
            _selectedImageBytes = bytes;
          } else {
            _selectedImageFile = File(image.path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('写真の撮影に失敗しました: $e')),
      );
    }
  }

  // 書類をアップロード
  Future<void> _uploadDocument() async {
    final hasImage = kIsWeb ? _selectedImageBytes != null : _selectedImageFile != null;
    if (!hasImage || _selectedDocumentType == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      print('📤 アップロード開始: ${_selectedDocumentType}');
      
      // Firebase Storageにアップロード
      final documentTypeName = _selectedDocumentType == 'license' ? 'license' : 'myNumber';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('identity_documents')
          .child(user.uid)
          .child('${documentTypeName}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      print('📁 保存先: ${storageRef.fullPath}');

      // Webとモバイルでアップロード方法を分ける
      if (kIsWeb && _selectedImageBytes != null) {
        final imageSizeMB = _selectedImageBytes!.length / (1024 * 1024);
        print('🌐 Web: 画像サイズ ${imageSizeMB.toStringAsFixed(2)} MB (${_selectedImageBytes!.length} bytes)');
        
        // 画像サイズが大きすぎる場合は警告
        if (imageSizeMB > 5) {
          print('⚠️ 画像サイズが大きいです（${imageSizeMB.toStringAsFixed(2)}MB）。アップロードに時間がかかる可能性があります。');
        }
        
        // アップロード処理（タイムアウトを60秒に延長）
        final uploadTask = storageRef.putData(
          _selectedImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        // アップロード進捗を監視
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('📊 アップロード進捗: ${progress.toStringAsFixed(1)}%');
        });
        
        await uploadTask.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('アップロードがタイムアウトしました（60秒）。画像サイズが大きすぎる可能性があります。');
          },
        );
        print('✅ Storageアップロード完了');
      } else if (!kIsWeb && _selectedImageFile != null) {
        final fileSize = await _selectedImageFile!.length();
        final imageSizeMB = fileSize / (1024 * 1024);
        print('📱 モバイル: 画像パス ${_selectedImageFile!.path}');
        print('📱 画像サイズ: ${imageSizeMB.toStringAsFixed(2)} MB');
        
        // 画像サイズが大きすぎる場合は警告
        if (imageSizeMB > 5) {
          print('⚠️ 画像サイズが大きいです（${imageSizeMB.toStringAsFixed(2)}MB）。アップロードに時間がかかる可能性があります。');
        }
        
        // アップロード処理（タイムアウトを60秒に延長）
        final uploadTask = storageRef.putFile(
          _selectedImageFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        // アップロード進捗を監視
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('📊 アップロード進捗: ${progress.toStringAsFixed(1)}%');
        });
        
        await uploadTask.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('アップロードがタイムアウトしました（60秒）。画像サイズが大きすぎる可能性があります。');
          },
        );
        print('✅ Storageアップロード完了');
      } else {
        throw Exception('画像データが見つかりません');
      }
      
      print('🔗 ダウンロードURL取得中...');
      final imageUrl = await storageRef.getDownloadURL();
      print('✅ URL取得完了: $imageUrl');

      // Firestoreに保存
      print('💾 Firestoreに保存中...');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('identity_documents')
          .doc(_selectedDocumentType)
          .set({
        'type': _selectedDocumentType,
        'typeName': _selectedDocumentType == 'license' ? '運転免許証' : 'マイナンバーカード',
        'imageUrl': imageUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Firestoreサブコレクション保存完了');

      // ユーザードキュメントにもフラグを設定
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'identityVerified': true,
        'identityDocumentType': _selectedDocumentType,
        'identityVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Firestoreユーザードキュメント更新完了');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedDocumentType == 'license' ? '運転免許証' : 'マイナンバーカード'}の提出が完了しました',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // 成功後、画像をクリア
      setState(() {
        _selectedImageFile = null;
        _selectedImageBytes = null;
        _selectedDocumentType = null;
      });

      // 少し待ってから前の画面に戻る
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('❌ エラー発生: $e');
      print('📚 スタックトレース: $stackTrace');
      
      if (!mounted) return;
      
      String errorMessage = 'アップロードに失敗しました';
      String detailedError = e.toString();
      
      // エラーの種類を判定
      if (detailedError.contains('permission') || 
          detailedError.contains('Permission') ||
          detailedError.contains('permission-denied') ||
          detailedError.contains('unauthorized')) {
        errorMessage = '❌ アップロード権限がありません。\nFirebase Storageのセキュリティルールを確認してください。\n\nエラー詳細: $detailedError';
      } else if (detailedError.contains('timeout') || detailedError.contains('タイムアウト')) {
        errorMessage = '⏱️ アップロードがタイムアウトしました。\n34KBの画像でタイムアウトする場合は、Firebase Storageのセキュリティルールが原因の可能性があります。\n\nエラー詳細: $detailedError';
      } else if (detailedError.contains('network') || detailedError.contains('Network')) {
        errorMessage = '🌐 ネットワークエラーが発生しました。\n接続を確認してください。\n\nエラー詳細: $detailedError';
      } else if (detailedError.contains('storage/') || detailedError.contains('firebase')) {
        errorMessage = '🔥 Firebase Storageエラー: $detailedError\n\nセキュリティルールを確認してください。';
      } else {
        errorMessage = 'エラー: $detailedError';
      }
      
      print('💬 ユーザー向けエラーメッセージ: $errorMessage');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: '詳細',
            textColor: Colors.white,
            onPressed: () {
              // 詳細をダイアログで表示
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('エラー詳細'),
                  content: SingleChildScrollView(
                    child: Text('$detailedError\n\n$stackTrace'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本人認証')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              '本人確認書類を選択してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // 運転免許証ボタン
            ElevatedButton.icon(
              onPressed: _isUploading ? null : () => _selectDocumentType('license'),
              icon: const Icon(Icons.badge),
              label: const Text('運転免許証を提出'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            
            // マイナンバーカードボタン
            ElevatedButton.icon(
              onPressed: _isUploading ? null : () => _selectDocumentType('myNumber'),
              icon: const Icon(Icons.credit_card),
              label: const Text('マイナンバーカードを提出'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            
            // 画像プレビューとアップロードボタン
            if ((kIsWeb ? _selectedImageBytes != null : _selectedImageFile != null) && _selectedDocumentType != null) ...[
              const SizedBox(height: 32),
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb && _selectedImageBytes != null
                      ? Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                        )
                      : !kIsWeb && _selectedImageFile != null
                          ? Image.file(
                              _selectedImageFile!,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _showImageSourceDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('画像を変更'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () {
                              setState(() {
                                _selectedImageFile = null;
                                _selectedImageBytes = null;
                                _selectedDocumentType = null;
                              });
                            },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('削除', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadDocument,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isUploading ? 'アップロード中...' : '提出する'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
