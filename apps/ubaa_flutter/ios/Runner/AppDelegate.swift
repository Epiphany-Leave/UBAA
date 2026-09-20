import Flutter
import UIKit
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var calendar: DeviceCalendarChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    calendar = DeviceCalendarChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

// Device calendar only. No school requests, persistence, logging or direct saves.
private final class DeviceCalendarChannel: NSObject, EKEventEditViewDelegate {
  private let store = EKEventStore()
  private let channel: FlutterMethodChannel
  private var pendingEdit: FlutterResult?
  private var requesting = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "cn.edu.buaa.ubaa/platform", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result: result) }
  }

  private var readable: Bool {
    if #available(iOS 17.0, *) {
      return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    return EKEventStore.authorizationStatus(for: .event) == .authorized
  }

  private func requestRead(_ result: @escaping FlutterResult) {
    if readable { result(true); return }
    if requesting { result(FlutterError(code: "calendar_busy", message: "日历授权正在进行", details: nil)); return }
    requesting = true
    let completion: (Bool, Error?) -> Void = { [weak self] granted, _ in
      DispatchQueue.main.async { self?.requesting = false; result(granted) }
    }
    if #available(iOS 17.0, *) { store.requestFullAccessToEvents(completion: completion) }
    else { store.requestAccess(to: .event, completion: completion) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "calendar.capability": result(true)
    case "calendar.requestRead": requestRead(result)
    case "calendar.read": read(call.arguments, result: result)
    case "calendar.edit": edit(call.arguments, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func interval(_ args: [String: Any]) -> (Date, Date)? {
    guard let start = args["startMs"] as? NSNumber,
      let end = args["endMs"] as? NSNumber,
      start.doubleValue >= 0, end.doubleValue > start.doubleValue,
      end.doubleValue <= 253402300799000 else { return nil }
    return (Date(timeIntervalSince1970: start.doubleValue / 1000),
            Date(timeIntervalSince1970: end.doubleValue / 1000))
  }

  private func read(_ arguments: Any?, result: @escaping FlutterResult) {
    guard readable else {
      result(FlutterError(code: "calendar_denied", message: "未获得日历读取权限，未完成检测", details: nil)); return
    }
    guard let args = arguments as? [String: Any], let (start, end) = interval(args),
      end.timeIntervalSince(start) <= 366 * 86400 else {
      result(FlutterError(code: "calendar_time", message: "课程时间无效，未完成检测", details: nil)); return
    }
    // EventKit expands recurring events and resolves all-day dates in its predicate.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      let readStore = EKEventStore()
      let predicate = readStore.predicateForEvents(withStart: start, end: end, calendars: nil)
      let events = readStore.events(matching: predicate).filter { $0.status != .canceled }
      let rows: [[String: Any]] = events.prefix(10001).map { event in
        ["startMs": Int64(event.startDate.timeIntervalSince1970 * 1000),
         "endMs": Int64(event.endDate.timeIntervalSince1970 * 1000),
         "title": event.title ?? "未命名日程", "location": event.location ?? "",
         "calendar": event.calendar.title ?? "日历", "allDay": event.isAllDay,
         "free": event.availability == .free]
      }
      DispatchQueue.main.async { [self] in
        guard readable, rows.count <= 10000 else {
          result(FlutterError(code: "calendar_read", message: "日历读取未完成，请检查权限后重试", details: nil)); return
        }
        result(rows)
      }
    }
  }

  private func edit(_ arguments: Any?, result: @escaping FlutterResult) {
    guard pendingEdit == nil else {
      result(FlutterError(code: "calendar_busy", message: "日历编辑页已打开", details: nil)); return
    }
    guard let args = arguments as? [String: Any], let (start, end) = interval(args),
      let title = args["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(FlutterError(code: "calendar_time", message: "日程内容无效", details: nil)); return
    }
    // iOS 17 can present the system editor without calendar access. Older iOS
    // requires event-store access; refusing it still leaves school selection usable.
    if #available(iOS 17.0, *) {} else if !readable {
      requestRead { [weak self] granted in
        guard granted as? Bool == true else {
          result(FlutterError(code: "calendar_denied", message: "此系统版本需要日历权限才能打开编辑页", details: nil)); return
        }
        self?.edit(arguments, result: result)
      }
      return
    }
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    guard var presenter = window?.rootViewController else {
      result(FlutterError(code: "calendar_edit", message: "无法打开系统日历编辑页", details: nil)); return
    }
    while let next = presenter.presentedViewController { presenter = next }
    let event = EKEvent(eventStore: store)
    event.title = title; event.startDate = start; event.endDate = end
    event.timeZone = TimeZone(identifier: "Asia/Shanghai")
    event.location = args["location"] as? String
    event.notes = args["description"] as? String
    if let minutes = args["reminderMinutes"] as? NSNumber {
      event.addAlarm(EKAlarm(relativeOffset: -minutes.doubleValue * 60))
    }
    let editor = EKEventEditViewController()
    editor.eventStore = store; editor.event = event; editor.editViewDelegate = self
    editor.isModalInPresentation = true
    pendingEdit = result
    presenter.present(editor, animated: true)
  }

  func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    let result = pendingEdit
    pendingEdit = nil
    controller.dismiss(animated: true) { result?(action == .saved ? "saved" : "cancelled") }
  }
}
