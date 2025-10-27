import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaUploadProgress {
  final double progress;
  final String? error;
  final bool isComplete;

  MediaUploadProgress({
    required this.progress,
    this.error,
    this.isComplete = false,
  });
}

class MediaService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      // Check permission
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        throw Exception('Gallery permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Pick image from gallery error: $e');
      rethrow;
    }
  }

  // Capture image from camera
  static Future<File?> captureImageFromCamera() async {
    try {
      // Check permission
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Capture image from camera error: $e');
      rethrow;
    }
  }

  // Upload image to Firebase Storage with progress tracking
  static Future<String> uploadImage(
    File image,
    String chatId, {
    Function(MediaUploadProgress)? onProgress,
  }) async {
    try {
      final String fileName =
          'chat_images/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fileName);

      final UploadTask uploadTask = ref.putFile(image);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(MediaUploadProgress(progress: progress));
      });

      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        final String downloadUrl = await ref.getDownloadURL();
        onProgress?.call(MediaUploadProgress(progress: 1.0, isComplete: true));
        return downloadUrl;
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      onProgress?.call(MediaUploadProgress(progress: 0.0, error: e.toString()));
      print('Upload image error: $e');
      rethrow;
    }
  }

  // Generate thumbnail for image preview
  static Future<String> generateThumbnail(File image, String chatId) async {
    try {
      // For thumbnail, we'll upload a compressed version
      final String fileName =
          'chat_thumbnails/$chatId/${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
      final Reference ref = _storage.ref().child(fileName);

      // Read image bytes
      final Uint8List imageBytes = await image.readAsBytes();

      // Upload compressed version as thumbnail
      final UploadTask uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'type': 'thumbnail'},
        ),
      );

      final TaskSnapshot snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      } else {
        throw Exception('Thumbnail upload failed');
      }
    } catch (e) {
      print('Generate thumbnail error: $e');
      rethrow;
    }
  }

  // Compress image for optimization
  static Future<File> compressImage(File image) async {
    try {
      // For now, we'll return the original file
      // In a production app, you might want to use a package like flutter_image_compress
      return image;
    } catch (e) {
      print('Compress image error: $e');
      rethrow;
    }
  }

  // Delete image from Firebase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Delete image error: $e');
      rethrow;
    }
  }

  // Get image size
  static Future<Map<String, int>> getImageDimensions(File image) async {
    try {
      // This is a placeholder - in a real app you'd use a package to get actual dimensions
      return {'width': 1920, 'height': 1080};
    } catch (e) {
      print('Get image dimensions error: $e');
      return {'width': 0, 'height': 0};
    }
  }

  // Validate image file
  static bool isValidImageFile(File file) {
    try {
      final String extension = file.path.toLowerCase().split('.').last;
      final List<String> validExtensions = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
      ];

      if (!validExtensions.contains(extension)) {
        return false;
      }

      // Check file size (max 10MB)
      final int fileSizeInBytes = file.lengthSync();
      final int maxSizeInBytes = 10 * 1024 * 1024; // 10MB

      return fileSizeInBytes <= maxSizeInBytes;
    } catch (e) {
      print('Validate image file error: $e');
      return false;
    }
  }

  // Get file size in human readable format
  static String getFileSizeString(File file) {
    try {
      final int bytes = file.lengthSync();

      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Show image picker options dialog
  static Future<File?> showImagePickerOptions() async {
    // This would typically show a dialog to choose between camera and gallery
    // For now, we'll just return null - this should be implemented in the UI layer
    return null;
  }

  // Batch upload multiple images
  static Future<List<String>> uploadMultipleImages(
    List<File> images,
    String chatId, {
    Function(int, MediaUploadProgress)? onProgress,
  }) async {
    try {
      final List<String> uploadedUrls = [];

      for (int i = 0; i < images.length; i++) {
        final String url = await uploadImage(
          images[i],
          chatId,
          onProgress: (progress) => onProgress?.call(i, progress),
        );
        uploadedUrls.add(url);
      }

      return uploadedUrls;
    } catch (e) {
      print('Upload multiple images error: $e');
      rethrow;
    }
  }

  // Clear cached images (for cleanup)
  static Future<void> clearImageCache() async {
    try {
      // This would clear any locally cached images
      // Implementation depends on caching strategy
    } catch (e) {
      print('Clear image cache error: $e');
    }
  }
}
