//
//  IosAudioController.m
//  Aruts
//
//  Created by Simon Epskamp on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "IosAudioController.h"
#import <Accelerate/Accelerate.h>

#define kOutputBus 0
#define kInputBus 1

IosAudioController* iosAudio;

void checkStatus(int status){
	if (status) {
		printf("Status not 0! %d\n", status);
//		exit(1);
	}
}

/**
 This callback is called when new audio data from the microphone is
 available.
 */
static OSStatus recordingCallback(void *inRefCon, 
                                  AudioUnitRenderActionFlags *ioActionFlags, 
                                  const AudioTimeStamp *inTimeStamp, 
                                  UInt32 inBusNumber, 
                                  UInt32 inNumberFrames, 
                                  AudioBufferList *ioData) {
	
	// Because of the way our audio format (setup below) is chosen:
	// we only need 1 buffer, since it is mono
	// Samples are 32 bits = 4 bytes.
	// 1 frame includes only 1 sample
	
	AudioBuffer buffer;
	
	buffer.mNumberChannels = 1;
	buffer.mDataByteSize = inNumberFrames * 4;
	buffer.mData = malloc( inNumberFrames * 4 );
	
	// Put buffer in a AudioBufferList
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0] = buffer;
	
    // Then:
    // Obtain recorded samples
	
    OSStatus status;
	
    status = AudioUnitRender([iosAudio audioUnit], 
                             ioActionFlags, 
                             inTimeStamp, 
                             inBusNumber, 
                             inNumberFrames, 
                             &bufferList);
	checkStatus(status);
	
    // Now, we have the samples we just read sitting in buffers in bufferList
	// Process the new data
	[iosAudio processAudio:&bufferList];
	
	// release the malloc'ed data in the buffer we created earlier
	free(bufferList.mBuffers[0].mData);
	
    return noErr;
}

@implementation IosAudioController {
    FFTSetup _fftSetup;
    DSPSplitComplex _A;
    Float32 _fftNormFactor;
    Float32 _adjust0DB;
    Float32 _24BitFracScale;
    Float32 *_tmpData;

}

@synthesize audioUnit, tempBuffer;
@synthesize fftOutData = _fftOutData;
@synthesize fftLength = _fftLength;
@synthesize isRunning = _isRunning;


/**
 Initialize the audioUnit and allocate our own temporary buffer.
 The temporary buffer will hold the latest data coming in from the microphone,
 and will be copied to the output when this is requested.
 */

