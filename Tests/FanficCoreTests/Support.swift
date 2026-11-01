import Foundation
@testable import FanficCore

/// The project folder's Fixtures/ (made by scripts/make-fixtures.swift).
let fixturesFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Fixtures", isDirectory: true)

struct ExpectedResult: Codable, Sendable {
    var file: String
    var outcome: String
    var kind: String?
    var title: String?
    var author: String?
    var firstPageSource: String?
    var relationships: [String]
    var fandoms: [String]
}

func loadExpected() throws -> [ExpectedResult] {
    try JSONDecoder().decode([ExpectedResult].self, from: Data(contentsOf: fixturesFolder.appendingPathComponent("expected.json")))
}

func fixture(_ name: String) -> URL { fixturesFolder.appendingPathComponent(name) }

func temporaryLibraryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("FanficEngineTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// A library in a temporary folder with every test file imported in expected.json order.
@MainActor
func importedLibrary() async throws -> (Library, ImportReport, [ExpectedResult]) {
    let expected = try loadExpected()
    let library = Library(root: try temporaryLibraryFolder())
    let report = await library.importFiles(expected.map { fixture($0.file) })
    return (library, report, expected)
}

func files(in folder: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
}
