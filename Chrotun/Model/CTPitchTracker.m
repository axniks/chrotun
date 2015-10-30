//
//  CTPitchTracker.m
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

#import "CTPitchTracker.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import "CAStreamBasicDescription.h"
#pragma clang diagnostic pop

#import "CAXException.h"
#import "dywapitchtrack.h"

const double kBytesPerSample = 4.0;
const int kSamplesNeeded = 2048;

@interface CTPitchTracker()
@property (nonatomic) AudioUnit rioUnit;
// Audio Stream Descriptions
@property (nonatomic) CAStreamBasicDescription outputCASBD;

@property (nonatomic, strong) NSMutableData *buffer;

@property (nonatomic) double sinPhase;
@property (nonatomic) dywapitchtracker tracker;
@property (nonatomic) dispatch_queue_t analysisQueue;

@property (nonatomic, copy) void (^pitchUpdateHandler)(NSNumber *pitch);

@end

@implementation CTPitchTracker
- (dispatch_queue_t)analysisQueue {
    if (!_analysisQueue) {
       _analysisQueue = dispatch_queue_create("com.stat10.chrotun.analysis", NULL);
    }
    return _analysisQueue;
}

// audio render procedure, don't allocate memory, don't take any locks, don't waste time
static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                            const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                            UInt32 inNumberFrames, AudioBufferList *ioData)
{
    CTPitchTracker *THIS = (__bridge CTPitchTracker *)inRefCon;

    AudioBuffer buffer;
    
	// Because of the way our audio format (setup below) is chosen:
	// we only need 1 buffer, since it is mono
	// Samples are 32 bits = 4 bytes.
	// 1 frame includes only 1 sample
    buffer.mNumberChannels = 1;
    buffer.mDataByteSize = inNumberFrames * kBytesPerSample;
    buffer.mData = malloc( inNumberFrames * kBytesPerSample );
    
    // Put buffer in a AudioBufferList
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0] = buffer;

	try {
        // Obtain recorded samples
        
        XThrowIfError(AudioUnitRender(THIS.rioUnit, ioActionFlags, inTimeStamp, inBusNumber,
                                      inNumberFrames, &bufferList), "Failed to render input");
       
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
    CAStreamBasicDescription outFormat = CAStreamBasicDescription
    (44100,                             // sample rate
     kAudioFormatLinearPCM,             // format id
     kBytesPerSample,                   // bytes per packet
     1,                                 // frames per packet
     kBytesPerSample,                   // bytes per frame
     1,                                 // channels per frame
     32,                                // bits per channel
     kAudioFormatFlagIsFloat |          // flags
     kAudioFormatFlagIsNonInterleaved);
    
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
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_EnableIO,
                                           kAudioUnitScope_Input, 1, &one, sizeof(one)),
                      "couldn't enable input on the remote I/O unit");
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = renderInput;
        callbackStruct.inputProcRefCon = (__bridge void*)self;
        
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioOutputUnitProperty_SetInputCallback,
                                           kAudioUnitScope_Global, 0, &callbackStruct,
                                           sizeof(callbackStruct)),
                      "couldn't set remote i/o render callback");
		
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Input, 0, &outFormat, sizeof(outFormat)),
                      "couldn't set the remote I/O unit's output client format");
        
		XThrowIfError(AudioUnitSetProperty(_rioUnit, kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output, 1, &outFormat,
                                           sizeof(outFormat)),
                      "couldn't set the remote I/O unit's input client format");
        
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

}

- (instancetype)initWithPitchTrackingHandler:(void (^)(NSNumber *pitch))pitchHandler {

    if (self = [super init]) {

        self.pitchUpdateHandler = pitchHandler;
        [self setupRemoteIO];
        dywapitch_inittracking(&_tracker);
    }
    return self;
}

- (void) dealloc {
//    dispatch_release(self.analysisQueue);
}

- (void) processAudio:(AudioBufferList*)bufferList {
    
    // create buffer with samples or append to existing buffer
    if (!self.buffer) {
        self.buffer = [NSMutableData dataWithBytes:bufferList->mBuffers[0].mData
                                            length:bufferList->mBuffers[0].mDataByteSize];
    } else {
        [self.buffer appendBytes:bufferList->mBuffers[0].mData
                          length:bufferList->mBuffers[0].mDataByteSize];
    }
    
    // check if we have enough samples to calculate pitch
    int numberOfSamples = self.buffer.length/kBytesPerSample;
    if (numberOfSamples >= kSamplesNeeded) {
        
        // convert samples to double
        float *samplesAsFloat = (float *)self.buffer.mutableBytes;
        double *samplesAsDouble = (double *)malloc(numberOfSamples * sizeof(double));
        for (int i = 0; i < numberOfSamples; i++) {
            samplesAsDouble[i] = (double)samplesAsFloat[i];
        }
    
        // calculate pitch
        double pitch = dywapitch_computepitch(&_tracker, samplesAsDouble, 0, numberOfSamples);
        
        if (self.pitchUpdateHandler && pitch != 0.0) {
            
            dispatch_async(dispatch_get_main_queue(), ^{

                self.pitchUpdateHandler(@(pitch));
            });
        }

        // purge buffer
        self.buffer = nil;
    }
}

@end
