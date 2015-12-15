
public class Header {
    var name: String = ""
    var values: [String] = []

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
    func addValue(value: String) {
        values.append(value);
    }

    func allValues() -> [String] {
        return values
    }

    func firstValue() -> String? {
        return values[0]
    }
}

/**
 * A header list for request and responses.
 */
public class HeaderCollection {
    var headers: [String: Header]

    init() {
        headers = [String: Header]()
    }

    func headerForKey(key: String) -> Header? {
        return headers[key]
    }
}
