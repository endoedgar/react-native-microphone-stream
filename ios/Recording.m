#import <React/RCTEventEmitter.h>
#import <AVFoundation/AVFoundation.h>

@interface Recording : RCTEventEmitter <RCTBridgeModule>
- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue;
@end

@implementation Recording {
    AudioQueueRef _queue;
    AudioQueueBufferRef _buffer;
    id _audioData[4096];
    UInt32 _bufferSize;
    bool _isRecording;
}

void inputCallback(
        void *inUserData,
        AudioQueueRef inAQ,
        AudioQueueBufferRef inBuffer,
        const AudioTimeStamp *inStartTime,
        UInt32 inNumberPacketDescriptions,
        const AudioStreamPacketDescription *inPacketDescs) {
    [(__bridge Recording *) inUserData processInputBuffer:inBuffer queue:inAQ];
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(start:(int)sampleRate bufferSize:(int)bufferSize) {
    if (_isRecording) {
        return;
    }

    AudioStreamBasicDescription description;
    description.mReserved = 0;
    description.mSampleRate = sampleRate;
    description.mBitsPerChannel = 16;
    description.mChannelsPerFrame = 1;
    description.mFramesPerPacket = 1;
    description.mBytesPerFrame = 2;
    description.mBytesPerPacket = 2;
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kAudioFormatFlagIsSignedInteger;

    AudioQueueNewInput(&description, inputCallback, (__bridge void *) self, NULL, NULL, 0, &_queue);
    AudioQueueAllocateBuffer(_queue, (UInt32) (bufferSize * 2), &_buffer);
    AudioQueueEnqueueBuffer(_queue, _buffer, 0, NULL);
    AudioQueueStart(_queue, NULL);

    _bufferSize = (UInt32) bufferSize;
    _isRecording = true;
}

RCT_EXPORT_METHOD(stop) {
    AudioQueueStop(_queue, YES);
}

- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue {
    SInt16 *audioData = inBuffer->mAudioData;
    UInt32 count = inBuffer->mAudioDataByteSize / sizeof(SInt16);
    for (int i = 0; i < _bufferSize; i++) {
        _audioData[i] = @(audioData[i]);
    }
    [self sendEventWithName:@"recording" body:[NSArray arrayWithObjects:_audioData count:count]];
    AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"recording"];
}

-(void)dealloc {
    AudioQueueStop(_queue, YES);
}

@end
