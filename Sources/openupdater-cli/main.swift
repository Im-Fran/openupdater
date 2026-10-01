import CryptoKit
import Foundation

let usage = """
usage:
  openupdater-cli generate-keys
  openupdater-cli sign <App.zip> [private-key-file]   (or set OPENUPDATER_PRIVATE_KEY)
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "generate-keys":
    let key = Curve25519.Signing.PrivateKey()
    print("Public key  (pass to Updater):  \(key.publicKey.rawRepresentation.base64EncodedString())")
    print("Private key (keep it secret!):  \(key.rawRepresentation.base64EncodedString())")

case "sign" where args.count >= 2:
    let encoded = args.count >= 3
        ? (try? String(contentsOfFile: args[2], encoding: .utf8))
        : ProcessInfo.processInfo.environment["OPENUPDATER_PRIVATE_KEY"]
    guard let encoded,
          let raw = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    else { fail("Invalid or missing private key.") }
    guard let zip = FileManager.default.contents(atPath: args[1]) else { fail("Cannot read \(args[1]).") }
    let signature = try key.signature(for: zip).base64EncodedString()
    try signature.write(toFile: args[1] + ".sig", atomically: true, encoding: .utf8)
    print("Wrote \(args[1]).sig")

default:
    fail(usage)
}
