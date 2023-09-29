//
//  Binding.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/21.
//

import SwiftUI

extension Binding {
    public func defaultValue<T>(_ value: T) -> Binding<T> where Value == Optional<T> {
        Binding<T> {
            wrappedValue ?? value
        } set: {
            wrappedValue = $0
        }
    }
}
