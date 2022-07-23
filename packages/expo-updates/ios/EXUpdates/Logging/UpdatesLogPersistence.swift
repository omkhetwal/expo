// Copyright 2022-present 650 Industries. All rights reserved.

import Foundation
import os.log

import ExpoModulesCore

public typealias UpdatesLogReadCompletionHandler = (_: [String]?, _: Error?) -> Void
public typealias UpdatesLogWriteCompletionHandler = (_: Error?) -> Void
public typealias UpdatesLogFilter = (_: String) -> Bool

/**
 * Static class to read and write expo-updates logs to a flat file
 */
public class UpdatesLogPersistence {
  /**
   Read entries from log file
   */
  public static func readEntries(completion: @escaping UpdatesLogReadCompletionHandler) {
    serialQueue.async {
      do {
        let contents = try _readFileSync()
        completion(contents, nil)
      } catch {
        completion(nil, error)
      }
    }
  }

  /**
   Append entry to the log file
   */
  public static func appendEntry(entry: String, completion: @escaping UpdatesLogWriteCompletionHandler) {
    serialQueue.async {
      do {
        var contents = try _readFileSync()
        contents.append(entry)
        try _writeFileSync(contents)
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  /**
   Filter existing entries and remove ones where filter(entry) == false
   */
  public static func filterEntries(filter: @escaping UpdatesLogFilter, completion: @escaping UpdatesLogWriteCompletionHandler) {
    serialQueue.async {
      do {
        let contents = try _readFileSync()
        let newcontents = contents.filter { entry in filter(entry) }
        try _writeFileSync(newcontents)
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  /**
   Clean up (remove) the log file
   */
  public static func clearEntries(completion: @escaping UpdatesLogWriteCompletionHandler) {
    serialQueue.async {
      do {
        try _deleteFileSync()
        completion(nil)
      } catch {
        completion(error)
      }
    }
  }

  // MARK: - Private methods

  private static let EXPO_UPDATES_LOG_FILENAME = "EXUpdates-Logs.txt"
  private static let EXPO_UPDATES_LOG_QUEUE_LABEL = "dev.expo.updates.logging"
  private static let serialQueue = DispatchQueue(label: EXPO_UPDATES_LOG_QUEUE_LABEL)
  private static let filePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(EXPO_UPDATES_LOG_FILENAME).path ?? ""

  private static func _ensureFileExists() {
    if !FileManager.default.fileExists(atPath: filePath) {
      FileManager.default.createFile(atPath: filePath, contents: nil)
    }
  }

  private static func _readFileSync() throws -> [String] {
    _ensureFileExists()
    return try _stringToList(String(contentsOfFile: filePath, encoding: .utf8))
  }

  private static func _writeFileSync(_ contents: [String]) throws {
    if contents.isEmpty {
      try _deleteFileSync()
      return
    }
    _ensureFileExists()
    try contents.joined(separator: "\n").write(toFile: filePath, atomically: true, encoding: .utf8)
  }

  private static func _deleteFileSync() throws {
    if FileManager.default.fileExists(atPath: filePath) {
      try FileManager.default.removeItem(atPath: filePath)
    }
  }

  private static func _stringToList(_ contents: String?) -> [String] {
    // If null contents, or 0 length contents, return empty list
    return (contents != nil && contents?.lengthOfBytes(using: .utf8) ?? 0 > 0) ?
      contents?.components(separatedBy: "\n") ?? [] :
      []
  }
}
