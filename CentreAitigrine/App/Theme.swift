import UIKit

/// ألوان الهوية — مطابقة لتطبيق أندرويد المعتمد (res/values/colors.xml)
/// ولمتغيرات الموقع (src/app/globals.css).
enum Theme {

    /// brand_primary #007D65 — أخضر مائل للتركواز
    static let primary = UIColor(hex: 0x007D65)

    /// brand_dark #005544
    static let primaryDark = UIColor(hex: 0x005544)

    /// brand_light #E6F3F2
    static let primaryLight = UIColor(hex: 0xE6F3F2)

    /// ic_launcher_background — خلفية بيضاء كما في أيقونة أندرويد المعتمدة
    static let background = UIColor(hex: 0xFFFFFF)
}

extension UIColor {

    /// تهيئة لون من قيمة سداسية عشرية RGB
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
