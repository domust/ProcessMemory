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

    public var description: String {
        return "Memory(0x\(String(base, radix: 16)))"
    }

    /// Constructs `Memory` from a given process id.
    public static func from(pid: pid_t) -> Result<Memory, MemoryError> {
        switch getBaseAddress(for: pid) {
        case .success(let addr):
            return .success(Memory(baseAddress: addr))
        case .failure(let error):
            return .failure(error)
        }
    }

    init(baseAddress: mach_vm_address_t) {
        self.base = baseAddress
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
