//
//  CTPitchTracker.m
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

#import "CTPitchTracker.h"
#import "CAStreamBasicDescription.h"
#import "CAXException.h"
#import "dywapitchtrack.h"

const int kMaxRecentPitches = 20;
const Float64 kGraphSampleRate = 44100.0;

@interface CTPitchTracker()
@property (nonatomic) AudioUnit rioUnit;
// Audio Stream Descriptions
@property (nonatomic) CAStreamBasicDescription outputCASBD;
@property (nonatomic) double sinPhase;
@property (nonatomic) dywapitchtracker tracker;
@property (nonatomic, strong) NSMutableArray *recentPitches;
@property (nonatomic) dispatch_queue_t analysisQueue;

@end

@implementation CTPitchTracker
- (NSMutableArray *)recentPitches {
    if (!_recentPitches) {
        _recentPitches = [[NSMutableArray alloc] initWithCapacity:kMaxRecentPitches];
    }
    return _recentPitches;
}

- (dispatch_queue_t)analysisQueue {
    if (!_analysisQueue) {
       _analysisQueue = dispatch_queue_create("com.stat10.chrotun.analysis", NULL);
    }
    return _analysisQueue;
}

// audio render procedure, don't allocate memory, don't take any locks, don't waste time
static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    CTPitchTracker *THIS = (__bridge CTPitchTracker *)inRefCon;

    AudioBuffer buffer;
    
	// Because of the way our audio format (setup below) is chosen:
	// we only need 1 buffer, since it is mono
	// Samples are 32 bits = 4 bytes.
	// 1 frame includes only 1 sample
    buffer.mNumberChannels = 1;
    buffer.mDataByteSize = inNumberFrames * 4;
    buffer.mData = malloc( inNumberFrames * 4 );
    
    // Put buffer in a AudioBufferList
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;

	try {
        // Obtain recorded samples
        
        XThrowIfError(AudioUnitRender(THIS.rioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList), "Failed to render input");
       
    }
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
	}

    dispatch_async(THIS.analysisQueue, ^{
        [THIS processAudio:(AudioBufferList *)&bufferList];
    });

    // release the malloc'ed data in the buffer we created earlier
    free(bufferList.mBuffers[0].mData);

    return noErr;
}

- (void)setupRemoteIO
{
    // set our required format - LPCM non-interleaved 32 bit floating point
    CAStreamBasicDescription outFormat = CAStreamBasicDescription(44100, // sample rate
                                                                  kAudioFormatLinearPCM, // format id
                                                                  4, // bytes per packet
                                                                  1, // frames per packet
                                                                  4, // bytes per frame
                                                                  1, // channels per frame
                                                                  32, // bits per channel
                                                                kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved);

	try {
		// Open the output unit
		AudioComponentDescription desc;
		desc.componentType = kAudioUnitType_Output;
		desc.componentSubType = kAudioUnitSubType_RemoteIO;
		desc.componentManufacturer = kAudioUnitManufacturer_Apple;
		desc.componentFlags = 0;
		desc.componentFlagsMask = 0;
		
		AudioComponent comp = AudioComponentFindNext(NULL, &desc);
		
		AudioComponentInstanceNew(comp, &_rioUnit);
        
		UInt32 one = 1;
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one)), "couldn't enable input on the remote I/O unit");
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = renderInput;
        callbackStruct.inputProcRefCon = (__bridge void*)self;
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, sizeof(callbackStruct)), "couldn't set remote i/o render callback");
		
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's output client format");
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &outFormat, sizeof(outFormat)), "couldn't set the remote I/O unit's input client format");
        
		XThrowIfError(AudioUnitInitialize(_rioUnit), "couldn't initialize the remote I/O unit");
		XThrowIfError(AudioOutputUnitStart(_rioUnit), "couldn't start the remote I/O unit");
	}
	catch (CAXException &e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
	catch (...) {
		fprintf(stderr, "An unknown error occurred\n");
	}
	
    // Allocate our own buffers (1 channel, 16 bits per sample, thus 16 bits per frame, thus 2 bytes per frame).
    // Practice learns the buffers used contain 512 frames, if this changes it will be fixed in processAudio.
    // will need float for accellerate fft (input is 16 bit signed integer) so make space...
    _tempBuffer.mNumberChannels = outFormat.mChannelsPerFrame;
    _tempBuffer.mDataByteSize = 512 * outFormat.mBytesPerFrame * 2;
    _tempBuffer.mData = malloc( self.tempBuffer.mDataByteSize );

}

- (id) init {
    if (self = [super init]) {
        [self setupRemoteIO];
        dywapitch_inittracking(&_tracker);
	}
	return self;
}

- (void) dealloc {
    dispatch_release(self.analysisQueue);
}

- (void) processAudio: (AudioBufferList*) bufferList{
    
    AudioBuffer sourceBuffer = bufferList->mBuffers[0];
	
	// fix tempBuffer size if it's the wrong size
	if (self.tempBuffer.mDataByteSize != sourceBuffer.mDataByteSize) {
		free(self.tempBuffer.mData);
		_tempBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
		_tempBuffer.mData = malloc(sourceBuffer.mDataByteSize);
	}
    
	// copy incoming audio data to temporary buffer
    memcpy(self.tempBuffer.mData, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);

    // calculate pitch
    int numberOfSamples = self.tempBuffer.mDataByteSize/4;
    float *samplesAsFloat = (float *)self.tempBuffer.mData;
    double *samplesAsDouble = (double *)malloc(numberOfSamples * sizeof(double));
    
    
    for (int i = 0; i < numberOfSamples; i++) {
        samplesAsDouble[i] = (double)samplesAsFloat[i];
    }
    
    self.currentPitch = [NSNumber numberWithDouble:dywapitch_computepitch(&_tracker, samplesAsDouble, 0, numberOfSamples)];
    if (self.recentPitches.count == kMaxRecentPitches) {
        [self.recentPitches removeLastObject];
    }
    [self.recentPitches insertObject:self.currentPitch atIndex:0];
    
    double runningTotal = 0.0;
    int validSamples = [self.recentPitches count];
    for(NSNumber *number in self.recentPitches)
    {
        if ([number doubleValue] > 0.0) {
            runningTotal += [number doubleValue];
        } else {
            validSamples--;
        }
    }
    
    self.averagePitch = [NSNumber numberWithDouble:(runningTotal / validSamples)];

}

@end
