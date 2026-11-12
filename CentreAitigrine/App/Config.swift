import Foundation

/// إعدادات مثبّتة داخل التطبيق — لا يُطلب من المستخدم أي إدخال.
/// رابط الموقع الرسمي مدمج تلقائياً ويعمل فور فتح التطبيق.
/// (محاكاة Config.java في تطبيق أندرويد المعتمد v1.1.0)
enum Config {

    /// الرابط الرسمي لموقع مركز آيت تقرين (النطاق الرسمي كما طلبه صاحب المركز).
    /// لتغييره: عدّل هذا السطر فقط (مثال النسخة على Vercel:
    /// https://centrepsy-aitigrine.vercel.app)
    static let baseURL = URL(string: "https://centreaitigrine.com")!

    /// مفتاح التوكن في localStorage بالموقع (src/lib/client-api.ts → TOKEN_KEY).
    /// يستخرجه التطبيق من صفحة الويب بعد الولوج ليستعمله في جلب الإشعارات الأصلية.
    static let webTokenKey = "ait_token"

    /// مفتاح تخزين التوكن في UserDefaults داخل التطبيق
    static let storedTokenKey = "ait_auth_token"

    /// معرّف مهمة التحديث الخلفي (BGTaskScheduler) — مطابق لـ Info.plist
    static let bgRefreshTaskID = "com.aittegrine.center.refresh"

    /// دورة نبض الإشعارات في المقدمة — نفس أندرويد (4 دقائق)
    static let foregroundPollInterval: TimeInterval = 240

    /// إصدار التطبيق
    static let appVersion = "1.0.1"

    /// النطاقات الداخلية المسموح بفتحها داخل التطبيق (كل ما عداها يفتح في سفاري)
    static func isInternalHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        if host == "centreaitigrine.com" || host.hasSuffix(".centreaitigrine.com") { return true }
        // للتجربة المحلية أثناء التطوير (عند تغيير baseURL إلى localhost)
        if host == "localhost" || host.hasPrefix("127.") || host.hasPrefix("192.168.") { return true }
        return false
    }
}
