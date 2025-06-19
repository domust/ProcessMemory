import ProcessMemory

extension ArraySlice where Element: Comparable {
    func get(atIndex: Index) -> Element? {
        return indices.contains(atIndex) ? self[atIndex] : nil
    }
}

@main
struct MemMain {
    static func main() {
        let args = CommandLine.arguments.dropFirst()
        guard let pos = args.firstIndex(where: { $0 == "--pid" }) else {
            return
        }

        guard let stringOfPid = args.get(atIndex: pos + 1) else {
            return
        }

        guard let pid = Int32(stringOfPid) else {
            return
        }

        guard let memory = Memory.from(pid: pid) else {
            return
        }

        print(memory)
    }
}
