//  Copyright (c) 2022 650 Industries, Inc. All rights reserved.

import XCTest

@testable import EXUpdates
@testable import ExpoModulesCore

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
class EXUpdatesLogReaderTests: XCTestCase {
  let serialQueue = DispatchQueue(label: "dev.expo.updates.logging.test")

  func test_ReadLogsAsDictionaries() {
    let logger = UpdatesLogger()
    let logReader = UpdatesLogReader()

    // Mark the date
    let epoch = Date()

    // Write a log message
    logger.error(message: "Test message", code: .NoUpdatesAvailable)

    // Write another log message
    logger.warn(message: "Warning message", code: .AssetsFailedToLoad, updateId: "myUpdateId", assetId: "myAssetId")

    // Use reader to retrieve messages
    var logEntries: [[String: Any]] = []
    do {
      logEntries = try logReader.getLogEntries(newerThan: epoch)
    } catch {
      XCTFail("logEntries call failed: \(error.localizedDescription)")
    }

    // Verify number of log entries and decoded values
    XCTAssertTrue(logEntries.count >= 2)

    // Check number of entries and values in each entry

    let logEntry: [String: Any] = logEntries[logEntries.count - 2]

    XCTAssertTrue(logEntry["timestamp"] as? UInt == UInt(epoch.timeIntervalSince1970))
    XCTAssertTrue(logEntry["message"] as? String == "Test message")
    XCTAssertTrue(logEntry["code"] as? String == "NoUpdatesAvailable")
    XCTAssertTrue(logEntry["level"] as? String == "error")
    XCTAssertNil(logEntry["updateId"])
    XCTAssertNil(logEntry["assetId"])
    XCTAssertFalse((logEntry["stacktrace"] as? [String] ?? []).isEmpty)

    let logEntry2: [String: Any] = logEntries[logEntries.count - 1]
    XCTAssertTrue(logEntry2["timestamp"] as? UInt == UInt(epoch.timeIntervalSince1970))
    XCTAssertTrue(logEntry2["message"] as? String == "Warning message")
    XCTAssertTrue(logEntry2["code"] as? String == "AssetsFailedToLoad")
    XCTAssertTrue(logEntry2["level"] as? String == "warn")
    XCTAssertTrue(logEntry2["updateId"] as? String == "myUpdateId")
    XCTAssertTrue(logEntry2["assetId"] as? String == "myAssetId")
    XCTAssertNil(logEntry2["stacktrace"])
  }

  func test_Persistence() {
    var entries: [String] = []
    // Check empty persistence
    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.clearEntries { _ in
        UpdatesLogPersistence.readEntries { result, error in
          if error != nil {
            XCTFail("Error in reading entry: \(String(describing: error?.localizedDescription))")
          }
          entries = result ?? []
          sem.signal()
        }
      }
      sem.wait()
    }
    XCTAssertEqual(0, entries.count)

    // Check the one entry case
    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.appendEntry(entry: "Test string 1") { error in
        if error != nil {
          XCTFail("Error in appending entry: \(String(describing: error?.localizedDescription))")
        }
        UpdatesLogPersistence.readEntries { result, error in
          if error != nil {
            XCTFail("Error in reading entry: \(String(describing: error?.localizedDescription))")
          }
          entries = result ?? []
          sem.signal()
        }
      }
      sem.wait()
    }
    XCTAssertEqual(1, entries.count)
    XCTAssertEqual("Test string 1", entries[0])

    // Check the two entry case
    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.appendEntry(entry: "Test string 2") { error in
        if error != nil {
          XCTFail("Error in appending entry: \(String(describing: error?.localizedDescription))")
        }
        UpdatesLogPersistence.readEntries { result, error in
          if error != nil {
            XCTFail("Error in reading entry: \(String(describing: error?.localizedDescription))")
          }
          entries = result ?? []
          sem.signal()
        }
      }
      sem.wait()
    }
    XCTAssertEqual(2, entries.count)
    XCTAssertEqual("Test string 1", entries[0])
    XCTAssertEqual("Test string 2", entries[1])

    // Check filtering
    serialQueue.sync {
      let sem = DispatchSemaphore(value: 0)
      UpdatesLogPersistence.filterEntries(filter: { entry in entry.contains("2") }) { error in
        if error != nil {
          XCTFail("Error in appending entry: \(String(describing: error?.localizedDescription))")
        }
        UpdatesLogPersistence.readEntries { result, error in
          if error != nil {
            XCTFail("Error in reading entry: \(String(describing: error?.localizedDescription))")
          }
          entries = result ?? []
          sem.signal()
        }
      }
      sem.wait()
    }
    XCTAssertEqual(1, entries.count)
    XCTAssertEqual("Test string 2", entries[0])
  }
}
