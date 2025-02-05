//
//  Presenter.swift
//  TabBarIconGenerator
//
//  Created by Kirill Pustovalov on 27.07.2020.
//  Copyright © 2020 Kirill Pustovalov. All rights reserved.
//

import AppKit

class Presenter {
    public static let shared = Presenter()
    private var lastImagesetURL: URL?

    private init() {}

    func presentNSOpenPanelForImage(completion: @escaping (_ result: Result<ImageModel, Error>) -> Void) {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = false

        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["png", "jpg", "jpeg"]
        panel.canChooseFiles = true
        panel.title = "Select image"

        panel.begin { result in
            if result == .OK,
               let url = panel.urls.first,
               let image = NSImage(contentsOf: url)
            {
                let imageName = url.deletingPathExtension().lastPathComponent
                completion(.success(ImageModel(imageName: imageName, image: image)))
            } else {
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo: nil)))
            }
        }
    }

    func presentNSOpenPanelForFolder(completion: @escaping (_ result: Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()

        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.title = "Select folder"
        panel.prompt = "Save"

        panel.begin { result in
            if result == .OK, let url = panel.urls.first {
                completion(.success(url))
            } else {
                completion(.failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotOpenFile, userInfo: nil)))
            }
        }
    }

    func createImageSetFrom(image: NSImage, with name: String, at path: URL) {
        let folderPath = path.appendingPathComponent("\(name).imageset")
        var normalizedFolderPath = folderPath.absoluteString
        lastImagesetURL = folderPath

        let prefix = "file://"

        normalizedFolderPath = normalizedFolderPath.replacingOccurrences(of: prefix, with: "")
        normalizedFolderPath = normalizedFolderPath.removingPercentEncoding ?? "\(normalizedFolderPath)"

        createFolderAtPath(at: normalizedFolderPath)

        let image3x = resizeImage(image: image, width: 38, height: 38)
        let image2x = resizeImage(image: image, width: 25, height: 25)
        let image1x = resizeImage(image: image, width: 13, height: 13)

        saveImage(image: image3x!, path: folderPath.appendingPathComponent("\(name)@3x.png"))
        saveImage(image: image2x!, path: folderPath.appendingPathComponent("\(name)@2x.png"))
        saveImage(image: image1x!, path: folderPath.appendingPathComponent("\(name)@1x.png"))

        saveJSON(path: folderPath, imageName: name)
    }

    func showLastImageset() {
        guard let url = lastImagesetURL, url.isFileURL else {
            return
        }

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }

    private func createFolderAtPath(at path: String) {
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    private func resizeImage(image: NSImage, width: CGFloat, height: CGFloat) -> NSImage? {
        let imageSize = calculateNewImageSize(image: image, for: width, height: height)

        let resizedImage = NSImage(size: imageSize)
        resizedImage.lockFocus()

        let imageContainerRect = NSMakeRect(.zero, .zero, imageSize.width, imageSize.height)
        let imageRect = NSMakeRect(.zero, .zero, image.size.width, image.size.height)

        image.draw(in: imageContainerRect, from: imageRect, operation: .sourceOver, fraction: 1)
        resizedImage.unlockFocus()

        guard let data = resizedImage.tiffRepresentation, let resultImage = NSImage(data: data) else { return nil }
        return resultImage
    }

    private func calculateNewImageSize(image: NSImage, for width: CGFloat, height: CGFloat) -> NSSize {
        let imageWidth = image.size.width
        let imageHeight = image.size.height

        let widthRatio = width / imageWidth
        let heightRatio = height / imageHeight

        return widthRatio > heightRatio ?
            NSSize(width: floor(imageWidth * widthRatio), height: floor(imageHeight * widthRatio)) :
            NSSize(width: floor(imageWidth * heightRatio), height: floor(imageHeight * heightRatio))
    }

    private func saveImage(image: NSImage, path: URL) {
        let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!)
        let pngData = imageRep?.representation(using: .png, properties: [:])
        do {
            try pngData?.write(to: path)
        } catch {
            debugPrint(error)
        }
    }

    private func saveJSON(path: URL, imageName: String) {
        let json = """
        {
          "images" : [
            {
              "filename" : "\(imageName)@1x.png",
              "idiom" : "universal",
              "scale" : "1x"
            },
            {
              "filename" : "\(imageName)@2x.png",
              "idiom" : "universal",
              "scale" : "2x"
            },
            {
              "filename" : "\(imageName)@3x.png",
              "idiom" : "universal",
              "scale" : "3x"
            }
          ],
          "info" : {
            "author" : "https://github.com/IrelDev",
            "version" : 1
          },
          "properties" : {
            "preserves-vector-representation" : true,
            "template-rendering-intent" : "original"
          }
        }
        """
        do {
            try json.write(to: path.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        } catch {
            debugPrint(error)
        }
    }
}
