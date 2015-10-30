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

@property (atomic, strong) NSNumber *currentPitch;

- (void) processAudio: (AudioBufferList*) bufferList;
@end