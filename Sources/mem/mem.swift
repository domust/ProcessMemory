import ArgumentParser
import Foundation
import ProcessMemory

extension ArraySlice where Element: Comparable {
    func get(atIndex: Index) -> Element? {
        return indices.contains(atIndex) ? self[atIndex] : nil
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
    @Option(name: .long, help: "The memory offset for all subsequent operations.")
    var move: Offset?
    @Option(name: .long, help: "The memory offset to dereference the pointer.")
    var deref: Offset?

    mutating func run() {
        var memory: Memory?

        if let name {
            switch Memory.from(name: name) {
            case .success(let mem):
                memory = mem
            case .failure(let error):
                print("process \(name): \(error)")
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

        guard var memory else {
            return
        }

        print(memory)

        if let move {
            memory = memory.move(offset: move.value)
            print(memory)
        }

        if let deref {
            guard let newMemory = memory.deref(offset: deref.value) else {
                return
            }

            memory = newMemory
            print(memory)
        }

        if let offset {
            guard let value = memory.readInt(offset: offset.value) else {
                return
            }

            print(value)
        }
    }
}
