import OSLog

enum Log {
    private static let subsystem = "app.ledge"

    static let app      = Logger(subsystem: subsystem, category: "app")
    static let window   = Logger(subsystem: subsystem, category: "window")
    static let display  = Logger(subsystem: subsystem, category: "display")
    static let module   = Logger(subsystem: subsystem, category: "module")
    static let media    = Logger(subsystem: subsystem, category: "media")
    static let shelf    = Logger(subsystem: subsystem, category: "module.fileshelf")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
