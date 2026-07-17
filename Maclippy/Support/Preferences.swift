import Foundation

enum Preferences {
    static let historySizeKey = "historySize"
    static let ignoreConcealedKey = "ignoreConcealed"

    static let defaultHistorySize = 20
    static let defaultIgnoreConcealed = true

    static let minHistorySize = 0  // 0 = unlimited
    static let maxHistorySize = 99

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            historySizeKey: defaultHistorySize,
            ignoreConcealedKey: defaultIgnoreConcealed
        ])
    }

    static var historySize: Int {
        UserDefaults.standard.integer(forKey: historySizeKey)
    }

    static var ignoreConcealed: Bool {
        UserDefaults.standard.bool(forKey: ignoreConcealedKey)
    }
}
