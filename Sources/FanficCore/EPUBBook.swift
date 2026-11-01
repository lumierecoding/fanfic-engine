import Foundation

/// An EPUB's title, author and reading order (spine), read from container.xml and the OPF package file.
public struct EPUBBook: Sendable {
    public let title: String?
    public let author: String?
    /// Paths inside the ZIP of the spine documents, in reading order.
    public let spinePaths: [String]
    private let archive: ZipArchive

    public enum EPUBError: LocalizedError {
        case noPackageFile
        case emptyReadingOrder

        public var errorDescription: String? {
            switch self {
            case .noPackageFile: "the EPUB has no package (OPF) file"
            case .emptyReadingOrder: "the EPUB has no pages in its reading order"
            }
        }
    }

    public init(data: Data) throws {
        let archive = try ZipArchive(data: data)
        let container = try archive.contents(of: "META-INF/container.xml")
        guard let opfPath = ContainerReader.rootFile(in: container) else { throw EPUBError.noPackageFile }
        let package = PackageReader.read(try archive.contents(of: opfPath))
        let base = (opfPath as NSString).deletingLastPathComponent

        let paths = package.spine.compactMap { idref -> String? in
            guard let item = package.manifest[idref] else { return nil }
            return Self.resolve(base: base, href: item)
        }
        guard !paths.isEmpty else { throw EPUBError.emptyReadingOrder }

        self.archive = archive
        self.spinePaths = paths
        self.title = package.title
        self.author = package.creator
    }

    /// Plain text of one spine document.
    public func text(at path: String) throws -> String {
        HTMLText.plainText(from: HTMLText.decode(try archive.contents(of: path)))
    }

    static func resolve(base: String, href: String) -> String {
        var h = href
        if let hash = h.firstIndex(of: "#") { h = String(h[..<hash]) }
        h = h.removingPercentEncoding ?? h
        var parts = base.split(separator: "/").map(String.init)
        for component in h.split(separator: "/") {
            if component == ".." {
                if !parts.isEmpty { parts.removeLast() }
            } else if component != "." {
                parts.append(String(component))
            }
        }
        return parts.joined(separator: "/")
    }
}

// MARK: - XML readers

/// Strips an XML namespace prefix: "dc:title" -> "title".
private func localName(_ name: String) -> String {
    name.split(separator: ":").last.map(String.init) ?? name
}

private final class ContainerReader: NSObject, XMLParserDelegate {
    private var path: String?

    static func rootFile(in data: Data) -> String? {
        let reader = ContainerReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.path
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if path == nil, localName(elementName) == "rootfile", let fullPath = attributeDict["full-path"], !fullPath.isEmpty {
            path = fullPath
        }
    }
}

private final class PackageReader: NSObject, XMLParserDelegate {
    var title: String?
    var creator: String?
    var manifest: [String: String] = [:]
    var spine: [String] = []
    private var collecting: String?
    private var buffer = ""

    struct Result {
        let title: String?
        let creator: String?
        let manifest: [String: String]
        let spine: [String]
    }

    static func read(_ data: Data) -> Result {
        let reader = PackageReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return Result(title: reader.title, creator: reader.creator, manifest: reader.manifest, spine: reader.spine)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch localName(elementName) {
        case "title" where title == nil, "creator" where creator == nil:
            collecting = localName(elementName)
            buffer = ""
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] { manifest[id] = href }
        case "itemref":
            if let idref = attributeDict["idref"] { spine.append(idref) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collecting != nil { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let field = collecting, localName(elementName) == field else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            if field == "title" { title = value } else { creator = value }
        }
        collecting = nil
    }
}
