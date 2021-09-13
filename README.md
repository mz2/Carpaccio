### Carpaccio [SPM build & test passes](https://github.com/mz2/Carpaccio/actions/workflows/spm-build-test.yml/badge.svg) [![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
##### Pure Swift goodness for RAW and other image + metadata handling

Carpaccio is a Swift library for macOS and iOS that allows fast decoding of image data & EXIF metadata from file formats supported by CoreImage (including all the various RAW file formats supported, using the CoreImage RAW decoding capability).

- thumbnails
- metadata
- full sized image 

Carpaccio uses multiple CPU cores efficiently in parallel for all of metadata, thumbnail and image data decoding.

There are no 3rd party dependencies (CoreImage filter is used for RAW decoding).

**NOTE! If you are looking at this on GitHub, please be noted that the primary source for Carpaccio is to be found at [gitlab.com/sashimiapp-public/carpaccio.git](https://gitlab.com/sashimiapp-public/carpaccio.git).**

#### INSTALLATION

##### Swift Package Manager

Add Carpaccio to your Swift package as a dependency by adding the following to your Package.swift file in the dependencies array:

```swift
.package(url: "https://github.com/mz2/Carpaccio.git", from: "<version>")
```

If you are using Xcode 11 or newer, you can add Carpaccio by entering the URL to the repository via the File menu:

```
File > Swift Packages > Add Package Dependency...
```

#### USAGE

For usage examples, consult the unit tests under `Tests/CarpaccioTests`.

#### TODO

Carpaccio is still a very fresh and raw (har har) library and there are many tasks to make this a more generally useful library.

- [x] Add tests for RAWs from a number of different camera vendors.
- [x] GitHub action CI support.
- [x] iOS support.
- [ ] Working xcframework support (when Xcode / SPM toolchain permits?) An xcframework build is already made available, but at least with Xcode 12.5.1 this results in build fails of the following kinds: 
  - 'where' clause cannot be applied to a non-generic top-level declaration
  - 'Iterator' is not a member type of type 'Self'
  - 'Iterator' is not a member type of type 'Self'
  - Covariant 'Self' can only appear as the type of a property, subscript or method result; did you mean 'Collection'?
  - 'Index' is not a member type of class 'Carpaccio.Collection'
