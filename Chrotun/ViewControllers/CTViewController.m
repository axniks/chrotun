//
//  CTViewController.m
//  Chrotun
//
//  Created by Axel Niklasson on 06/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CTViewController.h"
#import "CTPitchTracker.h"

static const float kCTTolerance = 0.3;

@interface CTViewController()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) CTPitchTracker *pitchTracker;
@property (nonatomic, strong) NSNumberFormatter *formatter;
@property (nonatomic, strong) NSArray *stringLabels;
@property (weak, nonatomic) IBOutlet UILabel *e4StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *b3StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *g3StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *d3StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *a2StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *e2StringLabel;
@property (weak, nonatomic) IBOutlet UILabel *lowLabel;
@property (weak, nonatomic) IBOutlet UILabel *highLabel;
@property (nonatomic, strong) NSNumber* tolerance;
@end


@implementation CTViewController
- (NSArray *)stringLabels {
    if (!_stringLabels) {
        _stringLabels = [[NSArray alloc] initWithObjects:self.highLabel, self.e4StringLabel, self.b3StringLabel, self.g3StringLabel, self.d3StringLabel, self.a2StringLabel, self.e2StringLabel, self.lowLabel, nil];
    }
    return _stringLabels;
}

- (NSNumberFormatter *)formatter {
    if (!_formatter) {
        _formatter = [[NSNumberFormatter alloc] init];
        [_formatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [_formatter setMaximumFractionDigits:0];
    }
    return _formatter;
}

- (BOOL)pitch:(double)pitch IsBetween:(double)low And:(double)high WithTargetPitch:(double)target ForStringLabel:(UILabel *)stringLabel {
    if (pitch < high && pitch > low) {
        stringLabel.textColor = [UIColor orangeColor];
        if (pitch < target + (high - target) * kCTTolerance &&
            pitch > target - (target - low) * kCTTolerance) {
            stringLabel.textColor = [UIColor greenColor];
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)refreshFrequency {
    for (UILabel *label in self.stringLabels) {
        label.textColor = [UIColor blackColor];
    }
    
    double pitch = [self.pitchTracker.currentPitch doubleValue];
    
    if (pitch == 0.0) return;
    
    if (pitch < 68.0) {
        self.lowLabel.textColor = [UIColor greenColor];
        return;
    }
    
    if (pitch > 371.5) {
        self.highLabel.textColor = [UIColor greenColor];
        return;
    }
    
    if ([self pitch:pitch IsBetween:68.0 And:96.0 WithTargetPitch:82.0 ForStringLabel:self.e2StringLabel]) {
        return;
    }

    if ([self pitch:pitch IsBetween:96.0 And:128.5 WithTargetPitch:110.0 ForStringLabel:self.a2StringLabel]) {
        return;
    }

    if ([self pitch:pitch IsBetween:128.5 And:171.5 WithTargetPitch:147.0 ForStringLabel:self.d3StringLabel]) {
        return;
    }

    if ([self pitch:pitch IsBetween:171.5 And:221.5 WithTargetPitch:196.0 ForStringLabel:self.g3StringLabel]) {
        return;
    }

    if ([self pitch:pitch IsBetween:221.5 And:288.5 WithTargetPitch:247.0 ForStringLabel:self.b3StringLabel]) {
        return;
    }

    if ([self pitch:pitch IsBetween:288.5 And:371.5 WithTargetPitch:330.0 ForStringLabel:self.e4StringLabel]) {
        return;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.pitchTracker = [[CTPitchTracker alloc] init];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(refreshFrequency) userInfo:nil repeats:YES];

}

- (void)viewDidDisappear:(BOOL)animated {
    [self.timer invalidate];
    self.pitchTracker = nil;
    [super viewDidDisappear:animated];
}


- (void)viewDidUnload
{
    [self setView:nil];
    [self setE4StringLabel:nil];
    [self setB3StringLabel:nil];
    [self setG3StringLabel:nil];
    [self setD3StringLabel:nil];
    [self setA2StringLabel:nil];
    [self setE2StringLabel:nil];
    [self setLowLabel:nil];
    [self setHighLabel:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
@end
