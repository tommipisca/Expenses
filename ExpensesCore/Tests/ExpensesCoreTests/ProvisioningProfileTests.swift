import Foundation
import Testing
@testable import ExpensesCore

@Suite struct ProvisioningProfileTests {
    /// Un profilo vero è un plist XML dentro una firma CMS binaria: lo simuliamo con byte attorno.
    func profile(expiration: String) -> Data {
        var data = Data([0x30, 0x82, 0x1F, 0x00, 0xFF, 0x01])
        data.append(Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>AppIDName</key><string>XTool ExamsTrack</string>
            <key>ExpirationDate</key><date>\(expiration)</date>
        </dict>
        </plist>
        """.utf8))
        data.append(Data([0xA0, 0x82, 0x00, 0x13]))
        return data
    }

    @Test func readsExpirationDate() {
        let date = ProvisioningProfile.expirationDate(from: profile(expiration: "2026-10-20T08:15:00Z"))
        #expect(date == ISO8601DateFormatter().date(from: "2026-10-20T08:15:00Z"))
    }

    @Test func nilForGarbage() {
        #expect(ProvisioningProfile.expirationDate(from: Data("niente".utf8)) == nil)
    }
}

