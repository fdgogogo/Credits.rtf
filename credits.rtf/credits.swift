//
//  main.swift
//  credits.rtf
//
//  Created by Jiaan Fang on 2024/1/15.
//

import AppKit
import ArgumentParser
import Foundation

@main
struct Credits: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A Swift command-line tool to generate Credits.rtf file"
    )

    @Argument(
        help: """
            Input file. Supports one of:
              - .xcodeproj/.pbxproj file
              - Project direcotry (contains .xcodeproj file)
              - plain text file with Github repository URLs (one per line)
            """)
    var input: String

    @Option(name: .shortAndLong, help: "The output file name.")
    var output: String

    @Option(
        name: [.customLong("title-font-size"), .customShort("t")],
        help: "Font size for the title.")
    var titleFontSize: Int = 16

    @Option(
        name: [.customLong("font-size"), .customShort("f")],
        help: "Font size for the content.")
    var fontSize: Int = 12
    
    @Option(
        name: [.customLong("exclude"), .customShort("x")],
        help: "Ignored repositories by name, repeat for multiple.")
    var excludes: [String] = []
    
        
    @Option(
        name: [.customLong("no-open"), .customShort("O")],
        help: "Don't automatically open the output file after generation."
        )
    var automaticallyOpenDisabled: Bool = false
    
    
    func run() throws {
        let attributedString: NSMutableAttributedString = .init()
        let extractedURLs = extractRepositoryURL(fromProjectFile: self.input)
        print("Extracted \(extractedURLs.count) URLs")
        
        for repo in extractedURLs
        {
            if let repoURL = URL(string: repo),
                let licenseFile = fetchLicenseContent(for: repoURL)
            {
                attributedString.append(
                    NSAttributedString(
                        string: repoURL.lastPathComponent + "\n",
                        attributes: [.font: NSFont.boldSystemFont(ofSize: CGFloat(self.titleFontSize))]))
                attributedString.append(
                    NSAttributedString(
                        string: licenseFile + "\n\n",
                        attributes: [.font: NSFont.systemFont(ofSize: CGFloat(self.fontSize))]))
            }

        }
        let range = NSRange(location: 0, length: attributedString.length)

        if let rtfData = attributedString.rtf(
            from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        {
            // 这里可以使用 rtfData，例如写入文件或进行其他操作
            do {
                let url = URL(filePath: self.output)
                try rtfData.write(to: url)
                if !automaticallyOpenDisabled {
                    NSWorkspace.shared.open(url)
                }
            } catch {
                print("Error wrting rtf file: \(error)")
            }
        } else {
            print("Error converting to rtf.")
        }
    }
    

    func extractRepositoryURL(fromProjectFile filePath: String) -> [String] {

        if isDir(path: filePath) {
            if filePath.hasSuffix(".xcodeproj") {
                // 如果是 .xcodeproj 文件，获取 project.pbxproj 文件的路径
                let projectFilePath = filePath + "/project.pbxproj"
                return extractRepositoryURL(fromProjectFile: projectFilePath)
            } else {
                // 如果是项目文件夹，获取 .xcodeproj 文件的路径
                let enumerator = FileManager.default.enumerator(
                    atPath: filePath)
                while let element = enumerator?.nextObject() as? String {
                    if !element.starts(with: ".") && element.hasSuffix(".xcodeproj") {
                        let projectFilePath = filePath + "/" + element + "/project.pbxproj"
                        return extractRepositoryURL(fromProjectFile: projectFilePath)
                    }
                }
            }
        }

        if !filePath.hasSuffix(".pbxproj") {
            print("ERROR: Invalid file type")
            return extractRepositoryURL(fromPlainTextFile: filePath)
        }
        print(filePath)
        var foundURLs = [String]()

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)

            if let rangeStart = content.range(
                of: "/* Begin XCRemoteSwiftPackageReference section */"),
                let rangeEnd = content.range(
                    of: "/* End XCRemoteSwiftPackageReference section */",
                    range: rangeStart.upperBound..<content.endIndex)
            {

                let packageSection = content[rangeStart.upperBound..<rangeEnd.lowerBound]

                let lines = packageSection.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("repositoryURL") {
                        if let urlRangeStart = line.range(of: "\""),
                            let urlRangeEnd = line.range(
                                of: "\"", range: urlRangeStart.upperBound..<line.endIndex)
                        {
                            let url = String(
                                line[urlRangeStart.upperBound..<urlRangeEnd.lowerBound])
                            foundURLs.append(url)
                        }
                    }
                }
            }
        } catch {
            print("Error reading file: \(error)")
        }

        return foundURLs
    }

    func extractRepositoryURL(fromPlainTextFile filePath: String) -> [String] {
        var foundURLs = [String]()
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("https://github.com") {
                    foundURLs.append(line)
                }
            }
        } catch {
            print("Error reading file: \(error)")
        }
        return foundURLs
    }

    func isDir(path: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                // 路径指向一个文件夹
                return true
            } else {
                // 路径指向一个文件
                return false
            }
        } else {
            return false
        }
    }

    func fetchLicenseContent(for repositoryURL: URL) -> String? {
        // 假设 GitHub URL 的格式是 https://github.com/[user]/[repo]
        let repoName = repositoryURL.lastPathComponent
        if excludes.contains(repoName) {
            print("\(repoName):\tExcluded")
            return nil
        }
        print("Fetching license for \(repoName)")
        let pathComponents = repositoryURL.pathComponents
        guard pathComponents.count >= 3 else {
            print("\(repoName):\tERROR: Invalid GitHub URL")
            return nil
        }

        let user = pathComponents[1]
        let repo = pathComponents[2].replacingOccurrences(of: ".git", with: "")
        let branches = ["main", "master"]
        let suffixes = ["", "txt", "md"]

        let licenseURLs = branches.flatMap { branch in
            suffixes.map { suffix in
                let urlString = "https://raw.githubusercontent.com/\(user)/\(repo)/\(branch)/LICENSE\(suffix.isEmpty ? "" : ".\(suffix)")"
                return URL(string: urlString)
            }
        }
        let semaphore = DispatchSemaphore(value: 0)
        var licenseContent: String?

        for url in licenseURLs where url != nil {
            print("\(repoName):\ttrying \(url!.relativeString)")

            URLSession.shared.dataTask(with: url!) { data, response, error in
                defer { semaphore.signal() }  // 在任务完成时发送信号

                if let error = error {
                    print("\(repoName):\tERROR: \(error)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                    let data = data
                {
                    licenseContent = String(data: data, encoding: .utf8)
                }
            }.resume()

            semaphore.wait()

            if licenseContent != nil {
                break
            }
        }
        if licenseContent == nil || (licenseContent?.count ?? 0) == 0 {
            print("\(repoName):\tERROR: License fetch failed")
        } else {
            print("\(repoName):\tLicense fetched, length \(licenseContent?.count ?? 0)")
        }
        
        return licenseContent
    }



}
