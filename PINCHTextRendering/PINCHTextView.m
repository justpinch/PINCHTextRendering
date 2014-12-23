//
//  PINCHTextView.m
//  Pinchlib
//
//  Created by Pim Coumans on 10/18/13.
//  Copyright (c) 2013 PINCH. All rights reserved.
//

#import "PINCHTextRendering.h"
#import "PINCHTextView.h"
#import "PINCHTextRenderer.h"
#import "PINCHTextLayout.h"
#import "PINCHTextLink.h"

typedef void(^PINCHDrawingBlock)(CGRect bounds, CGContextRef context);

@interface PINCHBlockDrawingView : UIView

@property (nonatomic, copy) PINCHDrawingBlock renderBlock;

@end

@implementation PINCHBlockDrawingView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setNeedsDisplay
{
	if (self.renderBlock)
	{
		[super setNeedsDisplay];
	}
	return;
}

- (void)drawRect:(CGRect)rect
{
	if (self.renderBlock)
	{
		CGContextRef context = UIGraphicsGetCurrentContext();
		self.renderBlock(self.bounds, context);
	}
}

@end

@interface PINCHTextView () <PINCHTextRendererDelegate>

@property (nonatomic, strong, readwrite) PINCHTextRenderer *renderer;
@property (nonatomic, strong) NSMutableArray *URLLinks;
@property (nonatomic, strong) NSMutableArray *resultLinks;
@property (nonatomic, strong) PINCHTextLink *highlightedLink;
@property (nonatomic, strong) PINCHTextLink *highlightingLink;
@property (nonatomic, strong) PINCHBlockDrawingView *linkHighlightView;

@end

@implementation PINCHTextView

#pragma mark - Initializers

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
        // Initialization code
		self.renderer = [[PINCHTextRenderer alloc] init];
		self.renderer.delegate = self;
		self.contentMode = UIViewContentModeRedraw;
		
		self.URLLinks = [@[] mutableCopy];
		self.resultLinks = [@[] mutableCopy];
		self.linkHighlightView = [[PINCHBlockDrawingView alloc] initWithFrame:self.bounds];
		self.linkHighlightView.opaque = NO;
		self.linkHighlightView.hidden = YES;
		self.linkHighlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self addSubview:self.linkHighlightView];
		
		PINCHTextWeakObject(self, weakSelf);
		self.linkHighlightView.renderBlock = ^(CGRect bounds, CGContextRef context){
			if (weakSelf.highlightedLink)
			{
				CGContextSetFillColorWithColor(context, weakSelf.linkHighlightBackgroundColor.CGColor);
				CGContextAddPath(context, [weakSelf.highlightedLink bezierPath].CGPath);
				CGContextFillPath(context);
			}
		};
		
		_linkHighlightBackgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame textLayouts:(NSArray *)textLayouts
{
	self = [self initWithFrame:frame];
	if (self)
	{
		self.renderer.textLayouts = textLayouts;
	}
	return self;
}

- (CGSize)sizeThatFits:(CGSize)size
{
	CGRect boundingRect = [self.renderer boundingRectForLayoutsInProposedRect:(CGRect){CGPointZero, size}];
	CGSize boundingSize = boundingRect.size;
	return boundingSize;
}

- (void)sizeToFit
{
	CGRect frame = self.frame;
	frame.size = [self sizeThatFits:CGSizeMake(CGRectGetWidth(frame), CGFLOAT_MAX)];
	frame.size = frame.size;
	self.frame = frame;
}

#pragma mark - Debugging

- (void)setDebugRendering:(BOOL)debugRendering
{
	if (debugRendering == _debugRendering)
		return;
	_debugRendering = debugRendering;
	[self setNeedsLayout];
}

#pragma mark - PINCHTextRenderer delegate methods

- (void)textRenderer:(PINCHTextRenderer *)textRenderer didUpdateTextLayouts:(NSArray *)textLayouts
{
	if ([self.delegate respondsToSelector:@selector(textViewDidUpdateLayoutAttributes:)])
	{
		[self.delegate textViewDidUpdateLayoutAttributes:self];
	}
	[self setNeedsDisplay];
}

- (void)textRenderer:(PINCHTextRenderer *)textRenderer willRenderTextLayout:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context
{
	if (self.debugRendering)
	{
		CGContextSaveGState(context);
		{
			static NSArray *debugColors = nil;
			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				debugColors = @[[UIColor redColor],
								[UIColor greenColor],
								[UIColor blueColor],
								[UIColor cyanColor],
								[UIColor yellowColor],
								[UIColor magentaColor],
								[UIColor orangeColor],
								[UIColor purpleColor],
								[UIColor brownColor]];
			});
			
			NSUInteger layoutIndex = [textRenderer.textLayouts indexOfObject:textLayout] % [debugColors count];
			UIColor *debugColor = debugColors[layoutIndex];
			CGContextSetFillColorWithColor(context, [debugColor colorWithAlphaComponent:0.2].CGColor);
			CGContextFillRect(context, rect);
		}
		CGContextRestoreGState(context);
	}
}

- (BOOL)textRenderer:(PINCHTextRenderer *)textRenderer shouldRenderTextLayouts:(NSArray *)textLayouts
{
	PINCHTextWeakObject(self, weakSelf);
	void(^beginBlock)(void) = ^ {
		[weakSelf.URLLinks removeAllObjects];
		[weakSelf.resultLinks removeAllObjects];
		weakSelf.highlightedLink = nil;
		weakSelf.highlightingLink = nil;
	};
	
	if ([[NSThread currentThread] isMainThread])
	{
		beginBlock();
	}
	else
	{
		dispatch_async(dispatch_get_main_queue(), beginBlock);
	}
	return YES;
}

