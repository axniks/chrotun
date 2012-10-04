//
//  CTAccelerateFFTPitchTracker.m
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

#import "CTAccelerateFFTPitchTracker.h"
#import <Accelerate/Accelerate.h>

@implementation CTAccelerateFFTPitchTracker {
    FFTSetup _fftSetup;
    DSPSplitComplex _A;
    Float32 _fftNormFactor;
    Float32 _adjust0DB;
    Float32 _24BitFracScale;
    Float32 *_tmpData;
    
}

@synthesize fftOutData = _fftOutData;
@synthesize fftLength = _fftLength;

- (id)init {
    self = [super init];
    
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
    
    return self;
}

- (void)analyzeBuffer {
    /*
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
     */
}

/**
 Clean up.
 */
- (void) dealloc {
    vDSP_destroy_fftsetup(_fftSetup);
}

@end
