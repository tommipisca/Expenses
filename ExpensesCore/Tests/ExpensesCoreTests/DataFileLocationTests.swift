import Foundation
import Testing
@testable import ExpensesCore

@Suite struct DataFileLocationTests {
    let group: URL
    let documents: URL

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        group = root.appendingPathComponent("group")
        documents = root.appendingPathComponent("documents")
        try FileManager.default.createDirectory(at: group, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    }

    @Test func usesGroupWhenAvailable() {
        let url = AppGroup.resolveDataFileURL(groupContainer: group, documents: documents)
        #expect(url == group.appendingPathComponent("expenses.json"))
    }

    @Test func fallsBackToDocuments() {
        let url = AppGroup.resolveDataFileURL(groupContainer: nil, documents: documents)
        #expect(url == documents.appendingPathComponent("expenses.json"))
    }

    @Test func movesDocumentsFileIntoGroup() throws {
        try Data("dati".utf8).write(to: documents.appendingPathComponent("expenses.json"))
        let url = AppGroup.resolveDataFileURL(groupContainer: group, documents: documents)
        #expect(try String(contentsOf: url, encoding: .utf8) == "dati")
        #expect(!FileManager.default.fileExists(atPath: documents.appendingPathComponent("expenses.json").path))
    }

    @Test func keepsExistingGroupFile() throws {
        try Data("vecchi".utf8).write(to: documents.appendingPathComponent("expenses.json"))
        try Data("gruppo".utf8).write(to: group.appendingPathComponent("expenses.json"))
        let url = AppGroup.resolveDataFileURL(groupContainer: group, documents: documents)
        #expect(try String(contentsOf: url, encoding: .utf8) == "gruppo")
    }
}

/// xtool con account gratuito riscrive bundle ID e gruppi aggiungendo il prefisso `XTL-<id>.`.
@Suite struct GroupIdentifierTests {
    @Test func appBundleIDWithXtoolPrefix() {
        #expect(AppGroup.groupIdentifier(forBundleID: "XTL-ABCD1234.com.Tommaso.Expenses")
            == "group.XTL-ABCD1234.com.Tommaso.Expenses")
    }

    @Test func widgetBundleIDSharesAppGroup() {
        #expect(AppGroup.groupIdentifier(forBundleID: "XTL-ABCD1234.com.Tommaso.Expenses.Widget")
            == "group.XTL-ABCD1234.com.Tommaso.Expenses")
    }

    @Test func plainBundleID() {
        #expect(AppGroup.groupIdentifier(forBundleID: "com.Tommaso.Expenses") == "group.com.Tommaso.Expenses")
    }

    @Test func missingBundleIDUsesDefault() {
        #expect(AppGroup.groupIdentifier(forBundleID: nil) == "group.com.Tommaso.Expenses")
    }
}
