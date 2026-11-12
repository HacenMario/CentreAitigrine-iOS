import UIKit
import UserNotifications
import BackgroundTasks

/// نقطتا الدخول — دورة حياة AppDelegate الكلاسيكية (بلا مشاهد Scenes)
/// لضمان سلوك موحّد والاحتفاظ الكامل بجلسة الويب بين الإطلاقات.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = WebViewController()
        win.backgroundColor = Theme.background
        win.makeKeyAndVisible()
        window = win

        // تسجيل مهمة التحديث الخلفي + جدولة الدورة القادمة (إشعارات أصلية)
        NotificationPoller.shared.registerBackgroundRefresh()
        NotificationPoller.shared.scheduleNextBackgroundRefresh()

        // طلب إذن الإشعارات بهدوء عند أول إطلاق، ثم نبضة أولى بعد الاستقرار
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            NotificationPoller.shared.notificationsAuthorized = granted
            if granted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    NotificationPoller.shared.pollNow()
                }
            }
        }

        return true
    }

    // الاتجاهات: كل شيء ما عدا الرأسي المقلوب (آيفون) — والآيباد كامل
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .allButUpsideDown
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // نبضة فور العودة + استئناف النبض الأمامي (كل 4 دقائق)
        NotificationPoller.shared.pollNow()
        NotificationPoller.shared.startForegroundPolling()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationPoller.shared.stopForegroundPolling()
        NotificationPoller.shared.scheduleNextBackgroundRefresh()
    }

    /// جلب الخلفي الكلاسيكي — يتكامل مع BGTaskScheduler لنفس الغرض
    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationPoller.shared.pollNow { result in
            NotificationPoller.shared.scheduleNextBackgroundRefresh()
            completionHandler(result)
        }
    }
}
