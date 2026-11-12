import UIKit
import UserNotifications
import BackgroundTasks

/// جالب الإشعارات الأصلية — محاكاة Poller.java في أندرويد المعتمد v1.1.0:
/// - يجلب آخر 50 إشعاراً من /api/notifications برأس x-auth-token
///   (التوكن المستخرج من جلسة الويب داخل التطبيق)
/// - يصدر إشعارات iOS أصلية للجديد غير المقروء فقط مع تتبع المشاهدات (حد 500)
/// - نبض أمامي كل 4 دقائق + تحديث خلفي BGAppRefreshTask كل ~15 دقيقة
/// ملاحظة أبل: الجلب الخلفي من جدولة iOS وليس خدمة دائمة كأندرويد؛
/// الحل الأمثل مستقبلاً هو APNs من الخادم — البنية جاهزة له دون تغيير الواجهة.
final class NotificationPoller {

    static let shared = NotificationPoller()
    private init() {}

    // MARK: — الحالة

    private var timer: Timer?
    private let seen = SeenStore()
    /// يُعيَّن من AppDelegate بعد استجابة إذن الإشعارات
    var notificationsAuthorized = false

    // MARK: — التسجيل والجدولة

    /// التسجيل لمهمة التحديث الخلفي — يجب أن يُستدعى قبل نهاية didFinishLaunching
    func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Config.bgRefreshTaskID,
                                        using: nil) { [weak self] task in
            self?.handleBackgroundRefresh(task as! BGAppRefreshTask)
        }
    }

    /// جدولة الدورة الخلفية القادمة (~15 دقيقة — تقديرية حسب قرار النظام)
    func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Config.bgRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// نبض المقدمة — يُستأنف عند العودة للتطبيق ويُوقف عند الخلفية
    func startForegroundPolling() {
        stopForegroundPolling()
        timer = Timer.scheduledTimer(withTimeInterval: Config.foregroundPollInterval,
                                     repeats: true) { [weak self] _ in
            self?.pollNow()
        }
    }

    func stopForegroundPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: — الجلب

    /// دورة جلب واحدة. تُستدعى من: النبض الأمامي، التحديث الخلفي،
    /// أول إطلاق بعد منح الإذن، والعودة للتطبيق.
    func pollNow(completion: ((UIBackgroundFetchResult) -> Void)? = nil) {
        let token = UserDefaults.standard.string(forKey: Config.storedTokenKey) ?? ""
        guard !token.isEmpty else {
            completion?(.noData)
            return
        }

        var request = URLRequest(url: Config.baseURL.appendingPathComponent("api/notifications"))
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "x-auth-token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { completion?(.failed); return }
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let data = data else {
                completion?(.failed)
                return
            }
            self.process(data: data, completion: completion)
        }.resume()
    }

    private func process(data: Data, completion: ((UIBackgroundFetchResult) -> Void)?) {
        struct Payload: Decodable {
            let notifications: [Notif]
            let unread: Int?
        }
        struct Notif: Decodable {
            let id: String
            let read: Bool
            let title: String?
            let titles: [String: String]?
            let body: String?
            let bodies: [String: String]?

            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case read, title, titles, body, bodies
            }
        }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            completion?(.failed)
            return
        }

        // الجديد غير المقروء فقط — نفس منطق أندرويد
        let fresh = payload.notifications.filter { !seen.contains($0.id) && !$0.read }
        seen.record(ids: payload.notifications.map { $0.id })

        if notificationsAuthorized {
            deliver(fresh)
        }

        // شارة الأيقونة = عدد غير المقروء من الخادم
        let unread = payload.unread ?? payload.notifications.filter { !$0.read }.count
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = max(0, unread)
        }

        completion?(fresh.isEmpty ? .noData : .newData)
    }

    // MARK: — الإصدار

    private func deliver(_ items: [Notif]) {
        guard !items.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = localized(from: item.titles, fallback: item.title)
            content.body = localized(from: item.bodies, fallback: item.body)
            content.sound = .default
            content.threadIdentifier = "ait-notifications"
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: nil)
            center.add(request)
        }
    }

    /// اختيار النص بلغة الجهاز من خريطة {ar, fr, en, tr, es} — نفس pickLocalized في أندرويد
    private func localized(from map: [String: String]?, fallback: String?) -> String {
        if let map = map, !map.isEmpty {
            let value = map[L10n.lang]
            if let value = value, !value.isEmpty { return value }
            if let value = map["ar"], !value.isEmpty { return value }
        }
        return fallback ?? ""
    }

    // MARK: — المهمة الخلفية

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        scheduleNextBackgroundRefresh()
        /* ضمان نداء setTaskCompleted مرة واحدة (انتهاء الوقت أو اكتمال الجلب) */
        var completed = false
        let finish = { (success: Bool) in
            if !completed {
                completed = true
                task.setTaskCompleted(success: success)
            }
        }
        task.expirationHandler = { finish(false) }
        pollNow { result in
            finish(result != .failed)
        }
    }
}
