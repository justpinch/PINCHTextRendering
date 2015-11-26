//
//  PINCHTextClippingView.m
//  PINCHTextRendering
//
//  Created by Pim Coumans on 24/12/14.
//  Copyright (c) 2014 Pim Coumans. All rights reserved.
//

#import "PINCHTextClippingView.h"
#import <PINCHTextRendering/PINCHTextRendering.h>

static const unichar softHypen = 0x00AD;

@interface PINCHTextClippingView ()

@property (nonatomic, strong) PINCHTextView *textView;

@end

@implementation PINCHTextClippingView

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		// Initialization code
		self.backgroundColor = [UIColor whiteColor];
		
		UIEdgeInsets defaultInsets = UIEdgeInsetsMake(0, 10, 10, 10);
		
		// Creating the tile
		NSString *title = @"PINCHTextRendering does all the heavy lifting";
		NSDictionary *attributes = @{PINCHTextLayoutFontAttribute: [UIFont systemFontOfSize:42],
									 PINCHTextLayoutUnderlinedAttribute: @YES, // The underlined value of PINCHTextLayout is thicker than a usual underline
									 PINCHTextLayoutLineHeightAttribute: @46};
		PINCHTextLayout *titleLayout = [[PINCHTextLayout alloc] initWithString:title attributes:attributes name:@"title"];
		titleLayout.minimumScaleFactor = 0.5;
		titleLayout.prefersNonWrappedWords = YES;
		titleLayout.textInsets = UIEdgeInsetsMake(10, 10, 20, 10); // Most attributes can also be set after initializing via their respective properties
		
		
		// The description
		NSString *description = @"So you only have to worry about what goes where. Instead of creating countless UILabels, stack some PINCHTextLayout instances and you are good to go!";
		
		attributes = @{PINCHTextLayoutFontAttribute: [UIFont boldSystemFontOfSize:12], PINCHTextLayoutLineHeightAttribute: @16, PINCHTextLayoutTextInsetsAttribute: [NSValue valueWithUIEdgeInsets:defaultInsets]};
		
		PINCHTextLayout *descriptionLayout = [[PINCHTextLayout alloc] initWithString:description attributes:attributes name:@"description"];
		descriptionLayout.textInsets = defaultInsets;
		
		// Hyphenated text. Each hyphen is replaced by a soft hyphen manually. Typically you should use some hyphenation logic to add soft hypens
		NSString *hypenatedText = @"Lo-rem ip-sum do-lor sit er e-lit la-met, con-sec-te-taur cil-lium a-dip-i-sic-ing pe-cu, sed do ei-us-mod tem-por in-ci-di-dunt ut la-bo-re et do-lo-re mag-na a-li-qua. Ut e-nim ad mi-nim ve-ni-am, quis no-strud ex-er-ci-ta-tion ul-lam-co la-bo-ris ni-si ut al-iq-uip ex ea com-mo-do con-se-quat. Duis au-te i-ru-re do-lor in re-pre-hen-de-rit in vo-lup-ta-te ve-lit es-se cil-lum do-lo-re eu fu-gi-at nul-la par-i-a-tur. Ex-cep-teur sint oc-cae-cat cu-pi-da-tat non pro-i-dent, sunt in cul-pa qui of-fi-ci-a de-ser-unt mol-lit an-im id est la-bo-rum. Nam li-ber te con-sci-ent to fac-tor tum po-en le-gum od-io-que ci-viu-da.";
		
		hypenatedText = [hypenatedText stringByReplacingOccurrencesOfString:@"-" withString:[NSString stringWithFormat:@"%C", softHypen]];
		
		attributes = @{PINCHTextLayoutFontAttribute : [UIFont systemFontOfSize:9], PINCHTextLayoutHyphenatedAttribute : @YES, PINCHTextLayoutTextInsetsAttribute : [NSValue valueWithUIEdgeInsets:defaultInsets]};
		
		PINCHTextLayout *hypenatedLayout = [[PINCHTextLayout alloc] initWithString:hypenatedText attributes:attributes name:@"hyphenated"];
		hypenatedLayout.textAlignment = NSTextAlignmentJustified;
		
		// Restricted layout
		hypenatedText = @"This text is limited to a maximum of three lines and shows URL parsing with data detectors: www.justpinch.com";
		attributes = @{ PINCHTextLayoutFontAttribute : [UIFont systemFontOfSize:20], PINCHTextLayoutTextInsetsAttribute : [NSValue valueWithUIEdgeInsets:defaultInsets]};
		
		PINCHTextLayout *restrictedLayout = [[PINCHTextLayout alloc] initWithString:hypenatedText attributes:attributes name:@"restricted"];
		restrictedLayout.minimumScaleFactor = 0.2;
		restrictedLayout.maximumNumberOfLines = 3;
#if TARGET_OS_IPHONE
		restrictedLayout.dataDetectorTypes = UIDataDetectorTypeLink;
#endif
		
		self.textView = [[PINCHTextView alloc] initWithFrame:self.bounds textLayouts:@[titleLayout, descriptionLayout, hypenatedLayout, restrictedLayout]];
		self.textView.backgroundColor = [UIColor clearColor];
		self.textView.debugRendering = NO; // Set to YES to show borders and background colors behind the layouts and each line
		[self addSubview:self.textView];
	}
	return self;
}

- (void)drawRect:(CGRect)rect
{
	UIColor *color = [UIColor blackColor];
	if (self.textView.debugRendering)
	{
		color = [[UIColor blueColor] colorWithAlphaComponent:0.5];
	}
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(context, color.CGColor);
	CGContextFillRect(context, self.textView.renderer.clippingRect);
}

- (void)setClippingPoint:(CGPoint)point
{
	CGSize clippingSize = CGSizeMake(100, 100);
	CGRect clipRect = CGRectMake(point.x - (clippingSize.width / 2), point.y - (clippingSize.height / 2), clippingSize.width, clippingSize.height);
	self.textView.renderer.clippingRect = clipRect;
	[self.textView setNeedsDisplay];
	[self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	UITouch *touch = [touches anyObject];
	[self setClippingPoint:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	UITouch *touch = [touches anyObject];
	[self setClippingPoint:[touch locationInView:self]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	self.textView.renderer.clippingRect = CGRectZero;
	[self.textView setNeedsDisplay];
	[self setNeedsDisplay];
}

@end
