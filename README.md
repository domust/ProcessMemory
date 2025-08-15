# ProcessMemory

The package provides Swift API for interacting with process memory.

## Testing

Due to the nature of this package (requires privileges or entitlements),
it cannot be tested in an automated way. Either an application that
uses this package as a dependency has to be built or `swift run --repl`
could be used to run the public functions, but I wasn't able to do it
successfully, it does not detect any of the public symbols after the
import, so none of the functions can actually be invoked.

The command to use for testing is:
```shell
$ ./build.sh && .build/debug/mem --pid [pid]
```
which will prompt for developer tools access

## Debugging

The following command can be used to view the embedded plist file:
```shell
$ otool -P .build/debug/mem
```

The following command can be used to check the signature:
```shell
$ codesign --display --verbose .build/debug/mem
```

The following command can be used to check the entitlements:
```shell
$ codesign --display --entitlements - .build/debug/mem
```
