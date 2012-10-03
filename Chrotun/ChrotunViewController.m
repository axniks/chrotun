//
//  ChrotunViewController.m
//  Chrotun
//
//  Created by Axel Niklasson on 06/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ChrotunViewController.h"
#import "IosAudioController.h"
#import "dywapitchtrack.h"

@interface ChrotunViewController()
@property (nonatomic, strong) NSTimer *timer;
@property (weak, nonatomic) IBOutlet UILabel *frequencyLabel;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;

@end

@implementation ChrotunViewController

- (SInt32)indexForFundamentalFrequency
{
    if (iosAudio.isRunning) {
        SInt32 *result = iosAudio.fftOutData;
        SInt32 maxValue = *result;
        int32_t maxIndex = 0;
        int32_t length = iosAudio.fftLength;
        
        for (int i=0; i<length; i++) {
            if (result[i]>maxValue) {
                maxValue = result[i];
                maxIndex = i;
            }
        }
        return maxIndex;
    } 
    else
        return 0;
}

- (void)refreshFrequency {
    self.frequencyLabel.text = [NSString stringWithFormat:@"%ld", [self indexForFundamentalFrequency]];
}

/*
- (SInt32 *)getFFTData
{
    if (iosAudio.isRunning) return iosAudio.fftOutData; 
    else return 0;
}

- (int32_t)getFFTLength
{
    if (iosAudio.isRunning) return iosAudio.fftLength;
    else return 0;
}
*/
- (IBAction)startButtonPressed:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"Start"]) {
        // start
        [self.startStopButton setTitle:@"Stop" forState:UIControlStateNormal];
        [iosAudio start];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(refreshFrequency) userInfo:nil repeats:YES];
        
    } else {
        // stop
        [self.startStopButton setTitle:@"Start" forState:UIControlStateNormal];
        self.frequencyLabel.text = @"-";
        [iosAudio stop];
        [self.timer invalidate];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    iosAudio = [[IosAudioController alloc] init];

}

- (void)viewDidUnload
{
    [self setView:nil];
    [self setView:nil];
    [self setFrequencyLabel:nil];
    [self setStartStopButton:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
