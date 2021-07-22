- Note: This is an adaptation for iOS of the sample code project associated with WWDC20 session [10011: Authoring Fragmented MPEG-4 with AVAssetWriter](https://developer.apple.com/videos/play/wwdc2020/10011).

## To run the iOS project
- Select the iOSWriter schema and run it.

The segment generation will start after the view controller is loaded and once it's done, it'll show you a `UIActivityController` to share the output folder.

> Notice that the input video is 10 seconds long but the output is only 6 seconds long.


## To run the macOS project

Before you run the sample code project in Xcode:

1. Edit the shared scheme called `fmp4Writer`.
2. Open the Run action.
3. Replace the _\<path to movie file on disk\>_ argument with the path to a movie file on your local hard drive.
4. Replace the _\<path to output directory\>_ argument  with your desired output directory; for example `~/Desktop/fmp4writer/`.

## Changes for making it work in iOS
- Use an asset from the app bundle instead of reading the asset from the file system.
- Copy the code from main.swift file to the ViewController.swift
- In `videoCompressionSettings`, change the value of the key `kVTCompressionPropertyKey_ProfileLevel` from `kVTProfileLevel_H264_High_4_2` to `kVTProfileLevel_H264_High_4_1`.


