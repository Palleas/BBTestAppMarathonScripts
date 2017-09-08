import Foundation
import Files
import PerfectZip

guard let token = ProcessInfo.processInfo.environment["HOCKEYAPP_API_TOKEN"] else {
    fatalError("Missing HOCKEYAPP_API_TOKEN")
}

guard let appId = ProcessInfo.processInfo.environment["HOCKEYAPP_APP_ID"] else {
    fatalError("Missing HOCKEYAPP_APP_ID")
}

guard let productDir = ProcessInfo.processInfo.environment["BUDDYBUILD_PRODUCT_DIR"] else {
    fatalError("Missing BUDDYBUILD_PRODUCT_DIR")
}

guard let ipaPath = ProcessInfo.processInfo.environment["BUDDYBUILD_IPA_PATH"] else {
    fatalError("Missing BUDDYBUILD_IPA_PATH")
}

let dSYMs = try Folder(path: productDir).makeSubfolderSequence(recursive: true).filter {
    // print("Current folder = \($0)")
    return $0.extension == "dSYM"
    }
    .map {
        $0.path
    }

print("Adding \(dSYMs.count) dSYMs to the archive")

let zippy = Zip()

let result = zippy.zipFiles(
    paths: dSYMs,
    zipFilePath: "symbols.zip",
    overwrite: true,
    password: ""
)

print("ZipResult Result: \(result.description)")


// Upload to hockey!
let boundary = "Boundary-\(UUID().uuidString)"
var request = URLRequest(url: URL(string: "https://rink.hockeyapp.net/api/2/apps/\(appId)/app_versions/upload")!)
// var request = URLRequest(url: URL(string: "https://requestb.in/15drt381")!)
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
request.setValue(token, forHTTPHeaderField: "X-HockeyAppToken")
request.httpMethod = "POST"

var body = Data()

body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append("Content-Disposition:form-data; name=\"dsym\"; filename=\"dsyms.zip\"\r\n".data(using: .utf8)!)
body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)

let symbols = try Data(contentsOf: URL(fileURLWithPath: "symbols.zip"))
body.append(symbols)
body.append("\r\n".data(using: .utf8)!)

body.append("--\(boundary)\r\n".data(using: .utf8)!)
body.append("Content-Disposition:form-data; name=\"ipa\"; filename=\"file.ipa\"\r\n".data(using: .utf8)!)
body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)

let ipa = try Data(contentsOf: URL(fileURLWithPath: ipaPath))
body.append(ipa)
body.append("\r\n".data(using: .utf8)!)

body.append("--\(boundary)--\r\n".data(using: .utf8)!)

request.httpBody = body

let s = DispatchSemaphore(value: 0)

URLSession.shared.dataTask(with: request) { (data, response, error) in
    print("Data = \(data)")
    if let data = data {
        print(String(data: data, encoding: .utf8))
    }
    print("Response = \(response)")
    print("Error = \(error)")
    s.signal()
    }.resume()

s.wait()