- (id) init {
	self = [super init];
	    
	OSStatus status;
	
	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio units
	status = AudioComponentInstanceNew(inputComponent, &audioUnit);
	checkStatus(status);
	
	// Enable IO for recording
	UInt32 flag = 1;
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, 
								  kAudioUnitScope_Input, 
								  kInputBus,
								  &flag, 
								  sizeof(flag));
	checkStatus(status);
		
	// Describe format
	AudioStreamBasicDescription audioFormat;
	audioFormat.mSampleRate			= 44100.00;
	audioFormat.mFormatID			= kAudioFormatLinearPCM;
	audioFormat.mFormatFlags		= kAudioFormatFlagIsPacked | kAudioFormatFlagIsFloat;
	audioFormat.mFramesPerPacket	= 1;
	audioFormat.mChannelsPerFrame	= 1;
	audioFormat.mBitsPerChannel		= 32;
	audioFormat.mBytesPerPacket		= 4;
	audioFormat.mBytesPerFrame		= 4;
	
	// Apply format
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Output, 
								  kInputBus, 
								  &audioFormat, 
								  sizeof(audioFormat));
	checkStatus(status);
	
    Float32 preferredBufferSize = .005;
    status = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, 
                                     sizeof(preferredBufferSize), 
                                     &preferredBufferSize);
	checkStatus(status);
    
	// Set input callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc = recordingCallback;
	callbackStruct.inputProcRefCon = (__bridge void *)self;
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioOutputUnitProperty_SetInputCallback, 
								  kAudioUnitScope_Global, 
								  kInputBus, 
								  &callbackStruct, 
								  sizeof(callbackStruct));
	checkStatus(status);
	
	// Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
	flag = 0;
	status = AudioUnitSetProperty(audioUnit, 
								  kAudioUnitProperty_ShouldAllocateBuffer,
								  kAudioUnitScope_Output, 
								  kInputBus,
								  &flag, 
								  sizeof(flag));
    checkStatus(status);

    // Find max number of frames per slice to get right dimension of FFT length
    UInt32 size, maxFPS;
    size = sizeof(maxFPS);
    status = AudioUnitGetProperty(audioUnit, 
                                  kAudioUnitProperty_MaximumFramesPerSlice, 
                                  kAudioUnitScope_Global, 
                                  0, 
                                  &maxFPS, 
                                  &size);
    checkStatus(status);

    self.fftLength = 128;
    
    _fftSetup = vDSP_create_fftsetup(log2(128), kFFTRadix2);
    if (_fftSetup == 0) NSLog(@"ERR - Failed to created FFT setup.");
    
    _A.realp = (Float32*) calloc(self.fftLength, sizeof(Float32));
    _A.imagp = (Float32*) calloc(self.fftLength, sizeof(Float32));

    self.fftOutData = (SInt32 *) calloc(self.fftLength, sizeof(SInt32));
    
    _fftNormFactor = 1.0/(2*2*self.fftLength);
    _adjust0DB = 1.5849e-13;
    _24BitFracScale = 16777216.0f;
    _tmpData = (Float32 *) calloc(self.fftLength, sizeof(Float32));
    
	// Allocate our own buffers (1 channel, 16 bits per sample, thus 16 bits per frame, thus 2 bytes per frame).
	// Practice learns the buffers used contain 512 frames, if this changes it will be fixed in processAudio.
    // will need float for accellerate fft (input is 16 bit signed integer) so make space...
    tempBuffer.mNumberChannels = audioFormat.mChannelsPerFrame;
	tempBuffer.mDataByteSize = 512 * audioFormat.mBytesPerFrame * 2;
	tempBuffer.mData = malloc( tempBuffer.mDataByteSize );
    
    self.isRunning = NO;
    
    // Initialise
	status = AudioUnitInitialize(audioUnit);
	checkStatus(status);
	
	return self;
}

/**
 Start the audioUnit. This means data will be provided from
 the microphone, and requested for feeding to the speakers, by
 use of the provided callbacks.
 */
- (void) start {
	OSStatus status = AudioOutputUnitStart(audioUnit);
    self.isRunning = YES;
	checkStatus(status);
}

/**
 Stop the audioUnit
 */
- (void) stop {
	OSStatus status = AudioOutputUnitStop(audioUnit);
    self.isRunning = NO;
	checkStatus(status);
}

/**
 Change this funtion to decide what is done with incoming
 audio data from the microphone.
 Right now we copy it to our own temporary buffer.
 */


- (void) processAudio: (AudioBufferList*) bufferList{
    	
    AudioBuffer sourceBuffer = bufferList->mBuffers[0];
	
	// fix tempBuffer size if it's the wrong size
	if (tempBuffer.mDataByteSize != sourceBuffer.mDataByteSize) {
		free(tempBuffer.mData);
		tempBuffer.mDataByteSize = sourceBuffer.mDataByteSize;
		tempBuffer.mData = malloc(sourceBuffer.mDataByteSize);
	}
    
	// copy incoming audio data to temporary buffer
    memcpy(tempBuffer.mData, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);

    vDSP_ctoz((COMPLEX *)tempBuffer.mData, 2, &_A, 1, self.fftLength);
    vDSP_fft_zrip(_fftSetup, &_A, 1, log2(512), kFFTDirection_Forward);
    vDSP_vsmul(_A.realp, 1, &_fftNormFactor, _A.realp, 1, self.fftLength);
    vDSP_vsmul(_A.imagp, 1, &_fftNormFactor, _A.imagp, 1, self.fftLength);

    //Zero out the nyquist value
    _A.imagp[0] = 0.0;

    //Convert the fft data to dB
    vDSP_zvmags(&_A, 1, _tmpData, 1, self.fftLength);

    //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
    vDSP_vsadd(_tmpData, 1, &_adjust0DB, _tmpData, 1, self.fftLength);
    Float32 one = 1;
    vDSP_vdbcon(_tmpData, 1, &one, _tmpData, 1, self.fftLength, 0);
    
    //Convert floating point data to integer (Q7.24)
    vDSP_vsmul(_tmpData, 1, &_24BitFracScale, _tmpData, 1, self.fftLength);

    memset(self.fftOutData, 0, self.fftLength*sizeof(SInt32));
    
    for(UInt32 i=0; i<self.fftLength; ++i)
        self.fftOutData[i] = (SInt32) _tmpData[i];

}


