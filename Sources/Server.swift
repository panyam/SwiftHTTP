
import CoreFoundation 
import Foundation 
import SocketServer
import SwiftGlibc


private func handleConnectionAccept(socket: CFSocket!, callbackType: CFSocketCallBackType, address: CFData!, data: UnsafePointer<Void>, info: UnsafeMutablePointer<Void>) {
}

public class Server {
    /**
     * Option to ignore a request if header's exceed this length>
     */
    var maxHeaderLength = 0
    var port = 80
    var securePort = 443
    var host = "*"
    private var isRunning = false
    private var stopped = false
    private var serverSocket : CFSocket

    init() {
        var _ = CFNumberCreate(nil, 15, nil)
        ev_default_loop(0);
        socket(AF_INET, 0, 0)
        serverSocket = CFSocketCreate(nil, 0, 0, 0, 2, nil, nil);
        print("Server Socket: \(serverSocket)")
    }

    private func initSocket() {
        // TODO: Use constants instead of magic numbers - need to learn about C consts to Swift conversion
        serverSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, 0, 0, 2, handleConnectionAccept, UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque()));
    }

    func stop() {
    }

    func run() {
        print("Running server")

        if isRunning {
            print("Server is already running")
        }

        isRunning = true
        while true {
            print("Server is already running")
        }
    }
}

