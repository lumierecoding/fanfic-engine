#!/usr/bin/env swift
// The EdDSA (Ed25519) key that signs Fanfic Engine's updates for Sparkle (SPEC section 10).
// The private key is a file (base64 of the 32-byte key), kept outside the repository and iCloud Drive and never in
// the Keychain; the public key goes into Resources/Info.plist as SUPublicEDKey. Back the private key up: without it,
// installed copies can't be updated in the app any more.
//
//   swift scripts/update-key.swift new <private-key-file>     make a new key (refuses to overwrite); prints the public key
//   swift scripts/update-key.swift public <private-key-file>  prints the public key
//   swift scripts/update-key.swift sign <private-key-file> <file>  prints the file's signature (sparkle:edSignature)
//   swift scripts/update-key.swift verify <public-key> <file> <signature>  checks a signature

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func readPrivateKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8),
          let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else { fail("cannot read the private key in \(path)") }
    return key
}

let args = Array(CommandLine.arguments.dropFirst())
switch (args.first, args.count) {
case ("new", 2):
    let path = args[1]
    if FileManager.default.fileExists(atPath: path) { fail("\(path) exists already; not overwritten") }
    let key = Curve25519.Signing.PrivateKey()
    let folder = (path as NSString).deletingLastPathComponent
    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    guard FileManager.default.createFile(atPath: path, contents: Data((key.rawRepresentation.base64EncodedString() + "\n").utf8),
                                         attributes: [.posixPermissions: 0o600]) else { fail("cannot write \(path)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case ("public", 2):
    print(readPrivateKey(args[1]).publicKey.rawRepresentation.base64EncodedString())
case ("sign", 3):
    let key = readPrivateKey(args[1])
    guard let data = FileManager.default.contents(atPath: args[2]) else { fail("cannot read \(args[2])") }
    print(try key.signature(for: data).base64EncodedString())
case ("verify", 4):
    guard let raw = Data(base64Encoded: args[1]), let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw),
          let data = FileManager.default.contents(atPath: args[2]), let signature = Data(base64Encoded: args[3]) else { fail("bad arguments") }
    if key.isValidSignature(signature, for: data) { print("valid") } else { fail("NOT valid") }
default:
    fail("usage: update-key.swift new|public <private-key-file> · sign <private-key-file> <file> · verify <public-key> <file> <signature>")
}