- (void)textRenderer:(PINCHTextRenderer *)textRenderer didRenderTextLayout:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context
{
	if (self.debugRendering)
	{
		CGFloat scale = [[UIScreen mainScreen] scale];
		CGFloat lineWidth = 1.f / scale;
		CGContextSaveGState(context);
		{
			CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
			[textLayout.lineRects enumerateObjectsUsingBlock:^(NSValue *rectValue, NSUInteger idx, BOOL *stop) {
				CGRect lineRect = [rectValue CGRectValue];
				CGContextStrokeRectWithWidth(context, lineRect, lineWidth);
			}];
		}
		CGContextRestoreGState(context);
	}
}

- (void)textRenderer:(PINCHTextRenderer *)textRenderer didEncounterURL:(NSURL *)URL inRange:(NSRange)range withRect:(CGRect)rect
{
	PINCHTextLink *previousLink = [self.URLLinks lastObject];
	if (previousLink.range.location == range.location && previousLink.range.length == range.length)
	{
		[previousLink addRect:rect];
	}
	else
	{
		PINCHTextLink *textLink = [[PINCHTextLink alloc] initWithURL:URL range:range rect:rect];
		[self.URLLinks addObject:textLink];
	}
}

- (void)textRenderer:(PINCHTextRenderer *)textRenderer didEncounterTextCheckingResult:(NSTextCheckingResult *)result inRange:(NSRange)range withRect:(CGRect)rect
{
	PINCHTextLink *previousLink = [self.resultLinks lastObject];
	if (previousLink.range.location == range.location && previousLink.range.length == range.length)
	{
		[previousLink addRect:rect];
	}
	else
	{
		PINCHTextLink *textLink = [[PINCHTextLink alloc] initWithTextCheckingResult:result rect:rect];
		[self.resultLinks addObject:textLink];
	}
}

- (void)textRenderer:(PINCHTextRenderer *)textRenderer textLayout:(PINCHTextLayout *)textLayout didParseDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes
{
	[self setNeedsDisplay];
}

#pragma mark - Tapping links

- (PINCHTextLink *)textLinkLinkAtPoint:(CGPoint)point
{
	__block PINCHTextLink *foundLink = nil;
	
	void(^specificEnumerator)(id obj, NSUInteger idx, BOOL *stop) = ^(PINCHTextLink *link, NSUInteger index, BOOL *stop)
	{
		if ([link containsPoint:point])
		{
			foundLink = link;
			*stop = YES;
		}
	};
	
	void(^regionEnumerator)(id obj, NSUInteger idx, BOOL *stop) = ^(PINCHTextLink *link, NSUInteger index, BOOL *stop)
	{
		if ([link touchRegionContainsPoint:point])
		{
			foundLink = link;
			*stop = YES;
		}
	};
	
	[self.URLLinks enumerateObjectsUsingBlock:specificEnumerator];
	
	if (!foundLink)
	{
		[self.resultLinks enumerateObjectsUsingBlock:specificEnumerator];
	}
	
	if (!foundLink)
	{
		[self.URLLinks enumerateObjectsUsingBlock:regionEnumerator];
	}
	
	if (!foundLink)
	{
		[self.resultLinks enumerateObjectsUsingBlock:regionEnumerator];
	}
	
	return foundLink;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	
	PINCHTextLink *link = [self textLinkLinkAtPoint:[touch locationInView:self]];
	
	self.highlightedLink = link;
	self.highlightingLink = link;
	
	if (!link)
	{
		[super touchesBegan:touches withEvent:event];
	}
	else
	{
		self.linkHighlightView.hidden = NO;
		[self.linkHighlightView setNeedsDisplay];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.highlightingLink)
	{
		BOOL wasHighlighted = (self.highlightedLink != nil);
		
		UITouch *touch = [touches anyObject];
		CGPoint touchLocation = [touch locationInView:self];
		if ([self.highlightingLink touchRegionContainsPoint:touchLocation])
		{
			self.highlightedLink = self.highlightingLink;
		}
		else
		{
			self.highlightedLink = nil;
		}
		if (wasHighlighted != (self.highlightedLink != nil))
		{
			[self.linkHighlightView setNeedsDisplay];
		}
	}
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.highlightingLink)
	{
		self.highlightedLink = nil;
		self.highlightingLink = nil;
		self.linkHighlightView.hidden = NO;
		[self.linkHighlightView setNeedsDisplay];
	}
	[super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.highlightedLink || self.highlightingLink)
	{
		if (self.highlightedLink)
		{
			if (self.highlightedLink.textLinkType == PINCHTextLinkTypeURL && [self.delegate respondsToSelector:@selector(textView:didTapURL:)])
			{
				[self.delegate textView:self didTapURL:self.highlightedLink.URL];
			}
			else if (self.highlightedLink.textLinkType == PINCHTextLinkTypeTextCheckingResult && [self.delegate respondsToSelector:@selector(textView:didTapTextCheckingResult:)])
			{
				[self.delegate textView:self didTapTextCheckingResult:self.highlightedLink.textCheckingResult];
			}
		}
		self.highlightedLink = nil;
		self.highlightingLink = nil;
		[self.linkHighlightView performSelector:@selector(setNeedsDisplay) withObject:nil afterDelay:0.1];
	}
	[super touchesEnded:touches withEvent:event];
}

#pragma mark - Renderinging

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	[self.renderer renderTextLayoutsInContext:context withRect:self.bounds];
}

@end
