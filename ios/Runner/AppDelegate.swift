import UIKit
import Flutter
import AutomaticAssessmentConfiguration

@available(iOS 13.4, *)
class AssessmentManager: NSObject, AEAssessmentSessionDelegate {
  private var session: AEAssessmentSession?
  private var pendingStartResult: FlutterResult?

  func start(result: @escaping FlutterResult) {
    if pendingStartResult != nil {
      result(FlutterError(code: "START_IN_PROGRESS", message: "Assessment start is already in progress", details: nil))
      return
    }

    let configuration = AEAssessmentConfiguration()
    let newSession = AEAssessmentSession(configuration: configuration)
    newSession.delegate = self
    session = newSession
    pendingStartResult = result
    newSession.begin()
  }

  func stop(result: @escaping FlutterResult) {
    session?.end()
    session = nil
    pendingStartResult = nil
    result("ENDED")
  }

  func state(result: FlutterResult) {
    result(session?.isActive == true ? "ACTIVE" : "INACTIVE")
  }

  func assessmentSessionDidBegin(_ session: AEAssessmentSession) {
    pendingStartResult?("STARTED")
    pendingStartResult = nil
  }

  func assessmentSession(_ session: AEAssessmentSession, failedToBeginWithError error: Error) {
    pendingStartResult?(FlutterError(
      code: "START_FAILED",
      message: error.localizedDescription,
      details: [
        "domain": (error as NSError).domain,
        "code": (error as NSError).code,
      ]
    ))
    pendingStartResult = nil
    self.session = nil
  }

  func assessmentSessionDidEnd(_ session: AEAssessmentSession) {
    self.session = nil
  }
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  var manager: Any?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 13.4, *) {
      manager = AssessmentManager()
    }
    
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "exam_channel",
                                       binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "startAssessment":
            self?.startAssessment(result: result)
        case "endAssessment":
            self?.endAssessment(result: result)
        case "getIOSVersion":
            self?.getIOSVersion(result: result)
        case "getAssessmentState":
          self?.getAssessmentState(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  func startAssessment(result: @escaping FlutterResult) {
    #if targetEnvironment(simulator)
    result(FlutterError(code: "UNSUPPORTED_SIMULATOR", message: "AAC is not supported on iOS Simulator. Test on a physical iPhone/iPad.", details: nil))
    return
    #endif

    if #available(iOS 13.4, *),
       let mgr = manager as? AssessmentManager {
      mgr.start(result: result)
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "Use Guided Access", details: nil))
    }
  }
  
  func endAssessment(result: @escaping FlutterResult) {
    if #available(iOS 13.4, *),
       let mgr = manager as? AssessmentManager {
      mgr.stop(result: result)
    } else {
      result(FlutterError(code: "UNSUPPORTED", message: "iOS version not supported", details: nil))
    }
  }
  
  func getIOSVersion(result: FlutterResult) {
    let components = UIDevice.current.systemVersion.split(separator: ".")
    let major = Double(components.first ?? "0") ?? 0
    let minor = components.count > 1 ? (Double(components[1]) ?? 0) : 0
    result(major + (minor / 10.0))
  }

  func getAssessmentState(result: FlutterResult) {
    if #available(iOS 13.4, *),
       let mgr = manager as? AssessmentManager {
      mgr.state(result: result)
    } else {
      result("INACTIVE")
    }
  }
}
