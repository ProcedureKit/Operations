//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import Foundation

public enum Delay {
    case by(TimeInterval)
    case until(Date)
}

extension Delay: CustomStringConvertible {

    private static let formatter = DateFormatter()

    public var description: String {
        switch self {
        case .by(let _interval):
            return "for \(_interval) seconds"
        case .until(let date):
            return "until \(Delay.formatter.string(from: date))"
        }
    }
}

internal extension Delay {

    var interval: TimeInterval {
        switch self {
        case .by(let _interval):
            return _interval
        case .until(let date):
            return date.timeIntervalSinceNow
        }
    }
}

/**
 `DelayProcedure` is a procedure which waits until a given future
 date, or a time interval. If the interval is negative, or the date
 is in the past, the procedure finishes.

 Note that this procedure efficiently uses GCD so it
 does not block the thread on which it is called.

 Make an operation dependent on a `DelayProcedure` in order to
 make it execute after a timeout, or in a repeated fashion with a
 time-out.
 */
public class DelayProcedure: Procedure {

    private let delay: Delay
    private let leeway: DispatchTimeInterval
    private let timer: DispatchSourceTimer

    internal init(delay: Delay, leeway: DispatchTimeInterval = .milliseconds(1)) {
        self.delay = delay
        self.leeway = leeway
        self.timer = DispatchSource.makeTimerSource()
        super.init()
        name = "Delay \(delay)"
        timer.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.isCancelled { strongSelf.finish() }
        }
        addDidCancelBlockObserver { procedure, _ in
            procedure.timer.cancel()
        }
    }
    /**
     Initialize the `DelayProcedure` with a time interval.

     - parameter interval: a `TimeInterval`.
     - parameter leeway: an `DispatchTimeInterval` representing leeway
     for the timer. This defaults to 1 milli-second accuracy.
     This is partly from a energy standpoint as nanosecond
     accuracy is costly.
     */
    public convenience init(interval: TimeInterval, leeway: DispatchTimeInterval = .milliseconds(1)) {
        self.init(delay: .by(interval), leeway: leeway)
    }

    /**
     Initialize the `DelayProcedure` with a time interval.

     - parameter date: a `Date`.
     - parameter leeway: an `DispatchTimeInterval` representing leeway
     for the timer. This defaults to 1 milli-second accuracy.
     This is partly from a energy standpoint as nanosecond
     accuracy is costly.
     */
    public convenience init(date: Date, leeway: DispatchTimeInterval = .milliseconds(1)) {
        self.init(delay: .until(date), leeway: leeway)
    }

    /**
     Executes the operation by using dispatch_after to finish the
     operation in the future, but only if the time interval is
     greater than zero.
     */
    public override func execute() {
        switch delay.interval {
        case (let interval) where interval > 0.0:
            timer.scheduleOneshot(deadline: DispatchTime.now() + interval, leeway: leeway)
        default:
            finish()
        }
    }
}
