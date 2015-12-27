
public class Header {
    var name = ""
    var values = [String]()

    public init(name: String)
    {
        self.name = name
    }

    func getName() -> String {
        return name
    }

    /**
     * Clears all values for this header.
     */
    func clear() {
        values.removeAll()
    }

    func isEmpty() -> Bool {
        return values.isEmpty
    }

    /**
     * Removes all values and sets the 
     */
    func setValue(value: String) {
        values = [value];
    }

    /**
     * Adds a new values to the list of values associated with this header's key
     */
    public func addValue(value: String) {
        values.append(value);
    }

    func allValues() -> [String] {
        return values
    }

    func firstValue() -> String? {
        return values[0]
    }
}
