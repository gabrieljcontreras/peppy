import Foundation

enum ExportFileError: Error, Equatable {
    case unexpectedExtension(expected: String, actual: String)
    case preparationFailed
}

protocol ExportFileServicing {
    func prepare(
        _ downloaded: DownloadedFile,
        expectedExtension: String
    ) throws -> URL
    func remove(_ url: URL)
    func removeStaleFiles() throws
}

protocol ExportFileAttributeApplying {
    func applyProtection(
        _ protection: FileProtectionType,
        to url: URL
    ) throws
    func excludeFromBackup(_ url: URL) throws -> URL
}

struct SystemExportFileAttributeApplier: ExportFileAttributeApplying {
    let fileManager: FileManager

    func applyProtection(
        _ protection: FileProtectionType,
        to url: URL
    ) throws {
        try fileManager.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }

    func excludeFromBackup(_ url: URL) throws -> URL {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var protectedURL = url
        try protectedURL.setResourceValues(values)
        return protectedURL
    }
}

final class ExportFileService: ExportFileServicing {
    private static let supportedExtensions: Set<String> = ["pdf", "zip"]

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let attributeApplier: ExportFileAttributeApplying

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        attributeApplier: ExportFileAttributeApplying? = nil
    ) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
            ?? fileManager.temporaryDirectory
                .appendingPathComponent("peppy-exports", isDirectory: true)
        self.attributeApplier = attributeApplier
            ?? SystemExportFileAttributeApplier(fileManager: fileManager)
    }

    func prepare(
        _ downloaded: DownloadedFile,
        expectedExtension: String
    ) throws -> URL {
        let expected = expectedExtension.lowercased()
        let actual = URL(fileURLWithPath: downloaded.suggestedFilename)
            .pathExtension
            .lowercased()

        guard Self.supportedExtensions.contains(expected),
              actual == expected else {
            remove(downloaded.url)
            throw ExportFileError.unexpectedExtension(
                expected: expected,
                actual: actual
            )
        }

        let destination = rootDirectory.appendingPathComponent(
            "peppy-export-\(UUID().uuidString.lowercased()).\(expected)"
        )

        do {
            try fileManager.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try fileManager.moveItem(at: downloaded.url, to: destination)
            try attributeApplier.applyProtection(
                .complete,
                to: destination
            )
            return try attributeApplier.excludeFromBackup(destination)
        } catch {
            remove(downloaded.url)
            remove(destination)
            throw ExportFileError.preparationFailed
        }
    }

    func remove(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
        removeRootDirectoryIfEmpty()
    }

    func removeStaleFiles() throws {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return }
        try fileManager.removeItem(at: rootDirectory)
    }

    private func removeRootDirectoryIfEmpty() {
        guard fileManager.fileExists(atPath: rootDirectory.path),
              let contents = try? fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: nil
              ),
              contents.isEmpty else {
            return
        }
        try? fileManager.removeItem(at: rootDirectory)
    }
}
