//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import Foundation

/**
 Log Severity

 The log severity of the message, ranging from .Verbose
 through to .Fatal.

 The severity of a message is one side of an equality, the other
 being the minimum between either the global severity or the
 severity of an instance logger. If the message severity
 is greater than the minimum severity the message string will
 be sent to the logger's block.

 */
@objc public enum LogSeverity: Int, Comparable {

    public static func < (lhs: LogSeverity, rhs: LogSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Chatty
    case verbose = 0

    /// Public Service Announcements
    case notice

    /// Info Bulletin
    case info

    /// Careful, Errors Occurring
    case warning

    /// Everything Is On Fire
    case fatal
}

// MARK: - Logger Block

/**
 A typealias for the argument to the logging block.
 */
public typealias LoggerInfo = (message: String, severity: LogSeverity, file: String, function: String, line: Int)


/**
 A typealias for a logging block. This is an easy way
 to pipe the message string into another logging system.
 */
public typealias LoggerBlockType = (LoggerInfo) -> Void

// MARK: - Log Manager

/**
 LogManagerProtocol

 This interface defines the protocol of a log manager, which is a
 singleton to control the global log settings.
 */
public protocol LogManagerProtocol {

    /// - returns: a bool to indicate if logging is enabled globally
    static var enabled: Bool { get set }

    /// - returns: the global LogSeverity
    static var severity: LogSeverity { get set }

    /// - returns: the global logger block type
    static var logger: LoggerBlockType { get set }
}

/**
 LogManager

 The log manager is responsible for holding the shared state required
 for the logger.
 */
public class LogManager: LogManagerProtocol {

    static func metadata(for file: String, function: String, line: Int) -> String {
        guard !file.contains("ProcedureKit") else { return "" }
        let filename = (file as NSString).lastPathComponent
        return "[\(filename) \(function):\(line)], "
    }

    /**
     # Enabled Operation logging
     Enable or Disable built in logger. Default is enabled.
     */
    public static var enabled: Bool {
        get { return sharedInstance.enabled }
        set { sharedInstance.enabled = newValue }
    }

    /**
     # Global Log Severity
     Adjust the global log level severity.
     */
    public static var severity: LogSeverity {
        get { return sharedInstance.severity }
        set { sharedInstance.severity = newValue }
    }

    /**
     # Global logger block
     Set a custom logger block.
     */
    public static var logger: LoggerBlockType {
        get { return sharedInstance.logger }
        set { sharedInstance.logger = newValue }
    }

    static var sharedInstance = LogManager()

    static var queue: DispatchQueue {
        return sharedInstance.queue
    }

    let queue = DispatchQueue(label: "run.kit.procedure.ProcedureKit.Logger", qos: .utility)
    var enabled: Bool {
        get { return _enabled.read { $0 } }
        set {
            _enabled.write { (value) in
                value = newValue
            }
        }
    }

    var severity: LogSeverity {
        get { return _severity.read { $0 } }
        set {
            _severity.write { (value) in
                value = newValue
            }
        }
    }

    var logger: LoggerBlockType {
        get { return loggerLock.read { _logger } }
        set { loggerLock.write { self._logger = newValue } }
    }

    init() {
        _enabled = Protector<Bool>(true)
        _severity = Protector<LogSeverity>(.warning)
        _logger = { message, severity, file, function, line in
            print("\(LogManager.metadata(for: file, function: function, line: line))\(message)")
        }
    }

    /// Private protected properties
    private var _severity: Protector<LogSeverity>
    private var _enabled: Protector<Bool>
    private var loggerLock: ReadWriteLock = Lock()
    private var _logger: LoggerBlockType
}


// MARK: - Logging


/**
 LoggerProtocol

 This is the protocol interface to different logger objects.
 ProcedureKit provides `Logger` a class which conforms to
 `LoggerProtocol`.
 */
public protocol LoggerProtocol {

    associatedtype Manager: LogManagerProtocol

    /// Access the block which receives the message to log.
    var logger: LoggerBlockType { get set }

    /// Get/Set the instance log level severity
    var severity: LogSeverity { get set }

    /// Enabled/Disable the instance logger
    var enabled: Bool { get set }

    /// Get/Set the name of the operation.
    var operationName: String? { get set }

