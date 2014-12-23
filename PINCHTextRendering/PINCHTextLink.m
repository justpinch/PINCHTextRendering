//
//  PINCHTextLink.m
//  Pinchlib
//
//  Created by Pim Coumans on 10/30/13.
//  Copyright (c) 2013 PINCH. All rights reserved.
//

#import "PINCHTextLink.h"

static CGFloat linkHorizontalOutset = 2;
static CGFloat linkVerticalOutset = 5;
static CGFloat linkCornerRadius = 4;
static CGFloat touchMinimumHeight = 44;

@interface PINCHTextLink ()

@property (nonatomic, strong) UIBezierPath *bezierPath;
@property (nonatomic, strong) UIBezierPath *touchBezierPath;

@end

@implementation PINCHTextLink

- (instancetype)initWithURL:(NSURL *)URL range:(NSRange)range rect:(CGRect)rect
{
	self = [super init];
	if (self)
	{
		_textLinkType = PINCHTextLinkTypeURL;
		_URL = URL;
		_range = range;
		[self addRect:rect];
	}
	return self;
}

- (instancetype)initWithTextCheckingResult:(NSTextCheckingResult *)result rect:(CGRect)rect
{
	self = [super init];
	if (self)
	{
		_textLinkType = PINCHTextLinkTypeTextCheckingResult;
		_textCheckingResult = result;
		_range = result.range;
		[self addRect:rect];
	}
	return self;
}

- (void)addRect:(CGRect)rect
{
	rect = CGRectInset(rect, -linkHorizontalOutset, -linkVerticalOutset);
	UIBezierPath *newBezierPath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:linkCornerRadius];
	
	UIBezierPath *newTouchBezierPath = nil;
	if (CGRectGetHeight(rect) < touchMinimumHeight)
	{
		CGFloat verticalOutset = roundf(touchMinimumHeight - CGRectGetHeight(rect));
		CGRect touchRect = CGRectInset(rect, 0, -verticalOutset);
		
		newTouchBezierPath = [UIBezierPath bezierPathWithRect:touchRect];
	}
		
	if (self.bezierPath)
	{
		[self.bezierPath appendPath:newBezierPath];
	}
	else
	{
		self.bezierPath = newBezierPath;
	}
	
	if (self.touchBezierPath)
	{
		[self.touchBezierPath appendPath:newTouchBezierPath];
	}
	else
	{
		self.touchBezierPath = newTouchBezierPath;
	}
}

- (BOOL)containsPoint:(CGPoint)point
{
	return [self.bezierPath containsPoint:point];
}

- (BOOL)touchRegionContainsPoint:(CGPoint)point
{
	return [self.touchBezierPath containsPoint:point];
}

- (UIBezierPath *)bezierPath
{
	return _bezierPath;
}

@end
