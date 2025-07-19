import 'dart:io';
import 'package:camera/camera.dart';
import 'package:face_detection_application/face_detection_painter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class Live_Detection_Screen extends StatefulWidget {
  const Live_Detection_Screen({super.key});

  @override
  State<Live_Detection_Screen> createState() => _Live_Detection_SStatecreen();
}

class _Live_Detection_SStatecreen extends State<Live_Detection_Screen> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool isDetecting = false;
  List<Face> _faces = [];
  List<CameraDescription> cameras = [];
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeCameras();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      print('Permission denied. Please enable camera permission in settings.');
    }
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No Cameras found.');
      }
      _selectedCameraIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 1;
      }
      await _initializeCamera(cameras[_selectedCameraIndex]);
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    _cameraController = controller;

    _initializeControllerFuture = controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _startFaceDetection();
          });
        })
        .catchError((error) {
          print('Error initializing camera: $error');
        });
  }

  void _toggleCamera() async {
    if (cameras.isEmpty || cameras.length < 2) {
      print('No secondary camera available to switch.');
      return;
    }

    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;

    setState(() {
      _faces = [];
    });

    await _initializeCamera(cameras[_selectedCameraIndex]);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    try {
      final format =
          Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.values.firstWhere(
          (element) =>
              element.rawValue ==
              _cameraController!.description.sensorOrientation,
          orElse: () => InputImageRotation.rotation0deg,
        ),
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final bytes = _concatenatePlanes(image.planes);
      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera is not initialized.');
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (isDetecting) return;
      isDetecting = true;
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        isDetecting = false;
        return;
      }

      try {
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        if (mounted) {
          setState(() {
            _faces = faces;
          });
        }
      } catch (e) {
        print('Error converting camera image: $e');
      } finally {
        isDetecting = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera Detection'),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.switch_camera,
              color: Colors.blueAccent,
            ),
            onPressed: _toggleCamera,
            color: Colors.blueAccent,
          ),
        ],
      ),
      body:
          _initializeControllerFuture == null
              ? Center(child: Text('No Camera Available'))
              : FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      _cameraController != null &&
                      _cameraController!.value.isInitialized) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        CustomPaint(
                          painter: FaceDetectionPainter(
                            faces: _faces,
                            imageSize: Size(
                              _cameraController!.value.previewSize!.height,
                              _cameraController!.value.previewSize!.width,
                            ),
                            cameraLensDirection:
                                _cameraController!.description.lensDirection,
                          ),
                        ),
                        Positioned(
                          bottom: 20.0,
                          left: 0.0,
                          right: 0.0,
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Text(
                                'Detected Faces: ${_faces.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
    );
  }
}
