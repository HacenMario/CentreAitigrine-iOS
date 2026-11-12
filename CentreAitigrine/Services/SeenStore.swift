import Foundation

/// تتبّع معرّفات الإشعارات المُشاهدة لمنع التكرار — مطابق لمنطق Poller.java
/// في أندرويد المعتمد: مصفوفة «الأحدث أولاً» بسقف 500 معرّف.
final class SeenStore {

    private let key = "ait_seen_ids"
    private let cap = 500
    private var ordered: [String]
    private var lookup: Set<String>

    init() {
        let raw = UserDefaults.standard.string(forKey: key) ?? "[]"
        let decoded = raw.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }
        ordered = decoded ?? []
        lookup = Set(ordered)
    }

    func contains(_ id: String) -> Bool {
        lookup.contains(id)
    }

    /// تسجيل دفعة معرّفات (الأحدث أولاً) مع إبقاء الأقدم ضمن السقف
    func record(ids newIDs: [String]) {
        var changed = false
        for id in newIDs where !lookup.contains(id) {
            ordered.insert(id, at: 0)
            lookup.insert(id)
            changed = true
        }
        if ordered.count > cap {
            let overflow = Array(ordered[cap...])
            ordered = Array(ordered.prefix(cap))
            for id in overflow { lookup.remove(id) }
            changed = true
        }
        if changed { persist() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(ordered),
              let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }
}
