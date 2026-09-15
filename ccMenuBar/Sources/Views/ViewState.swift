import SwiftUI

/// Drop-in replacement for SwiftUI's `@State`.
///
/// In the macOS 26+ SDKs `@State` is an attached macro whose implementation
/// (`SwiftUIMacros`) ships only inside Xcode.app, so building with the
/// Command Line Tools alone fails with "plugin for module 'SwiftUIMacros'
/// not found". The underlying `State` property wrapper is still part of the
/// SDK, so wrapping it here gives identical behaviour without the macro.
@propertyWrapper
struct ViewState<Value>: DynamicProperty {
    private var state: State<Value>

    init(wrappedValue: Value) {
        state = State(wrappedValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> {
        state.projectedValue
    }
}
