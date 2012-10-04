//
//  CTViewController.m
//  Chrotun
//
//  Created by Axel Niklasson on 06/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CTViewController.h"
#import "CTPitchTracker.h"

@interface CTViewController()
@property (nonatomic, strong) NSTimer *timer;
@property (weak, nonatomic) IBOutlet UILabel *frequencyLabel;
@property (weak, nonatomic) IBOutlet UILabel *averageFrequencyLabel;
@property (weak, nonatomic) IBOutlet UIButton *startStopButton;
@property (nonatomic, strong) CTPitchTracker *pitchTracker;
@property (nonatomic, strong) NSNumberFormatter *formatter;
@end

@implementation CTViewController
- (NSNumberFormatter *)formatter {
    if (!_formatter) {
        _formatter = [[NSNumberFormatter alloc] init];
        [_formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [_formatter setMaximumFractionDigits:0];
    }
    return _formatter;
}

- (void)refreshFrequency {
    self.frequencyLabel.text = [NSString stringWithFormat:@"%@", [self.formatter stringFromNumber:self.pitchTracker.currentPitch]];
    self.averageFrequencyLabel.text = [NSString stringWithFormat:@"%@", [self.formatter stringFromNumber:self.pitchTracker.averagePitch]];
}

- (IBAction)startButtonPressed:(UIButton *)sender {
    if ([sender.titleLabel.text isEqualToString:@"Start"]) {
        // start
        [self.startStopButton setTitle:@"Stop" forState:UIControlStateNormal];
        self.pitchTracker = [[CTPitchTracker alloc] init];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(refreshFrequency) userInfo:nil repeats:YES];
        
    } else {
        // stop
        [self.startStopButton setTitle:@"Start" forState:UIControlStateNormal];
        self.frequencyLabel.text = @"[off]";
        self.pitchTracker = nil;
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

    self.frequencyLabel.text = @"[off]";
}

- (void)viewDidUnload
{
    [self setView:nil];
    [self setView:nil];
    [self setFrequencyLabel:nil];
    [self setStartStopButton:nil];
    [self setAverageFrequencyLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
