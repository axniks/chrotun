//
//  CTAccelerateFFTPitchTracker.h
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

#import "CTPitchTracker.h"

@interface CTAccelerateFFTPitchTracker : CTPitchTracker

@property (nonatomic) SInt32 *fftOutData;
@property (nonatomic) int32_t fftLength;

@end
