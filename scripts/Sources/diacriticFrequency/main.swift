import Foundation
import Naqqash

// Logic for what to do as the XML parser reads the file
class ParserDelegate: NSObject, XMLParserDelegate {
    var text = ""
    var readText = false
    
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == "title" { readText = true }
        if elementName == "body" { readText = true }
        if elementName == "annotation" { readText = false }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "title" { readText = false }
        if elementName == "annotation" { readText = true }
    }

    func parser(_ parser: XMLParser,
                foundCharacters string: String) {
        if readText { text.append(string) }
    }
}

// dictionary to store words and their frequencies
var diacriticFreq : [String:Int] = [:]

// get file URLs from ../text directory
let textDirectoryPath = "../text/"
let textDirectoryURL: URL = NSURL.fileURL(withPath: textDirectoryPath)
let files = try! FileManager.default.contentsOfDirectory(at: textDirectoryURL,
                                                         includingPropertiesForKeys: nil,
                                                         options: [.skipsHiddenFiles])

// process every file
for file in files {
    
    // get the relevant text from the text file
    let parserDelegate = ParserDelegate()
    if let parser = XMLParser(contentsOf: file) {
        parser.delegate = parserDelegate
        parser.parse()
    }
    var text = parserDelegate.text
    
    // remove punctuation, numbers, extraneous whitespace and non-essential diacritics
    var charactersToRemove = CharacterSet()
    charactersToRemove.formUnion(.punctuationCharacters)
    charactersToRemove.formUnion(.decimalDigits)
    text.removeAll { String($0).rangeOfCharacter(from:charactersToRemove) != nil }
    text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "‌", with: " ", options: .regularExpression) // zwnj removal
    
    // go through each character
    for char in text {
        var c = char
        if Naqqash.isLetter(c) {
            if Naqqash.isDecomposable(c) { c = Naqqash.decompose(c) }
            for scalar in c.unicodeScalars {
                if Naqqash.isDiacritic(scalar) {
                    let s = String(Character(scalar)) + "◌"
                    let freq = diacriticFreq[s] ?? 0
                    diacriticFreq.updateValue(freq + 1, forKey: s)
                }
            }
        }
    }
}

// write to file
var outputPath = "../stats/diacriticFrequency"
var outputStream = OutputStream.init(toFileAtPath: outputPath, append: false)
outputStream?.open()
JSONSerialization.writeJSONObject(diacriticFreq,
                                  to: outputStream!,
                                  options: [.prettyPrinted],
                                  error: nil)
outputStream?.close()

