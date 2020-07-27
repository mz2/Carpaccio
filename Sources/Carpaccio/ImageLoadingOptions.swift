//
//  ImageLoadingOptions.swift
//  Carpaccio
//
//  Created by Markus on 27.6.2020.
//  Copyright © 2020 Matias Piipari & Co. All rights reserved.
//
import Foundation
import CoreGraphics

public struct ImageLoadingOptions {
    public let maximumPixelDimensions: CGSize?

    public let allowDraftMode: Bool
    public let baselineExposure: Double?
    public let noiseReductionAmount: Double
    public let colorNoiseReductionAmount: Double
    public let noiseReductionSharpnessAmount: Double
    public let noiseReductionContrastAmount: Double
    public let boostShadowAmount: Double
    public let enableVendorLensCorrection: Bool

    public init(
        maximumPixelDimensions: CGSize? = nil,
        allowDraftMode: Bool = true,
        baselineExposure: Double? = nil,
        noiseReductionAmount: Double = 0.5,
        colorNoiseReductionAmount: Double = 1.0,
        noiseReductionSharpnessAmount: Double = 0.5,
        noiseReductionContrastAmount: Double = 0.5,
        boostShadowAmount: Double = 2.0,
        enableVendorLensCorrection: Bool = true
    ) {
        self.maximumPixelDimensions = maximumPixelDimensions
        self.allowDraftMode = allowDraftMode
        self.baselineExposure = baselineExposure
        self.noiseReductionAmount = noiseReductionAmount
        self.colorNoiseReductionAmount = colorNoiseReductionAmount
        self.noiseReductionSharpnessAmount = noiseReductionSharpnessAmount
        self.noiseReductionContrastAmount = noiseReductionContrastAmount
        self.boostShadowAmount = boostShadowAmount
        self.enableVendorLensCorrection = enableVendorLensCorrection
    }
}
