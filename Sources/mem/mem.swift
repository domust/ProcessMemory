import ArgumentParser
import ProcessMemory

extension ArraySlice where Element: Comparable {
    func get(atIndex: Index) -> Element? {
        return indices.contains(atIndex) ? self[atIndex] : nil
    }
}

@main
struct Mem: ParsableCommand {
    @Option(name: .long, help: "The name of the process.")
    var name: String? = nil
    @Option(name: .long, help: "The PID of the process.")
    var pid: String? = nil

    mutating func run() {
        if let name {
            switch Memory.from(name: name) {
            case .some(let memory):
                print(memory)
            case .none:
                print("process \(name) not found")
            }
        }

        if let pid, let pid = Int32(pid) {
            switch Memory.from(pid: pid) {
            case .success(let memory):
                print(memory)
            case .failure(let error):
                print(error)
            }
        }
    }
}
