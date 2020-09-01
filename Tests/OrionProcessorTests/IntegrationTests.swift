import XCTest
@testable import OrionProcessor

final class IntegrationTests: XCTestCase {
    func testIntegration() throws {
        let contents = #"""
        import Orion
        import Foundation

        class MyFunctionHook: FunctionHook {
            static let target = Function(image: nil, name: "socket")

            func function(foo: Int32, bar: Int32) -> Int32 {
                typealias Foo = @convention(c) () -> Void
                _ = orig { function(foo: foo, bar: bar) }
                return 1
            }
        }

        class MyHook: NamedClassHook<NSObject> {
            static let targetName = "NSDateFormatter"

            func string(fromDate date: Date) -> String {
                let actual = orig { string(fromDate: date) }
                return "Swizzled: '\(actual)'"
            }

            @objc(localizedStringFromDate:dateStyle:timeStyle:)
            class func localizedString(
                from date: Date, dateStyle dstyle: DateFormatter.Style, timeStyle tstyle: DateFormatter.Style
            ) -> String {
                "Class method: \(orig { localizedString(from: date, dateStyle: dstyle, timeStyle: tstyle) })"
            }
        }

        class SuperHook: ClassHook<MyClass> {
            func description() -> String {
                "hax"
            }
        }
        """#

        let generated = #"""
        import Orion
        import Foundation
        import Orion
        import Foundation

        private final class Orion_ClassHook1: MyHook, ConcreteClassHook {
            static let callState = CallState<ClassRequest>()
            let callState = CallState<ClassRequest>()

            private static var orion_orig1: @convention(c) (Target, Selector, Date) -> String = { target, _cmd, arg1 in
                Orion_ClassHook1(target: target).string(fromDate:)(arg1)
            }
            private static let orion_sel1 = #selector(string(fromDate:) as (Self) -> (Date) -> String)
            @objc override func string(fromDate arg1: Date) -> String {
                switch callState.fetchRequest() {
                case nil:
                    return super.string(fromDate:)(arg1)
                case .origCall:
                    return Self.orion_orig1(target, Self.orion_sel1, arg1)
                case .superCall:
                    return callSuper((@convention(c) (UnsafeRawPointer, Selector, Date) -> String).self) { $0($1, Self.orion_sel1, arg1) }
                }
            }

            private static var orion_orig2: @convention(c) (AnyClass, Selector, Date, DateFormatter.Style, DateFormatter.Style) -> String = { target, _cmd, arg1, arg2, arg3 in
                Orion_ClassHook1.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
            }
            private static let orion_sel2 = #selector(localizedString(from:dateStyle:timeStyle:) as (Date, DateFormatter.Style, DateFormatter.Style) -> String)
            @objc(localizedStringFromDate:dateStyle:timeStyle:)
                class override func localizedString(
                    from arg1: Date, dateStyle arg2: DateFormatter.Style, timeStyle arg3: DateFormatter.Style
                ) -> String {
                switch callState.fetchRequest() {
                case nil:
                    return super.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
                case .origCall:
                    return Self.orion_orig2(target, Self.orion_sel2, arg1, arg2, arg3)
                case .superCall:
                    return callSuper((@convention(c) (UnsafeRawPointer, Selector, Date, DateFormatter.Style, DateFormatter.Style) -> String).self) { $0($1, Self.orion_sel2, arg1, arg2, arg3) }
                }
            }

            static func activate(withBackend backend: Backend) {
                register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
                register(backend, orion_sel2, &orion_orig2, isClassMethod: true)
            }
        }

        private final class Orion_ClassHook2: SuperHook, ConcreteClassHook {
            static let callState = CallState<ClassRequest>()
            let callState = CallState<ClassRequest>()

            private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
                Orion_ClassHook2(target: target).description()
            }
            private static let orion_sel1 = #selector(description as (Self) -> () -> String)
            @objc override func description() -> String {
                switch callState.fetchRequest() {
                case nil:
                    return super.description()
                case .origCall:
                    return Self.orion_orig1(target, Self.orion_sel1)
                case .superCall:
                    return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
                }
            }

            static func activate(withBackend backend: Backend) {
                register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
            }
        }

        private final class Orion_FunctionHook1: MyFunctionHook, ConcreteFunctionHook {
            let callState = CallState<FunctionRequest>()

            static var origFunction: @convention(c) (Int32, Int32) -> Int32 = { arg1, arg2 in
                Orion_FunctionHook1().function(foo:bar:)(arg1, arg2)
            }

            override func function(foo arg1: Int32, bar arg2: Int32) -> Int32 {
                switch callState.fetchRequest() {
                case nil:
                    return super.function(foo:bar:)(arg1, arg2)
                case .origCall:
                    return Self.origFunction(arg1, arg2)
                }
            }
        }

        @_cdecl("__orion_constructor")
        func __orion_constructor() {
            DefaultTweak().activate(
                backend: InternalBackend(),
                hooks: [
                    Orion_ClassHook1.self,
                    Orion_ClassHook2.self,
                    Orion_FunctionHook1.self
                ]
            )
        }
        """#

        let parser = OrionParser(contents: contents)
        let data = try parser.parse()
        let generator = OrionGenerator(data: data)
        let source = try generator.generate(backend: .internal)

        XCTAssertEqual(source, generated)
    }

    static var allTests = [
        ("testIntegration", testIntegration),
    ]
}