    /**
     The primary log function. The main job of this method
     is to format the message, and send it to its logger
     block, but only if the level is > the minimum severity.

     - parameter message: a `String`, the message to log.
     - parameter severity: a `LogSeverity`, the level of the message.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func log(message: @autoclosure () -> String, severity: LogSeverity, file: String, function: String, line: Int)
}


public extension LoggerProtocol {

    /// Access the minimum `LogSeverity` severity.
    internal var minimumLogSeverity: LogSeverity {
        return min(Manager.severity, severity)
    }

    internal func messageWithOperationName(_ message: String) -> String {
        let name = operationName.map { "\($0): " } ?? ""
        return "\(name)\(message)"
    }

    /**
     Default log function

     The default implementation will create a prefix from the file,
     function and line info. Only the last path component of the
     file is used. If the file is from the Operations framework
     itself, the prefix is empty. The idea here is that log output
     looks like this:

     $ [MyCustomOperation.swift doTheThing:56], This is my log message

     for an operation which is custom to the consumers app.

     For logs from within Operation's operations, e.g. `UserLocation`
     it looks like this:

     User Location: did start
     User Location updated last location: <+51.30971096,-0.12562101> +/- 10.00m (speed 0.00 mps / course -1.00) @ 10/11/2015, 16:06:32 Greenwich Mean Time
     User Location: did finish with no errors.

     - parameter message: a `String`, the message to log.
     - parameter severity: a `LogSeverity`, the level of the message.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func log(message: @autoclosure () -> String, severity: LogSeverity, file: String = #file, function: String = #function, line: Int = #line) {
        guard Manager.enabled && enabled && severity >= minimumLogSeverity else { return }
        let _message = messageWithOperationName(message())
        LogManager.queue.async {
            self.logger(message: _message, severity: severity, file: file, function: function, line: line)
        }
    }

    /**
     Send a .verbose log message.

     - parameter message: a `String`, the message to log.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func verbose(message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, severity: .verbose, file: file, function: function, line: line)
    }

    /**
     Send a .notice log message.

     - parameter message: a `String`, the message to log.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func notice(message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, severity: .notice, file: file, function: function, line: line)
    }

    /**
     Send a .info log message.

     - parameter message: a `String`, the message to log.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func info(message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, severity: .info, file: file, function: function, line: line)
    }

    /**
     Send a .warning log message.

     - parameter message: a `String`, the message to log.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func warning(message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, severity: .warning, file: file, function: function, line: line)
    }

    /**
     Send a .fatal log message.

     - parameter message: a `String`, the message to log.
     - parameter file: a `String`, containing the file (make it default to #file)
     - parameter function: a `String`, containing the function (make it default to #function)
     - parameter line: a `Int`, containing the line number (make it default to #line)
     */
    func fatal(message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message: message, severity: .fatal, file: file, function: function, line: line)
    }
}

// MARK: - AnyLogger

private class AnyLogger_<M: LogManagerProtocol>: LoggerProtocol {
    typealias Manager = M

    var severity: LogSeverity {
        get { _abstractMethod(); return .fatal }
        set { _abstractMethod() }
    }

    var enabled: Bool {
        get { _abstractMethod(); return false }
        set { _abstractMethod() }
    }

    var logger: LoggerBlockType {
        get { _abstractMethod(); return { _ in } }
        set { _abstractMethod() }
    }

    var operationName: String? {
        get { _abstractMethod(); return nil }
        set { _abstractMethod() }
    }
}

private final class AnyLoggerBox<Base: LoggerProtocol>: AnyLogger_<Base.Manager> {
    private var base: Base! = nil

    override var severity: LogSeverity {
        get { return base.severity }
        set { base.severity = newValue }
    }

    override var enabled: Bool {
        get { return base.enabled }
        set { base.enabled = newValue }
    }

    override var logger: LoggerBlockType {
        get { return base.logger }
        set { base.logger = newValue }
    }

    override var operationName: String? {
        get { return base.operationName }
        set { base.operationName = newValue }
    }

    fileprivate init(_ base: Base) {
        self.base = base
    }
}

public struct _AnyLogger<M: LogManagerProtocol>: LoggerProtocol {
    public typealias Manager = M

    private typealias ErasedLogger = AnyLogger_<M>
    private var box: ErasedLogger!

    public var severity: LogSeverity {
        get { return box.severity }
        set { box.severity = newValue }
    }

    public var enabled: Bool {
        get { return box.enabled }
        set { box.enabled = newValue }
    }

    public var logger: LoggerBlockType {
        get { return box.logger }
        set { box.logger = newValue }
    }

    public var operationName: String? {
        get { return box.operationName }
        set { box.operationName = newValue }
    }

    public init<Base: LoggerProtocol>(_ base: Base) where M == Base.Manager {
        box = AnyLoggerBox(base)
    }
}

public typealias AnyLogger = _AnyLogger<LogManager>

public struct AnyLoggerContext<M: LogManagerProtocol>: LoggerProtocol {
    public typealias Manager = M

    private var any: _AnyLogger<M>

    public var severity: LogSeverity {
        get { return any.severity }
        set { any.severity = newValue }
    }

    public var enabled: Bool {
        get { return any.enabled }
        set { any.enabled = newValue }
    }

    public var logger: LoggerBlockType {
        get { return any.logger }
        set { any.logger = newValue }
    }

    public var operationName: String? = nil

    public init<Base: LoggerProtocol>(logger base: Base, operationName name: String) where M == Base.Manager {
        any = _AnyLogger(base)
        operationName = name
    }
}


internal class _Logger<M: LogManagerProtocol>: LoggerProtocol {

    typealias Manager = M

    var severity: LogSeverity

    var enabled: Bool

    var logger: LoggerBlockType

    var operationName: String? = nil

    required init(severity: LogSeverity = Manager.severity, enabled: Bool = Manager.enabled, logger: LoggerBlockType = Manager.logger) {
        self.severity = severity
        self.enabled = enabled
        self.logger = logger
    }
}

internal typealias Logger = _Logger<LogManager>
