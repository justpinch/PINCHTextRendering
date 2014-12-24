//
//  PINCHViewController.m
//  PINCHTextRendering
//
//  Created by Pim Coumans on 12/23/2014.
//  Copyright (c) 2014 PINCH B.V. All rights reserved.
//

#import "PINCHViewController.h"
#import "PINCHTextClippingView.h"

@interface PINCHViewController ()

@end

@implementation PINCHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	PINCHTextClippingView *view = [[PINCHTextClippingView alloc] initWithFrame:UIEdgeInsetsInsetRect(self.view.bounds, UIEdgeInsetsMake(20, 0, 0, 0))];
	view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:view];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
