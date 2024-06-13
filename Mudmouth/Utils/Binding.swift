import SwiftUI

extension Binding {
    public func defaultValue<T>(_ value: T) -> Binding<T> where Value == T? {
        Binding<T> {
            wrappedValue ?? value
        } set: {
            wrappedValue = $0
        }
    }
}
