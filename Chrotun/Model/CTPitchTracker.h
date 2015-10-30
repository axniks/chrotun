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

- (instancetype)initWithPitchTrackingHandler:(void (^)(NSNumber *pitch))pitchHandler;

- (void) processAudio: (AudioBufferList*) bufferList;

@end