import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    // Request permission for push notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    // Set up appearance change observer
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateAppIcon),
      name: UIApplication.significantTimeChangeNotification,
      object: nil
    )

    // Initial icon setup
    updateAppIcon()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
                          didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                          fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    Messaging.messaging().appDidReceiveMessage(userInfo)
    completionHandler(.newData)
  }

  @objc private func updateAppIcon() {
    let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
    let iconName = isDarkMode ? "AppIcon-Dark" : nil // nil will use the primary icon

    if UIApplication.shared.alternateIconName != iconName {
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error = error {
          print("Error changing app icon: \(error.localizedDescription)")
        }
      }
    }
  }
}
