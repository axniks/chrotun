//
//  CTPitchTracker.h
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface CTPitchTracker : NSObject
@property (nonatomic) AudioBuffer tempBuffer;

@property (atomic, strong) NSNumber *currentPitch;
@property (atomic, strong) NSNumber *averagePitch;

- (void) processAudio: (AudioBufferList*) bufferList;

@end