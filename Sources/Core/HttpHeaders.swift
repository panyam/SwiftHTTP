
public class Header {
    var name = ""
    var values = [String]()

    public init(name: String)
    {
        self.name = name
    }

    public func getName() -> String {
        return name
    }

    /**
     * Clears all values for this header.
     */
    public func clear() {
        values.removeAll()
    }

    public func isEmpty() -> Bool {
        return values.isEmpty
    }

    /**
     * Removes all values and sets the 
     */
    public func setValue(value: String) {
        values = [value];
    }

    /**
     * Adds a new values to the list of values associated with this header's key
     */
    public func addValue(value: String) {
        values.append(value);
    }

    public func allValues() -> [String] {
        return values
    }

    public func firstValue() -> String? {
        return values[0]
    }
}
