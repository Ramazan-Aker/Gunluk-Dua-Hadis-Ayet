import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let mediaChannelName = "com.tahram.gunlukduahadis/media"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureMediaChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureMediaChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: mediaChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveImageToPhotoLibrary" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let imageData = (call.arguments as? FlutterStandardTypedData)?.data else {
        result(FlutterError(
          code: "invalid_image",
          message: "Kaydedilecek görsel verisi bulunamadı.",
          details: nil
        ))
        return
      }

      self?.saveImageToPhotoLibrary(imageData, result: result)
    }
  }

  private func saveImageToPhotoLibrary(_ imageData: Data, result: @escaping FlutterResult) {
    guard let image = UIImage(data: imageData) else {
      result(FlutterError(
        code: "invalid_image",
        message: "Görsel dosyası okunamadı.",
        details: nil
      ))
      return
    }

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "photo_permission_denied",
            message: "Görseli kaydetmek için Fotoğraflar izni gerekli.",
            details: nil
          ))
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(true)
          } else {
            result(FlutterError(
              code: "photo_save_failed",
              message: error?.localizedDescription ?? "Görsel Fotoğraflar arşivine kaydedilemedi.",
              details: nil
            ))
          }
        }
      }
    }
  }
}
