[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](https://swiftpackageindex.com/kvyatkovskys/KVKToast)
[![Platform](https://img.shields.io/cocoapods/p/KVKToast.svg?style=flat)](https://cocoapods.org/pods/KVKToast)
[![License](https://img.shields.io/cocoapods/l/KVKToast.svg?style=flat)](https://cocoapods.org/pods/KVKToast)

# KVKSocket

## Requirements

- iOS 13.0+, iPadOS 13.0+, MacOS 10.15+
- Swift 5.0+

## Installation

**KVKSocket** is available through [Swift Package Manager](https://swift.org/package-manager/).

### Swift Package Manager (Xcode 12 or higher)

1. In Xcode navigate to **File** → **Swift Packages** → **Add Package Dependency...**
2. Select a project
3. Paste the repository URL (`https://github.com/kvyatkovskys/KVKSocket.git`) and click **Next**.
4. For **Rules**, select **Version (Up to Next Major)** and click **Next**.
5. Click **Finish**.

[Adding Package Dependencies to Your App](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app)

## Step for usage

- Import `KVKSocket`

- Create a object
```swift
let socket = WebSocket(parameters: WebSocket.Parameters(host: "localhost",
                                                        path: "/cards",
                                                        port: 8080,
                                                        scheme: "ws",
                                                        sendPingPong: true))
```

- Connect to scoket 
```swift
socket?.connect()
```

- Subscribe on events
```swift
socket?.event.sink { (event) in
    switch event {
    case .connected:
        print("Socket did connect")
    case .disconnected(_, _):
        print("Socket did disconnect")
    case .error(let error):
        if let err = error {
            print(err)
        }
    case .ping:
        print("ping")
    case .pong(let date):
        print("pong", date)
    case .message(let msg):
        switch msg {
        case .text(let txt):
            print(txt)
        case .binary(let data):
            print(String(data: data, encoding: .utf8) ?? "")
        }
    case .reconnecting:
        print("reconnecting")
    }
}
```

- Disconnect
```swift
socket?.disconnect()
```

## Author

[Sergei Kviatkovskii](https://github.com/kvyatkovskys)

## License

KVKToast is available under the [MIT license](https://github.com/kvyatkovskys/KVKSocket/blob/master/LICENSE.md)
