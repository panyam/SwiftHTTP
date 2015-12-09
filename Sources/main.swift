
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import Foundation

print("Starting server...")
var s = Server()
s.run()
