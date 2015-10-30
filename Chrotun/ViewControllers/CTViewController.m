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
    
    self.pitchTracker = [[CTPitchTracker alloc] init];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                  target:self
                                                selector:@selector(refreshFrequency)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.timer invalidate];
    self.pitchTracker = nil;
    [super viewDidDisappear:animated];
}


#pragma mark - UI refresh

- (void)refreshFrequency {
    
    self.pitchLabel.text = [NSString stringWithFormat:@"%@", self.pitchTracker.currentPitch];
}

@end
