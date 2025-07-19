import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  FaceDetectionPainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final Paint facePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.red;

    final Paint landmarkPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 5.0
          ..color = Colors.red;

    for (var i = 0; i < faces.length; i++) {
      final Face face = faces[i];

      double leftOffset = face.boundingBox.left;
      if (cameraLensDirection == CameraLensDirection.front) {
        leftOffset = imageSize.width - face.boundingBox.right;
      }

      final double left = leftOffset * scaleX;
      final double top = face.boundingBox.top * scaleY;
      final double right = (leftOffset + face.boundingBox.width) * scaleX;
      final double bottom =
          (face.boundingBox.top + face.boundingBox.height) * scaleY;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), facePaint);

      void drawLandmarks(FaceLandmarkType type) {
        if (face.landmarks[type] != null) {
          final point = face.landmarks[type]!.position;
          double pointX = point.x.toDouble();

          if (cameraLensDirection == CameraLensDirection.front) {
            pointX = imageSize.width - pointX;
          }
          canvas.drawCircle(
            Offset(pointX * scaleX, point.y * scaleY),
            4.0,
            landmarkPaint,
          );
        }
      }

      drawLandmarks(FaceLandmarkType.leftEye);
      drawLandmarks(FaceLandmarkType.rightEye);
      drawLandmarks(FaceLandmarkType.noseBase);
      drawLandmarks(FaceLandmarkType.leftMouth);
      drawLandmarks(FaceLandmarkType.rightMouth);
    }
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
