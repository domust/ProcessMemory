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
$ swift build && sudo .build/debug/mem --pid [pid]
```
Without sudo, mem fails to get task for pid. And even with sudo it works
only on other processes that have been spawned from the command line.
