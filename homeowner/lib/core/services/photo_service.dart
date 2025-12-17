import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick multiple images from gallery
  static Future<List<File>> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      print('Error picking images: $e');
      return [];
    }
  }

  /// Take a photo with camera
  static Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  /// Convert file to base64 string
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting file to base64: $e');
      return '';
    }
  }

  /// Pick single image from gallery
  static Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
}
