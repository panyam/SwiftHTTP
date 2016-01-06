
func signal_handler(signum: Int32)
{
    print("Ignoring Signal: \(signum)")
}

signal(SIGPIPE, signal_handler)

testWSServer()
