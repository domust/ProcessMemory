// The Swift Programming Language
// https://docs.swift.org/swift-book
import Darwin.Mach
import Foundation

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

extension Data {
    func toInt<T: FixedWidthInteger>(type: T.Type) -> T? {
        guard self.count >= MemoryLayout<T>.size else { return nil }
        return self.withUnsafeBytes { $0.load(as: T.self) }
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
    public static func from(name: String) -> Result<Memory, MemoryError> {
        var processes: [String: pid_t]
        switch getProcessList() {
        case .success(let value):
            processes = value
        case .failure(let error):
            return .failure(error)
        }

        guard let pid = processes[name] else {
            return .failure(.failure("process map access"))
        }

        return from(pid: pid)
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

    public func deref(offset: UInt64) -> Memory? {
        guard let data = readMemory(for: self.pid, from: self.base, at: offset, size: 32) else {
            return nil
        }

        guard let pointer = data.toInt(type: UInt64.self) else {
            return nil
        }

        return Memory(baseAddress: pointer, pid: self.pid)
    }

    public func move(offset: UInt64) -> Memory {
        return Memory(baseAddress: self.base + offset, pid: self.pid)
    }

    public func readInt(offset: UInt64) -> Int32? {
        guard let data = readMemory(for: self.pid, from: self.base, at: offset, size: 32) else {
            return nil
        }

        return data.toInt(type: Int32.self)
    }
}

func getBaseAddress(for pid: pid_t) -> Result<mach_vm_address_t, MemoryError> {
    var task: mach_port_t = 0
    var result = task_for_pid(mach_task_self_, pid, &task)
    guard result == KERN_SUCCESS else {
        return .failure(error(result, function: "task_for_pid"))
    }

    defer { mach_port_deallocate(mach_task_self_, task) }

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

func getProcessList() -> Result<[String: pid_t], MemoryError> {
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    var bufferSize = 0

    // Set the required buffer size
    if sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) < 0 {
        return .failure(.unknown(errno, "set buffer size"))
    }

    let entryCount = bufferSize / MemoryLayout<kinfo_proc>.stride

    var processList: UnsafeMutablePointer<kinfo_proc>?
    processList = UnsafeMutablePointer.allocate(capacity: bufferSize)
    defer { processList?.deallocate() }

    if sysctl(&mib, UInt32(mib.count), processList, &bufferSize, nil, 0) < 0 {
        return .failure(.unknown(errno, "list processes"))
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

    return .success(processMap)
}

func readMemory(for pid: pid_t, from: mach_vm_address_t, at: mach_vm_offset_t, size: mach_vm_size_t)
    -> Data?
{
    var task: mach_port_t = 0
    var result = task_for_pid(mach_task_self_, pid, &task)
    guard result == KERN_SUCCESS else {
        return nil
    }

    defer { mach_port_deallocate(mach_task_self_, task) }

    var dataPointer: vm_offset_t = 0
    var dataSize: mach_msg_type_number_t = 0

    result = withUnsafeMutablePointer(to: &dataPointer) { dataPtr in
        withUnsafeMutablePointer(to: &dataSize) { sizePtr in
            vm_read(task, vm_address_t(from + at), vm_size_t(size), dataPtr, sizePtr)
        }
    }
    guard result == KERN_SUCCESS else {
        return nil
    }

    defer { vm_deallocate(mach_task_self_, dataPointer, vm_size_t(dataSize)) }

    guard let rawPointer = UnsafeRawPointer(bitPattern: UInt(dataPointer)) else {
        return nil
    }

    return Data(bytes: rawPointer, count: Int(dataSize))
}
