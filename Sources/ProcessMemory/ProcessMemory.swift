// The Swift Programming Language
// https://docs.swift.org/swift-book
import Darwin.Mach

public enum MemoryError: Error {
    case failure(String)
    case unknown(Int32, String)
}

func error(_ code: Int32, function: String) -> MemoryError {
    switch code {
    case KERN_FAILURE:
        return .failure(function)
    default:
        return .unknown(code, function)
    }
}

/// Represents memory of a currently running process.
///
/// Use `Memory` to read from or write to process memory.
public struct Memory: CustomStringConvertible {
    var base: mach_vm_address_t
    var pid: pid_t

    public var description: String {
        return "Memory(0x\(String(base, radix: 16)))"
    }

    /// Constructs `Memory` from a given process name.
    public static func from(name: String) -> Memory? {
        guard let processes = getProcessList() else {
            return nil
        }

        guard let pid = processes[name] else {
            return nil
        }

        switch from(pid: pid) {
        case .success(let memory):
            return memory
        case .failure(_):
            return nil
        }
    }

    /// Constructs `Memory` from a given process id.
    public static func from(pid: pid_t) -> Result<Memory, MemoryError> {
        switch getBaseAddress(for: pid) {
        case .success(let addr):
            return .success(Memory(baseAddress: addr, pid: pid))
        case .failure(let error):
            return .failure(error)
        }
    }

    init(baseAddress: mach_vm_address_t, pid: pid_t) {
        self.base = baseAddress
        self.pid = pid
    }
}

func getBaseAddress(for pid: pid_t) -> Result<mach_vm_address_t, MemoryError> {
    var task: mach_port_t = 0
    var result = task_for_pid(mach_task_self_, pid, &task)
    guard result == KERN_SUCCESS else {
        return .failure(error(result, function: "task_for_pid"))
    }

    defer {
        mach_port_deallocate(mach_task_self_, task)
    }

    var address: mach_vm_address_t = 0
    var size: mach_vm_size_t = 0
    var nestingDepth: UInt32 = 0
    var info = vm_region_submap_info_64()
    var infoCount = mach_msg_type_number_t(
        MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size
    )

    result = withUnsafeMutablePointer(to: &info) { infoPtr -> kern_return_t in
        infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) {
            intPtr in
            mach_vm_region_recurse(
                task,
                &address,
                &size,
                &nestingDepth,
                intPtr,
                &infoCount
            )
        }
    }
    guard result == KERN_SUCCESS else {
        return .failure(error(result, function: "mach_vm_region_recurse"))
    }

    return .success(address)
}

func getProcessList() -> [String: pid_t]? {
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    var bufferSize = 0

    // Set the required buffer size
    if sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) < 0 {
        perror(&errno)
        return nil
    }

    let entryCount = bufferSize / MemoryLayout<kinfo_proc>.stride

    var processList: UnsafeMutablePointer<kinfo_proc>?
    processList = UnsafeMutablePointer.allocate(capacity: bufferSize)
    defer { processList?.deallocate() }

    if sysctl(&mib, UInt32(mib.count), processList, &bufferSize, nil, 0) < 0 {
        perror(&errno)
        return nil
    }

    var processMap = [String: pid_t]()
    for index in 0...entryCount {
        guard var process = processList?[index].kp_proc, process.p_pid != 0 else {
            continue
        }

        let name = withUnsafePointer(to: &process.p_comm) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: $0)) {
                String(cString: $0)
            }
        }

        processMap[name] = process.p_pid
    }

    return processMap
}
