import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let server = PhotoBridgeServer()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainViewController()
        window?.makeKeyAndVisible()

        // Bắt đầu TCP server ngay khi app mở
        server.start()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Xin thêm thời gian chạy nền
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = application.beginBackgroundTask {
            application.endBackgroundTask(bgTask)
        }
    }
}
