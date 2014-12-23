//
//  PINCHTextLabel.m
//  Pinchlib
//
//  Created by Pim Coumans on 1/8/14.
//  Copyright (c) 2014 PINCH. All rights reserved.
//

#import "PINCHTextLabel.h"
#import "PINCHTextLayout.h"
#import "PINCHTextRenderer.h"

static NSString *const attributedStringLayoutName = @"attributedStringLayout";

@implementation PINCHTextLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
	PINCHTextLayout *textLayout = [[PINCHTextLayout alloc] initWithAttributedString:attributedString name:attributedStringLayoutName];
	[self setTextLayout:textLayout];
}

- (PINCHTextLayout *)textLayout
{
	return [self.renderer.textLayouts firstObject];
}

- (void)setTextLayout:(PINCHTextLayout *)textLayout
{
	self.renderer.textLayouts = @[textLayout];
}

- (CGSize)sizeThatFits:(CGSize)size
{
	PINCHTextLayout *textLayout = [[self.renderer textLayouts] firstObject];
	size.width = fminf(size.width, 10000);
	size.height = fminf(size.height, 10000);
	CGRect boundingRect = CGRectMake(0, 0, size.width, size.height);
	boundingRect = [textLayout boundingRectForProposedRect:boundingRect withClippingRect:&(CGRect){} containerRect:boundingRect];
	return boundingRect.size;
}

- (void)sizeToFit
{
	CGRect frame = self.frame;
	frame.size = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
	self.frame = frame;
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect layoutBounds = [self.textLayout boundingRectForProposedRect:rect withClippingRect:&(CGRect){} containerRect:rect];
	layoutBounds.origin.y = roundf(CGRectGetMidY(rect) - (CGRectGetHeight(layoutBounds) / 2));
	
	[self.renderer renderTextLayoutsInContext:context withRect:layoutBounds];
}

@end
