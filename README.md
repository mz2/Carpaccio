### Carpaccio [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
##### Cocoa wrapper for the libraw RAW converter library

Carpaccio is a Cocoa wrapper to the [LibRaw](http://www.libraw.org/docs/API-CXX-eng.html) C / C++ RAW image conversion library.

#### INSTALLATION

**NOTE:** As a prerequisite to building & installing the framework any route you choose, it is assumed that [LibRaw](http://www.libraw.org/docs/API-CXX-eng.html) is available under `/usr/local/lib` and its headers under `/usr/local/include`. 

The easiest way to make that happen is with `brew install libraw`. Note that Carpaccio uses LibRaw built as a static library as part of its build and therefore your end users will not need to have LibRaw installed under /usr/local/lib.

##### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Carpaccio into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "mz2/Carpaccio" ~> 0.0.1
```

Run `carthage update` to build the framework and drag the built `Carpaccio.framework` into your Xcode project.

### Manually

If you prefer not to use either of the aforementioned dependency managers, you can integrate Carpaccio into your project manually.

#### Embedded Framework

- Open up Terminal, `cd` into your top-level project directory, and run the following command "if" your project is not initialized as a git repository:

```bash
$ git init
```

- Add Carpaccio as a git [submodule](http://git-scm.com/docs/git-submodule) by running the following command:

```bash
$ git submodule add https://github.com/mz2/Carpaccio.git
```

- Open the new `Carpaccio` folder, and drag the `Carpaccio.xcodeproj` into the Project Navigator of your application's Xcode project.

    > It should appear nested underneath your application's blue project icon. Whether it is above or below all the other Xcode groups does not matter.

- Select the `Carpaccio.xcodeproj` in the Project Navigator and verify the deployment target matches that of your application target.
- Next, select your application project in the Project Navigator (blue project icon) to navigate to the target configuration window and select the application target under the "Targets" heading in the sidebar.
- In the tab bar at the top of that window, open the "General" panel.
- Click on the `+` button under the "Embedded Binaries" section.
- Select the `Carpaccio.xcodeproj` nested inside a `Products` folder now visible.

> The `Carthage.framework` is automagically added as a target dependency, linked framework and embedded framework in a copy files build phase which is all you need to build on the simulator and a device.

(This manual installation section was shamelessly ripped from the excellent [Alamofire](github.com/alamofire/Alamofire) instructions.)

#### USAGE

Adapting from a test included in the test suite for the framework, here's how you can use Carpaccio:

```Swift
        let img1URL = NSBundle(forClass: self.dynamicType).URLForResource("DSC00583", withExtension: "ARW")!
        let tempDir = NSURL(fileURLWithPath:NSTemporaryDirectory().stringByAppendingString("/\(NSUUID().UUIDString)"))
        try! NSFileManager.defaultManager().createDirectoryAtURL(tempDir, withIntermediateDirectories: true, attributes: [:])
        
        let converter = RAWConverter(URL: img1URL, convertedImagesRootURL:tempDir)
        
        converter.decodeContentsOfURL(img1URL,
                                      thumbnailHandler:
            { thumb in
                // do stuff with the thumbnail
            }, imageHandler: { imgURL in
                // do stuff with the TIFF image URL
        }) { err in
          // handle error
        }
```

#### TODO

Carpaccio is still a very fresh and raw (har har) library and there are many tasks to make this a more generally useful library.

- [ ] As part of the build process, help with building your own copy of [LibRaw](http://www.libraw.org/docs/API-CXX-eng.html) library instead of assuming one sits under `/usr/local/lib`. 
- [ ] Switch the `RAWConverter` implementation to using the libraw C API instead of the C++ API to allow for a pure Swift implementation.
- [ ] Add tests for RAWs from a number of different camera vendors.
- [ ] Travis CI support.
- [ ] iOS support.
