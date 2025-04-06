#import <XCTest/XCTest.h>
#import "VADWrapper.h"

@interface MockVADDelegate : NSObject <VADDelegate>
@property (nonatomic, assign) BOOL voiceStartedCalled;
@property (nonatomic, strong) NSData *receivedWavData;
@property (nonatomic, strong) NSData *receivedPCMFloatData;
@end

@implementation MockVADDelegate

- (void)voiceStarted {
    self.voiceStartedCalled = YES;
}

- (void)voiceEndedWithWavData:(NSData *)wavData {
    self.receivedWavData = wavData;
}

- (void)voiceDidContinueWithPCMFloatData:(NSData *)pcmFloatData { 
    self.receivedPCMFloatData = pcmFloatData;
}


@end

@interface RealTimeCutVADLibraryTests : XCTestCase
@property (nonatomic, strong) VADWrapper *vadManager;
@property (nonatomic, strong) MockVADDelegate *mockDelegate;
@end

@implementation RealTimeCutVADLibraryTests

- (void)setUp {
    [super setUp];
    self.vadManager = [[VADWrapper alloc] init];
    self.mockDelegate = [[MockVADDelegate alloc] init];
    self.vadManager.delegate = self.mockDelegate;
}

- (void)tearDown {
    self.vadManager = nil;
    self.mockDelegate = nil;
    [super tearDown];
}

- (void)testVADWrapperInitialization {
    XCTAssertNotNil(self.vadManager, @"VADWrapper should be initialized");
}

- (void)testSetSileroModel {
    XCTAssertNoThrow([self.vadManager setSileroModel:v4], @"Setting model v4 should not throw");
    XCTAssertNoThrow([self.vadManager setSileroModel:v5], @"Setting model v5 should not throw");
}

- (void)testSetSamplerate {
    XCTAssertNoThrow([self.vadManager setSamplerate:SAMPLERATE_16], @"Setting samplerate should not throw an exception");
}

- (void)testSetThreshold {
    XCTAssertNoThrow([self.vadManager setThresholdWithVadStartDetectionProbability:0.5
                                                         VadEndDetectionProbability:0.5
                                                             VoiceStartVadTrueRatio:0.7
                                                             VoiceEndVadFalseRatio:0.3
                                                               VoiceStartFrameCount:10
                                                                 VoiceEndFrameCount:5],
                     @"Setting threshold values should not throw an exception");
}

- (void)testDelegateVoice {
    // 1. バンドル内の PCM ファイルのパスを取得
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"16khz_32bitfloat" ofType:@"pcm"];
    XCTAssertNotNil(filePath, @"PCM file path should not be nil");

    // 2. PCMデータを読み込む
    NSData *audioData = [NSData dataWithContentsOfFile:filePath];
    XCTAssertNotNil(audioData, @"PCM data should not be nil");

    // 3. PCM データを `NSArray<NSNumber *>` に変換（32-bit float）
    NSUInteger sampleCount = audioData.length / sizeof(float);
    NSLog(@"------ PCM Data Count: %lu ------", (unsigned long)sampleCount);

    NSMutableArray<NSNumber *> *audioSamples = [NSMutableArray arrayWithCapacity:sampleCount];
    const float *pcmFloatData = (const float *)[audioData bytes];

    for (NSUInteger i = 0; i < sampleCount; i++) {
        [audioSamples addObject:@(pcmFloatData[i])];
    }
    
    // 4. VAD の設定を行う
    [self.vadManager setSileroModel:v4];
    [self.vadManager setSamplerate:SAMPLERATE_16];

    // 5. VAD に PCM オーディオデータを渡して処理
    [self.vadManager processAudioData:audioSamples];

    // 6. デリゲートのコールバックが正常に呼ばれたか確認
    XCTAssertTrue(self.mockDelegate.voiceStartedCalled, @"voiceStarted should be called on delegate");
    XCTAssertNotNil(self.mockDelegate.receivedWavData, @"voiceEndedWithWavData should be called with valid data");
    XCTAssertNotNil(self.mockDelegate.receivedPCMFloatData, @"voiceDidContinueWithPCMFloatData should be called with valid data");
}


@end
