// Copyright 2022-present 650 Industries. All rights reserved.

import Foundation
import OSLog

import ExpoModulesCore

/**
 Class to read expo-updates logs using OSLogReader
 */
@objc(EXUpdatesLogReader)
public class UpdatesLogReader: NSObject {
  private let serialQueue = DispatchQueue(label: "dev.expo.updates.logging.reader")

  /**
   Get expo-updates logs newer than the given date
   Returns the log entries unpacked as dictionaries
   Maximum of one day lookback is allowed
   */
  @objc(getLogEntriesNewerThan:error:)
  public func getLogEntries(newerThan: Date) throws -> [[String: Any]] {
    return try getLogEntries(newerThan: newerThan)
      .compactMap { logEntryString in
        UpdatesLogEntry.create(from: logEntryString)?.asDict()
      }
  }

  /**
   Purge all log entries written prior to the given date
   */
  @objc(purgeLogEntriesOlderThan:error:)
  public func purgeLogEntries(olderThan: Date) throws {
    let epoch = UInt(olderThan.timeIntervalSince1970)
    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.filterEntries { entryString in
        if let entry = UpdatesLogEntry.create(from: entryString) {
          return entry.timestamp >= epoch
        }
        return false
      } completion: { _ in
        sem.signal()
      }
      sem.wait()
    }
  }

  /**
   Get expo-updates logs newer than the given date
   Returned strings are all in the JSON format of UpdatesLogEntry
   Maximum of one day lookback is allowed
   */
  @objc(getLogEntryStringsNewerThan:error:)
  public func getLogEntries(newerThan: Date) throws -> [String] {
    let earliestDate = Date().addingTimeInterval(-86_400)
    let dateToUse = newerThan.timeIntervalSince1970 < earliestDate.timeIntervalSince1970 ?
      earliestDate :
      newerThan
    let epoch = UInt(dateToUse.timeIntervalSince1970)

    var result: [String] = []

    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.readEntries { entries, error in
        if error != nil {
          print("UpdatesLogReader: error in getLogEntries: \(String(describing: error))")
        } else {
          result = entries ?? []
        }
        sem.signal()
      }
      sem.wait()
    }

    return result
      .compactMap { entry in
        UpdatesLogEntry.create(from: entry)
      }
      .filter { entry in
        entry.timestamp >= epoch
      }
      .compactMap { entry in
        entry.asString()
      }

    /*
    let logStore = try OSLogStore(scope: .currentProcessIdentifier)
    // Get all the logs since the given date.
    let position = logStore.position(date: dateToUse)

    // Fetch log objects, selecting our subsystem and category
    let predicate = NSPredicate(format: "category == %@ AND subsystem = %@",
                                argumentArray: [UpdatesLogger.EXPO_UPDATES_LOG_CATEGORY, Logger.EXPO_MODULES_LOG_SUBSYSTEM])
    let allEntries = try logStore.getEntries(at: position, matching: predicate)

    // Extract just the log message strings, removing the first two characters added
    // by ExpoModulesCore.Logger
    return allEntries
          .compactMap { entry in
            let suffixFrom = entry.composedMessage.index(entry.composedMessage.startIndex, offsetBy: 2)
            return String(entry.composedMessage.suffix(from: suffixFrom))
          }
     */
  }
}
