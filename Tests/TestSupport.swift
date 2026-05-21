import Foundation

/// Test helper that advances time deterministically.
final class TestClock: @unchecked Sendable {
    private(set) var now: Date
    init(start: Date) { self.now = start }
    func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

final class TestRunner {
    private(set) var passed = 0
    private(set) var failed = 0
    private var currentName = ""
    private var currentFailures: [String] = []

    func run(_ name: String, _ body: () throws -> Void) {
        currentName = name
        currentFailures = []
        do {
            try body()
        } catch {
            currentFailures.append("threw: \(error)")
        }
        if currentFailures.isEmpty {
            passed += 1
            FileHandle.standardOutput.write("  ✓ \(name)\n".data(using: .utf8)!)
        } else {
            failed += 1
            FileHandle.standardOutput.write("  ✗ \(name)\n".data(using: .utf8)!)
            for f in currentFailures {
                FileHandle.standardOutput.write("      \(f)\n".data(using: .utf8)!)
            }
        }
    }

    func section(_ name: String) {
        FileHandle.standardOutput.write("\n\(name)\n".data(using: .utf8)!)
    }

    func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
        if a != b {
            currentFailures.append("\(file):\(line) — \(msg.isEmpty ? "values differ" : msg): expected \(b), got \(a)")
        }
    }

    func assertNil<T>(_ value: T?, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
        if value != nil {
            currentFailures.append("\(file):\(line) — \(msg.isEmpty ? "expected nil" : msg): got \(value!)")
        }
    }

    func assertNotNil<T>(_ value: T?, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
        if value == nil {
            currentFailures.append("\(file):\(line) — \(msg.isEmpty ? "expected non-nil" : msg)")
        }
    }

    func assertTrue(_ condition: Bool, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
        if !condition {
            currentFailures.append("\(file):\(line) — \(msg.isEmpty ? "expected true" : msg)")
        }
    }

    func assertThrows<E: Error & Equatable>(_ expected: E, _ body: () throws -> Void, file: StaticString = #file, line: UInt = #line) {
        do {
            try body()
            currentFailures.append("\(file):\(line) — expected throw \(expected), did not throw")
        } catch let e as E {
            if e != expected {
                currentFailures.append("\(file):\(line) — wrong error: expected \(expected), got \(e)")
            }
        } catch {
            currentFailures.append("\(file):\(line) — wrong error type: expected \(expected), got \(error)")
        }
    }

    func assertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #file, line: UInt = #line) {
        if !(a > b) {
            currentFailures.append("\(file):\(line) — \(msg.isEmpty ? "expected \(a) > \(b)" : msg)")
        }
    }

    func summarize() -> Int32 {
        let total = passed + failed
        FileHandle.standardOutput.write("\n\(passed)/\(total) passed".data(using: .utf8)!)
        if failed > 0 {
            FileHandle.standardOutput.write(", \(failed) failed\n".data(using: .utf8)!)
            return 1
        } else {
            FileHandle.standardOutput.write(" ✓\n".data(using: .utf8)!)
            return 0
        }
    }
}
