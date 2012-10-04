//
//  CTHomeGrownFFTTracker.m
//  Chrotun
//
//  Created by Axel Niklasson on 03/10/2012.
//
//

// This is code "inspired" by a C# project I found here: http://www.codeproject.com/script/Articles/ViewDownloads.aspx?aid=32172
// not working in its current state

#import "CTHomeGrownFFTTracker.h"

@implementation CTHomeGrownFFTTracker

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

@end
