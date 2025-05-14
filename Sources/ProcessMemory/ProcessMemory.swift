// The Swift Programming Language
// https://docs.swift.org/swift-book
import Darwin.Mach

public func getBaseAddress(for pid: pid_t) -> mach_vm_address_t? {
	var task: mach_port_t = 0
	var result = task_for_pid(mach_task_self_, pid, &task)
	guard result == KERN_SUCCESS else {
		return nil
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
		return nil
	}

	return address
}
