import ArgumentParser
import Foundation
import ProcessMemory

extension ArraySlice where Element: Comparable {
    func get(atIndex: Index) -> Element? {
        return indices.contains(atIndex) ? self[atIndex] : nil
    }
}

extension Data {
    func toInt<T: FixedWidthInteger>(type: T.Type) -> T? {
        guard self.count >= MemoryLayout<T>.size else { return nil }
        return self.withUnsafeBytes { $0.load(as: T.self) }
    }
}

struct Offset: ExpressibleByArgument {
    let value: UInt64

    init?(argument: String) {
        if argument.hasPrefix("0x") || argument.hasPrefix("0X") {
            self.value = UInt64(argument.dropFirst(2), radix: 16) ?? 0
        } else {
            self.value = UInt64(argument) ?? 0
        }
    }
}

@main
struct Mem: ParsableCommand {
    @Option(name: .long, help: "The name of the process.")
    var name: String? = nil
    @Option(name: .long, help: "The PID of the process.")
    var pid: String? = nil
    @Option(name: .long, help: "The memory offset for reading.")
    var offset: Offset?

    mutating func run() {
        var memory: Memory?

        if let name {
            switch Memory.from(name: name) {
            case .some(let mem):
                memory = mem
            case .none:
                print("process \(name) not found")
            }
        }

        if let pid, let pid = Int32(pid) {
            switch Memory.from(pid: pid) {
            case .success(let mem):
                memory = mem
            case .failure(let error):
                print(error)
            }
        }

        guard let memory else {
            return
        }

        print(memory)

        if let offset {
            guard let data = memory.readAt(offset: offset.value) else {
                return
            }

            guard let value = data.toInt(type: Int32.self) else {
                return
            }

            print(value)
        }
    }
}
