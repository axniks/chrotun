//
//  IosAudioController.h
//  Aruts
//
//  Created by Simon Epskamp on 10/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#ifndef max
#define max( a, b ) ( ((a) > (b)) ? (a) : (b) )
#endif

#ifndef min
#define min( a, b ) ( ((a) < (b)) ? (a) : (b) )
#endif

void checkStatus(int status);

@interface IosAudioController : NSObject {
	AudioComponentInstance audioUnit;
	AudioBuffer tempBuffer; // this will hold the latest data from the microphone
}

@property (readonly) AudioComponentInstance audioUnit;
@property (readonly) AudioBuffer tempBuffer;
@property (nonatomic) SInt32 *fftOutData;
@property (nonatomic) int32_t fftLength;
@property (nonatomic) BOOL isRunning;

- (void) start;
- (void) stop;
- (void) processAudio: (AudioBufferList*) bufferList;

@end

// setup a global iosAudio variable, accessible everywhere
extern IosAudioController* iosAudio;