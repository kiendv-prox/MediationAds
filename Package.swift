// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MediationAds",
  platforms: [
    .iOS(.v14)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "MediationAds",
      targets: ["MediationAds"]),
  ],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", revision: "11.13.0"),
    .package(url: "https://github.com/AppsFlyerSDK/AppsFlyerFramework", revision: "6.17.0"),
    .package(url: "https://github.com/AppsFlyerSDK/appsflyer-apple-purchase-connector", revision: "6.16.2"),
    .package(url: "https://github.com/Kitura/Swift-JWT", revision: "3.6.201"),
    .package(url: "https://github.com/SnapKit/SnapKit", revision: "5.7.1")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "MediationAds",
      dependencies: [
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
        .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
        .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
        //                .product(name: "FirebaseABTesting", package: "firebase-ios-sdk"),
        .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
        .product(name: "AppsFlyerLib", package: "AppsFlyerFramework"),
        .product(name: "PurchaseConnector", package: "appsflyer-apple-purchase-connector"),
        .product(name: "SwiftJWT", package: "swift-jwt")
      ]
    ),
  ]
)