/**
 Clean up.
 */
- (void) dealloc {
	AudioUnitUninitialize(audioUnit);
	free(tempBuffer.mData);
    vDSP_destroy_fftsetup(_fftSetup);
}

@end

/* 
 - (int)Log2:(int)n
 {
 int i = 0;
 while (n > 0)
 {
 ++i; n >>= 1;
 }
 return i;
 }
 
 - (BOOL)IsPowerOfTwo:(int) n
 {            
 return n > 1 && (n & (n - 1)) == 0;
 }
 
 - (int)ReverseBits:(int)n WithCount:(int)bitsCount
 {
 int reversed = 0;
 for (int i = 0; i < bitsCount; i++)
 {
 int nextBit = n & 1;
 n >>= 1;
 
 reversed <<= 1;
 reversed |= nextBit;
 }
 return reversed;
 }
 
 typedef struct {
 float real;
 float imaginary;
 } complex;
 
 - (complex)sumOf:(complex)operand1 And:(complex)operand2 {
 complex result;
 result.real = operand1.real + operand2.real;
 result.imaginary = operand1.imaginary + operand2.imaginary;
 return result;
 }
 
 - (double)absoluteSquareOf:(complex)operand {
 double result = operand.real * operand.real + operand.imaginary* operand.imaginary;
 return result;
 }
 
 - (complex)poweredE:(complex)operand {
 complex result;
 result.real = exp(operand.real) * cos(operand.imaginary);
 result.imaginary = exp(operand.real) * sin(operand.imaginary);
 return operand;
 }
 
 - (complex)productOf:(complex)operand1 And:(complex)operand2 {
 complex result;
 result.real = operand1.real * operand2.real - operand1.imaginary * operand2.imaginary;
 result.imaginary = operand1.imaginary * operand2.real + operand1.real * operand2.imaginary;
 return operand1;
 }
 
 - (complex)differenceBetween:(complex)operand1 And:(complex)operand2 {
 complex result;
 result.real = operand1.real - operand2.real;
 result.imaginary = operand1.imaginary - operand2.imaginary;
 return result;
 }
 
 - (void)CalculateFFTForData:(int16_t *)samples WithByteSize:(UInt32) size {
 int length = size/2;
 int bitsInLength;
 
 if ([self IsPowerOfTwo:length])
 {
 length = size/2;
 bitsInLength = [self Log2:length] - 1;
 }
 else
 {
 bitsInLength = [self Log2:size/2];
 length = 1 << bitsInLength;
 // the items will be pad with zeros
 }
 
 // bit reversal
 complex data[length];
 
 for (int i = 0; i < length; i++)
 {
 int j = [self ReverseBits:i WithCount:bitsInLength];
 complex number;
 number.real = samples[i]; // is this the right way to get to the samples?
 number.imaginary = 0;
 data[j] = number;
 }
 
 // Cooley-Tukey 
 for (int i = 0; i < bitsInLength; i++)
 {
 
 int m = 1 << i;
 int n = m * 2;
 double alpha = -(2 * M_PI / n);
 
 for (int k = 0; k < m; k++)
 {
 // e^(-2*pi/N*k)
 complex oddPartMultiplier;
 oddPartMultiplier.real = 0;
 oddPartMultiplier.imaginary = alpha * k; // this will be an integer now? cast it?
 
 oddPartMultiplier = [self poweredE:oddPartMultiplier];
 
 for (int j = k; j < length; j += n)
 {
 complex evenPart = data[j];
 complex oddPart = [self productOf:oddPartMultiplier And:data[j + m]];   // multiply oddPartMultiplier and data[j+m] to oddPart
 data[j] = [self sumOf:evenPart And:oddPart];                            // add evenPart and oddPart and store in data[j]
 data[j + m] = [self differenceBetween:evenPart And:oddPart];            // subtract oddPart from evenPart and store in data[j + m]
 }
 }
 }
 
 }
 */

