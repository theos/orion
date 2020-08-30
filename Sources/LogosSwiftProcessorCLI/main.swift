import Foundation
import LogosSwiftProcessor

//let contents = #"""
//import LogosSwift
//import Foundation
//
//class MyFunctionHook: FunctionHook {
//    static let target = Function(image: nil, name: "socket")
//
//    func function(foo: Int32, bar: Int32) -> Int32 {
//        typealias Foo = @convention(c) () -> Void
//        _ = orig { function(foo: foo, bar: bar) }
//        return 1
//    }
//}
//
//class MyHook: NamedClassHook<NSObject> {
//    static let targetName = "NSDateFormatter"
//
//    func string(fromDate date: Date) -> String {
//        let actual = orig { string(fromDate: date) }
//        return "Swizzled: '\(actual)'"
//    }
//
//    @objc(localizedStringFromDate:dateStyle:timeStyle:)
//    class func localizedString(
//        from date: Date, dateStyle dstyle: DateFormatter.Style, timeStyle tstyle: DateFormatter.Style
//    ) -> String {
//        "Class method: \(orig { localizedString(from: date, dateStyle: dstyle, timeStyle: tstyle) })"
//    }
//}
//
//struct MyTweak: Tweak {
////    let backend: Backend = MyBackend()
//}
//"""#

//let parser = LogosParser(contents: contents)

guard CommandLine.argc == 2 else {
    fputs("Usage: \(CommandLine.arguments[0]) <file.swift>\n", stderr)
    exit(EX_USAGE)
}

let file = URL(fileURLWithPath: CommandLine.arguments[1])

let parser = LogosParser(file: file)
parser.addDiagnosticConsumer(kind: .printing)
let data = try parser.parse()

let generator = LogosGenerator(data: data)
let companion = try generator.generate(backend: "InternalBackend", backendModule: nil)

print(companion)
