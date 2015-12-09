
public class Server {
    /**
     * Option to ignore a request if header's exceed this length>
     */
    var maxHeaderLength = 0
    var port = 80
    var securePort = 443
    var host = "*"

    func run() {
        print("Running server")
    }
}

