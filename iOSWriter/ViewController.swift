//
//  ViewController.swift
//  iOSWriter
//
//  Created by Reynaldo on 22/7/21.
//  Copyright © 2021 Apple. All rights reserved.
//

import Combine
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let assetURL = Bundle.main.url(forResource: "video", withExtension: "mp4")!
        let outputURL = outputDirectory()
        let config = FMP4WriterConfiguration(assetPath: assetURL.path, outputDirectoryPath: outputURL.path)
        
        generateHLSContent(config: config) { succeed in
            guard succeed else {
                fatalError()
            }
            
            DispatchQueue.main.async {
                self.share(url: outputURL)
            }
        }
    }
    
    /// Shares a url using a `UIActivityViewController`.
    /// - Parameter url: URL to share.
    private func share(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        self.show(activityVC, sender: nil)
    }

    /// Creates a directory that will containg the HLS output.
    private func outputDirectory() -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("hls", isDirectory: true)
        
        if FileManager.default.fileExists(atPath: output.path) {
            try! FileManager.default.removeItem(at: output)
        }
        
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true, attributes: nil)
        return output
    }
    
    // This is basically a copy of the code from the `main.swift` file, only modifying it to call a completion handler
    // instead of waiting for the dispatch group.
    func generateHLSContent(config: FMP4WriterConfiguration, completion: @escaping (Bool) -> Void) {
        // This is the result of the asynchronous operations.
        var result: Subscribers.Completion<Error>?

        // These are needed to keep the asynchronous operations running.
        var segmentGenerationToken: Any?
        var segmentAndIndexFileWriter: AnyCancellable?
        
        let group = DispatchGroup()
        group.enter()

        // Asynchronously load tracks from the source movie file.
        loadTracks(using: config) { trackLoadingResult in
            do {
                let sourceMedia = try trackLoadingResult.get()
                
                // Make sure that the output directory exists.
                let fullOutputPath = NSString(string: config.outputDirectoryPath).expandingTildeInPath
                let outputDirectoryURL = URL(fileURLWithPath: fullOutputPath, isDirectory: true)
                try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                print("Writing segment files to directory \(outputDirectoryURL)")
                
                // Set up the processing pipelines.
                
                // Generate a stream of Segment structures.
                // This will be hooked up to the segment generation code after the processing chains have been set up.
                let segmentGenerator = PassthroughSubject<Segment, Error>()
                
                // Generate an index file from a stream of Segments.
                let indexFileGenerator = segmentGenerator.reduceToIndexFile(using: config)
                
                // Write each segment to disk.
                let segmentFileWriter = segmentGenerator
                    .tryMap { segment in
                        let segmentFileName = segment.fileName(forPrefix: config.segmentFileNamePrefix)
                        let segmentFileURL = URL(fileURLWithPath: segmentFileName, isDirectory: false, relativeTo: outputDirectoryURL)

                        print("writing \(segment.data.count) bytes to \(segmentFileName)")
                        try segment.data.write(to: segmentFileURL)
                    }
                
                // Write the index file to disk.
                let indexFileWriter = indexFileGenerator
                    .tryMap { finalIndexFile in
                        let indexFileURL = URL(fileURLWithPath: config.indexFileName, isDirectory: false, relativeTo: outputDirectoryURL)
                        
                        print("writing index file to \(config.indexFileName)")
                        try finalIndexFile.write(to: indexFileURL, atomically: false, encoding: .utf8)
                    }
                
                // Collect the results of segment and index file writing.
                segmentAndIndexFileWriter = segmentFileWriter.merge(with: indexFileWriter)
                    .sink(receiveCompletion: { completion in
                        result = completion
                        group.leave()
                    }, receiveValue: {})
                
                // Now that all the processing pipelines are set up, start the flow of data and wait for completion.
                segmentGenerationToken = generateSegments(sourceMedia: sourceMedia, configuration: config, subject: segmentGenerator)
            } catch {
                result = .failure(error)
                group.leave()
            }
        }

        // Wait for the asynchronous processing to finish.
        group.notify(queue: .global()) {
            // Evaluate the result.
            switch result! {
            case .finished:
                assert(segmentGenerationToken != nil)
                assert(segmentAndIndexFileWriter != nil)
                print("Finished writing segment data")
                completion(true)
            case .failure(let error):
                switch error {
                case let localizedError as LocalizedError:
                    print("Error: \(localizedError.errorDescription ?? String(describing: localizedError))")
                default:
                    print("Error: \(error)")
                }
                completion(false)
            }
        }
    }
}

