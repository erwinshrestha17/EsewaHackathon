import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerMacosVisionOcrChannel(with: flutterViewController)

    super.awakeFromNib()
  }

  private func registerMacosVisionOcrChannel(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "sajha_kharcha/macos_vision_ocr",
      binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeReceipt" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let typedData = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(
          code: "invalid_image",
          message: "Vision OCR expected encoded image bytes.",
          details: nil))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let rows = try Self.recognizeTextRows(in: typedData.data)
          DispatchQueue.main.async {
            result(rows)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "vision_ocr_failed",
              message: "Could not read the bill with macOS Vision OCR.",
              details: error.localizedDescription))
          }
        }
      }
    }
  }

  private static func recognizeTextRows(in data: Data) throws -> [[String: Any]] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if #available(macOS 11.0, *) {
      request.recognitionLanguages = ["en-US"]
    }

    let handler = VNImageRequestHandler(data: data, options: [:])
    try handler.perform([request])

    let observations = request.results ?? []
    return observations
      .sorted {
        if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.01 {
          return $0.boundingBox.minY > $1.boundingBox.minY
        }
        return $0.boundingBox.minX < $1.boundingBox.minX
      }
      .compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else {
          return nil
        }
        return [
          "text": candidate.string,
          "confidence": Double(candidate.confidence),
        ]
      }
  }
}
