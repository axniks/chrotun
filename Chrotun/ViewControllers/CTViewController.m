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
@property (nonatomic, strong) CTPitchTracker *pitchTracker;
@property (weak, nonatomic) IBOutlet UILabel *pitchLabel;

@end


@implementation CTViewController

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.maximumFractionDigits = 0;

    self.pitchTracker = [[CTPitchTracker alloc] initWithPitchTrackingHandler:^(NSNumber *pitch) {

        self.pitchLabel.text = [NSString stringWithFormat:@"%@ Hz", [formatter stringFromNumber:pitch]];
    }];
}

- (void)viewDidDisappear:(BOOL)animated {

    self.pitchTracker = nil;

    [super viewDidDisappear:animated];
}

@end
