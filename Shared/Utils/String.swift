import Foundation

extension String {
    var localizedString: String {
        NSLocalizedString(self, comment: "")
    }
}
