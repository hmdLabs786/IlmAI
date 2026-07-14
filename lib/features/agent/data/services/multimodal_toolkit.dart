import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class MultimodalToolKit {
  const MultimodalToolKit();

  Future<CroppedFile?> cropImage({
    required String sourcePath,
    CropStyle cropStyle = CropStyle.rectangle,
  }) {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      cropStyle: cropStyle,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop for IlmAI',
          toolbarColor: const Color(0xFF1E3A8A),
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop for IlmAI',
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> buildGeminiMultimodalPart(CroppedFile file) async {
    final bytes = await File(file.path).readAsBytes();
    return {
      'inline_data': {
        'mime_type': 'image/jpeg',
        'data': base64Encode(bytes),
      },
    };
  }

  Future<String> buildBase64StringFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  }

  Future<List<int>> buildBytesFromFile(String path) async {
    return File(path).readAsBytes();
  }

  Map<String, dynamic> buildSnapAndSolveRequest({
    required String prompt,
    required String base64Image,
  }) {
    return {
      'model': 'gemini-2.5-flash',
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            },
          ],
        }
      ],
    };
  }

  Map<String, dynamic> buildBoardPaperCheckerRequest({
    required String prompt,
    required List<int> bytes,
  }) {
    return {
      'model': 'gemini-2.5-flash',
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Encode(bytes),
              }
            },
          ],
        }
      ],
    };
  }
}
