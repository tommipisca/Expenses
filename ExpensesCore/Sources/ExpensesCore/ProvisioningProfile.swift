import Foundation

/// Profilo di installazione (`embedded.mobileprovision`): con l'account gratuito scade dopo 7 giorni.
public enum ProvisioningProfile {
    /// Data di scadenza dell'app installata; nil se il profilo manca (es. sul Simulatore).
    public static func embeddedExpirationDate(bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return expirationDate(from: data)
    }

    /// Il profilo è un plist XML racchiuso in una firma binaria: estrae il plist e legge `ExpirationDate`.
    public static func expirationDate(from data: Data) -> Date? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil
              ) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }
}

