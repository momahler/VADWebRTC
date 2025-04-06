//
//  VADWrapper.h
//  RealTimeCutVADLibrary
//
//  Created by Yasushi Sakita on 2025/02/03.
//
// Voice Activity Detection (VAD) Library Header File
// This file defines enums, protocols, and the VADWrapper interface for real-time voice detection.
//

#import <Foundation/Foundation.h>

// Enumeration for supported sample rates
typedef NS_ENUM(NSInteger, SL) {
    SAMPLERATE_8 = 0,   // 8 kHz sample rate
    SAMPLERATE_16 = 1,  // 16 kHz sample rate
    SAMPLERATE_24 = 2,  // 24 kHz sample rate
    SAMPLERATE_48 = 3,  // 48 kHz sample rate
};

// Enumeration for Silero Model Versions
// Choose between version 4 (v4) and version 5 (v5)
typedef NS_ENUM(NSInteger, SMVER) {
    v4 = 0, // Silero Model Version 4
    v5 = 1, // Silero Model Version 5
};

// VADDelegate Protocol
// Observer methods to detect the start and end of voice activity.
@protocol VADDelegate <NSObject>

// Called when voice activity starts
- (void)voiceStarted;

// Called when voice activity ends, providing the recorded WAV data
// The extracted audio data is always at a sample rate of 16 kHz.
// Internal sample rate conversion is performed automatically.
- (void)voiceEndedWithWavData:(NSData *)wavData;

// Called continuously during voice activity with the current chunk of denoised PCM float data.
// The data is 32-bit floating point (IEEE 754), mono, and at a sample rate of 16 kHz.
// This allows real-time processing or streaming of voice segments while recording is still in progress.
- (void)voiceDidContinueWithPCMFloatData:(NSData *)pcmFloatData;

@end

// VADWrapper Interface
// Manages voice activity detection with customizable parameters and processing.
@interface VADWrapper : NSObject

// Delegate to observe voice start and end events
@property (nonatomic, weak) id<VADDelegate> delegate;

// Initializes the VADWrapper instance
- (instancetype)init;

// Deallocates the VADWrapper instance
- (void)dealloc;

// Sets the sample rate for audio processing
- (void)setSamplerate:(SL)sl;

// Configures VAD detection thresholds
// This method allows customization of the thresholds used for voice activity detection.
// The following parameters have default values but can be adjusted as needed:
//
// a - Probability threshold for starting VAD detection (default: 0.7)
// b - Probability threshold for ending VAD detection (default: 0.7)
// c - True positive ratio for voice start detection (default: 0.8)
// d - False positive ratio for voice end detection (default: 0.95)
// e - Frame count required to confirm voice start (default: 10, equivalent to 0.32 seconds with 16 kHz sample rate)
// f - Frame count required to confirm voice end (default: 57, equivalent to 1.792 seconds with 16 kHz sample rate)
//
// Note: Each VAD frame represents 0.032 seconds (1 / 16000 * 512 samples).
- (void)setThresholdWithVadStartDetectionProbability:(float)a
                          VadEndDetectionProbability:(float)b
                              VoiceStartVadTrueRatio:(float)c
                              VoiceEndVadFalseRatio:(float)d
                                VoiceStartFrameCount:(int)e
                                  VoiceEndFrameCount:(int)f;


/// Processes audio data for VAD (deprecated)
/// @discussion This method is slow due to unnecessary NSNumber boxing.
/// Use `processAudioDataWithBuffer:count:` instead.
/// @deprecated Use `processAudioDataWithBuffer:count:` instead.
- (void)processAudioData:(NSArray<NSNumber *> *)audioData __attribute__((deprecated("This method is slow due to unnecessary NSNumber boxing. Use processAudioDataWithBuffer:count: instead.")));

// Processes audio data for VAD
// Accepts an array of NSNumber representing float audio points (mono only)
- (void)processAudioDataWithBuffer:(const float *)audioData count:(NSUInteger)count;

// Sets the Silero model version to use for VAD
- (void)setSileroModel:(SMVER)modelVersion;

@end
