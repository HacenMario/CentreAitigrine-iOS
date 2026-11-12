import Foundation
import UIKit

/// نصوص واجهة التطبيق الأصلية بالخمس لغات المعتمدة بالموقع (ar, fr, en, tr, es).
/// لغة الجهاز هي المرجع، والعربية هي الافتراضي (الموقع عربي أولاً).
enum L10n {

    /// رمز لغة الجهاز الحالي (حرفان) — من لغات الموقع وإلا "ar"
    static let lang: String = {
        let code = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "ar"
        return ["ar", "fr", "en", "tr", "es"].contains(code) ? String(code) : "ar"
    }()

    /// جلب نص بمفتاحه بلغة الجهاز (يfallback إلى العربية)
    static func text(_ table: [String: String]) -> String {
        table[L10n.lang] ?? table["ar"] ?? ""
    }

    enum Offline {
        static let title = text([
            "ar": "لا يوجد اتصال بالإنترنت",
            "fr": "Pas de connexion Internet",
            "en": "No Internet connection",
            "tr": "İnternet bağlantısı yok",
            "es": "Sin conexión a Internet"
        ])
        static let message = text([
            "ar": "تحقق من اتصالك بالشبكة ثم أعد المحاولة. سيحاول التطبيق الولوج تلقائياً فور عودة الاتصال.",
            "fr": "Vérifiez votre connexion réseau puis réessayez. L'application réessaiera automatiquement dès le retour du réseau.",
            "en": "Check your network connection and try again. The app will reconnect automatically once the network is back.",
            "tr": "Ağ bağlantınızı kontrol edin ve tekrar deneyin. Uygulama, ağ döndüğünde otomatik olarak yeniden bağlanacaktır.",
            "es": "Compruebe su conexión de red e inténtelo de nuevo. La aplicación se reconectará automáticamente cuando vuelva la red."
        ])
        static let retry = text([
            "ar": "إعادة المحاولة",
            "fr": "Réessayer",
            "en": "Retry",
            "tr": "Tekrar dene",
            "es": "Reintentar"
        ])
    }

    enum Dialog {
        static let ok = text([
            "ar": "حسناً",
            "fr": "OK",
            "en": "OK",
            "tr": "Tamam",
            "es": "Aceptar"
        ])
        static let cancel = text([
            "ar": "إلغاء",
            "fr": "Annuler",
            "en": "Cancel",
            "tr": "İptal",
            "es": "Cancelar"
        ])
    }

    /// رسالة الخطأ العامة لأي فشل تحميل غير شامل لانقطاع الشبكة
    static func loadError(code: Int) -> String {
        switch L10n.lang {
        case "fr": return "Impossible de charger la page (code \(code)). Vérifiez la connexion puis réessayez."
        case "en": return "Could not load the page (code \(code)). Check your connection and retry."
        case "tr": return "Sayfa yüklenemedi (kod \(code)). Bağlantınızı kontrol edip tekrar deneyin."
        case "es": return "No se pudo cargar la página (código \(code)). Compruebe la conexión y reintente."
        default: return "تعذر تحميل الصفحة (رمز \(code)). تحقق من الاتصال وأعد المحاولة."
        }
    }
}
