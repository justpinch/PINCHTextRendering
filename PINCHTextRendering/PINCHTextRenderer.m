//
//  PINCHTextRenderer.m
//  PINCHTextRendering
//
//  Created by Pim Coumans on 9/26/13.
//  Copyright (c) 2013 PINCH B.V. All rights reserved.
//

#import "PINCHTextRenderer.h"
#import "PINCHTextLayout.h"

static BOOL debugClipping = NO;
static NSUInteger maximumNumberOfRelayoutAttempts = 5;

@interface PINCHTextRenderer ()

@end

@interface PINCHTextLayout ()

/// Making lineRects accessibly by textRenderer
@property (nonatomic, copy, readwrite) NSArray *lineRects;
/// Making stringFitsProposedRect accessibly by textRenderer
@property (nonatomic, assign, readwrite) BOOL stringFitsProposedRect;

@end

@implementation PINCHTextRenderer
{
	NSMutableArray *_textLayouts;
	CGRect _clippingRect;
}

- (id)init
{
    self = [super init];
    if (self) {
		_textLayouts = [@[] mutableCopy];
    }
    return self;
}

#pragma mark - TextLayout setting

- (void)addTextLayout:(PINCHTextLayout *)textLayout
{
	[self addTextLayout:textLayout notifyDelegate:YES];
}

- (void)addTextLayout:(PINCHTextLayout *)textLayout notifyDelegate:(BOOL)notifyDelegate
{
	// Just adding a textLayout should not directly invalidate layoutCaches
	[_textLayouts addObject:textLayout];
	
	textLayout.textRenderer = self;
	
	if (notifyDelegate)
	{
		[self didUpdateTextLayouts:@[textLayout]];
	}
}

- (void)insertTextLayout:(PINCHTextLayout *)textLayout atIndex:(NSUInteger)index
{
	textLayout.textRenderer = self;
	[_textLayouts insertObject:textLayout atIndex:index];
	textLayout.textRenderer = self;
	[self invalidateLayoutCachesFromIndex:index];
	
	[self didUpdateTextLayouts:self.textLayouts];
}

- (void)removeTextLayout:(PINCHTextLayout *)textLayout
{
	textLayout.textRenderer = nil;
	NSUInteger index = [_textLayouts indexOfObject:textLayout];
	[_textLayouts removeObject:textLayout];
	if (index != NSNotFound)
	{
		[self invalidateLayoutCachesFromIndex:index];
		
		[self didUpdateTextLayouts:self.textLayouts];
	}
}

- (void)setTextLayouts:(NSArray *)textLayouts
{
	@synchronized(self.textLayouts)
	{
		[_textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			PINCHTextLayout *textLayout = obj;
			if (textLayout.textRenderer == self)
			{
				// If the textLayout is still reporting to this renderer, the textRenderer property can be nilled
				// It might occur that an other renderer already has been given this perticular layout
				textLayout.textRenderer = nil;
			}
		}];
		[_textLayouts removeAllObjects];
		[textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			PINCHTextLayout *textLayout = obj;
			[self addTextLayout:textLayout notifyDelegate:NO];
		}];
	}
	
	[self didUpdateTextLayouts:self.textLayouts];
}

- (void)didUpdateTextLayouts:(NSArray *)textLayouts
{
	if ([self.delegate respondsToSelector:@selector(textRenderer:didUpdateTextLayouts:)])
	{
		[self.delegate textRenderer:self didUpdateTextLayouts:textLayouts];
	}
}

#pragma mark - Searching layouts

- (PINCHTextLayout *)textLayoutWithName:(NSString *)name
{
	__block PINCHTextLayout *foundTextLayout = nil;
	
	@synchronized(self.textLayouts)
	{
		[self.textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			PINCHTextLayout *textLayout = obj;
			if ([name isEqualToString:textLayout.name])
			{
				foundTextLayout = textLayout;
			}
		}];
	}
	
	return foundTextLayout;
}

#pragma mark - Handling clippingRects



- (void)setClippingRect:(CGRect)clippingRect
{
	@synchronized(self)
	{
		if (CGRectEqualToRect(clippingRect, _clippingRect))
			return;
		_clippingRect = clippingRect;
	}
	[self invalidateLayoutCaches];
}

- (CGRect)clippingRect
{
	CGRect clippingRect = CGRectZero;
	
	@synchronized(self)
	{
		clippingRect = _clippingRect;
	}
	
	return clippingRect;
}

- (CGRect)clippingRectIntersectingRect:(CGRect)rect
{
	CGRect clippingRect = self.clippingRect;
	return (CGRectIntersectsRect(rect, clippingRect) ? clippingRect : CGRectZero);
}

#pragma mark - Invalidating caches

- (void)invalidateLayoutCaches
{
	[self invalidateLayoutCachesFromIndex:0];
	[self didUpdateTextLayouts:self.textLayouts];
}

- (void)invalidateLayoutCachesFromIndex:(NSUInteger)index
{
	[_textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		PINCHTextLayout *textLayout = obj;
		if (idx >= index)
		{
			@synchronized(textLayout)
			{
				[textLayout invalidateLayoutCache];
			}
		}
	}];
}

#pragma mark - Rendering and size calculation

- (CGRect)boundingRectForLayoutsInProposedRect:(CGRect)rect
{
	NSArray *layoutRects = [self layoutRectsForLayoutsInProposedRect:rect withContext:NULL clippingRects:nil];
	__block CGRect boundingRect = CGRectZero;
	
	[layoutRects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSValue *value = obj;
		CGRect rect = [value CGRectValue];
		if (!CGRectIsEmpty(rect))
		{
			if (CGRectIsEmpty(boundingRect))
			{
				boundingRect = rect;
			}
			else
			{
				boundingRect = CGRectUnion(boundingRect, rect);
			}
		}
	}];
	
	return boundingRect;
}

- (NSArray *)layoutRectsForLayoutsInProposedRect:(CGRect)rect withContext:(CGContextRef)context clippingRects:(NSArray **)clippingRects
{
	if (CGRectGetWidth(rect) == CGFLOAT_MAX)
	{
		rect.size.width = 100000;
	}
	
	if (CGRectGetHeight(rect) == CGFLOAT_MAX)
	{
		rect.size.height = 100000;
	}
	
	CGRect bounds = rect;
	if (context != NULL)
	{
		bounds = CGContextGetClipBoundingBox(context);
	}
	
	NSArray *layoutRects = nil;
	
	@synchronized(self.textLayouts)
	{
		NSMutableArray *textRects = [NSMutableArray arrayWithCapacity:[self.textLayouts count]];
		NSMutableArray *textClippingRects = [NSMutableArray arrayWithCapacity:[self.textLayouts count]];
		
		BOOL shouldDrawLayouts = NO;
		NSUInteger numberOfRelayouts = 0;
		
		while (shouldDrawLayouts == NO)
		{
			[textRects removeAllObjects];
			[textClippingRects removeAllObjects];
			
			__block CGRect remainingRect = rect;
			__block CGRect layoutBounds = CGRectZero;
			
			// Calculate the rects, inform the delegates
			[self.textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
				PINCHTextLayout *textLayout = obj;
				
				@synchronized(textLayout)
				{
					CGRect clippingRect = [self clippingRectIntersectingRect:remainingRect];
					CGRect textRect = [textLayout boundingRectForProposedRect:remainingRect withClippingRect:&clippingRect containerRect:bounds];
					
					textRect.size.width = fminf(CGRectGetWidth(textRect), CGRectGetWidth(remainingRect));
					
					[textRects addObject:[NSValue valueWithCGRect:textRect]];
					[textClippingRects addObject:[NSValue valueWithCGRect:clippingRect]];
					
					if ([self.delegate respondsToSelector:@selector(textRenderer:didCalculateBoundingRect:forTextLayout:)])
					{
						[self.delegate textRenderer:self didCalculateBoundingRect:textRect forTextLayout:textLayout];
					}
					
					if (CGRectIsEmpty(textRect))
					{
						return;
					}
					
					if (CGRectIsEmpty(layoutBounds))
					{
						layoutBounds = textRect;
					}
					else
					{
						layoutBounds = CGRectUnion(layoutBounds, textRect);
					}
					
					remainingRect.size.height -= textRect.size.height;
					remainingRect.origin.y = CGRectGetMaxY(textRect);
				}
			}];
			
			if (self.alignsToBottom)
			{
				// Move all rects to the bottom
				NSMutableArray *newRects = [NSMutableArray arrayWithCapacity:[textRects count]];
				[textRects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
					NSValue *value = obj;
					CGRect textLayoutRect = [value CGRectValue];
					textLayoutRect.origin.y += CGRectGetMaxY(rect) - CGRectGetMaxY(layoutBounds);
					NSValue *newValue = [NSValue valueWithCGRect:textLayoutRect];
					[newRects addObject:newValue];
				}];
				textRects = newRects;
			}
			
			if (numberOfRelayouts < maximumNumberOfRelayoutAttempts && [self.delegate respondsToSelector:@selector(textRenderer:shouldRenderTextLayouts:)])
			{
				shouldDrawLayouts = [self.delegate textRenderer:self shouldRenderTextLayouts:self.textLayouts];
			}
			else
			{
				shouldDrawLayouts = YES;
			}
			
			numberOfRelayouts++;
		}
		
		layoutRects = [textRects copy];
		if (clippingRects)
		{
			*clippingRects = [textClippingRects copy];
		}
	}
	
	return layoutRects;
}

- (void)renderTextLayoutsInContext:(CGContextRef)context withRect:(CGRect)rect
{
	@synchronized(self.textLayouts)
	{
		NSArray *clippingRects = nil;
		NSArray *layoutRects = [self layoutRectsForLayoutsInProposedRect:rect withContext:context clippingRects:&clippingRects];
	
		__block CGRect boundingRect = CGRectZero;
		NSMutableArray *drawnTextLayouts = [NSMutableArray array];
		
		if ([self.delegate respondsToSelector:@selector(textRenderer:willRenderTextLayouts:inBoundingRect:withContext:)])
		{
			// Delegate wants to now when all textLayouts will be rendered
			[self.textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
				PINCHTextLayout *textLayout = obj;
				CGRect textRect = [layoutRects[index] CGRectValue];
				CGRect clippingRect = [clippingRects[index] CGRectValue];
				
				if ([self shouldRenderTextLayout:textLayout inContext:context withRect:textRect clippingRect:clippingRect])
				{
					if (CGRectIsEmpty(CGRectZero))
					{
						boundingRect = textRect;
					}
					else
					{
						boundingRect = CGRectUnion(boundingRect, textRect);
					}
					[drawnTextLayouts addObject:textLayout];
				}
			}];
			
			[self.delegate textRenderer:self willRenderTextLayouts:[drawnTextLayouts copy] inBoundingRect:boundingRect withContext:context];
		}
		
		// Draw the strings
		[self.textLayouts enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
			PINCHTextLayout *textLayout = obj;
			CGRect textRect = [layoutRects[index] CGRectValue];
			CGRect clippingRect = [clippingRects[index] CGRectValue];
			if ([self renderTextLayout:textLayout inContext:context withRect:textRect clippingRect:clippingRect])
			{
				if (CGRectIsEmpty(CGRectZero))
				{
					boundingRect = textRect;
				}
				else
				{
					boundingRect = CGRectUnion(boundingRect, textRect);
				}
				
				if (![drawnTextLayouts containsObject:textLayout])
				{
					[drawnTextLayouts addObject:textLayout];
				}
			}
		}];
		
		if ([self.delegate respondsToSelector:@selector(textRenderer:didRenderTextLayouts:withBoundingRect:inContext:)])
		{
			[self.delegate textRenderer:self didRenderTextLayouts:[drawnTextLayouts copy] withBoundingRect:boundingRect inContext:context];
		}
	}
}

- (BOOL)shouldRenderTextLayout:(PINCHTextLayout *)textLayout inContext:(CGContextRef)context withRect:(CGRect)rect clippingRect:(CGRect)clippingRect
{
	CGRect bounds = CGContextGetClipBoundingBox(context);
	if (CGRectIsEmpty(rect) || textLayout == nil || !CGRectIntersectsRect(bounds, rect))
	{
		textLayout.stringFitsProposedRect = NO;
		return NO;
	}
	return YES;
}

- (BOOL)renderTextLayout:(PINCHTextLayout *)textLayout inContext:(CGContextRef)context withRect:(CGRect)rect clippingRect:(CGRect)clippingRect
{
	if (![self shouldRenderTextLayout:textLayout inContext:context withRect:rect clippingRect:clippingRect])
	{
		return NO;
	}
	
	[textLayout drawInContext:context withRect:rect clippingRect:clippingRect];
	return YES;
}

@end

@implementation PINCHTextRenderer (PINCHTextLayoutAdditions)

#if TARGET_OS_IOS
- (void)notifyTextCheckingResultsFromTextLayout:(PINCHTextLayout *)textLayout withDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes
{
	if ([self.delegate respondsToSelector:@selector(textRenderer:textLayout:didParseDataDetectorTypes:)])
	{
		[self.delegate textRenderer:self textLayout:textLayout didParseDataDetectorTypes:dataDetectorTypes];
	}
}
#endif

- (BOOL)textLayoutShouldDebugClipping:(PINCHTextLayout *)textLayout
{
	return debugClipping;
}

- (void)textLayoutWillRender:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context
{
	if ([self.delegate respondsToSelector:@selector(textRenderer:willRenderTextLayout:inRect:withContext:)])
	{
		[self.delegate textRenderer:self willRenderTextLayout:textLayout inRect:rect withContext:context];
	}
}

- (void)textLayoutDidRender:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context
{
	if ([self.delegate respondsToSelector:@selector(textRenderer:didRenderTextLayout:inRect:withContext:)])
	{
		[self.delegate textRenderer:self didRenderTextLayout:textLayout inRect:rect withContext:context];
	}
}

- (BOOL)textLayoutShouldCheckForURLS:(PINCHTextLayout *)textLayout
{
	return ([self.delegate respondsToSelector:@selector(textRenderer:didEncounterURL:inRange:withRect:)] || [self.delegate respondsToSelector:@selector(textRenderer:didEncounterTextCheckingResult:inRange:withRect:)]);
}

- (void)notifyEncounteredURL:(NSURL *)URL inRange:(NSRange)range withRect:(CGRect)rect
{
	void(^notifyBlock)(void) = ^ {
		if ([self.delegate respondsToSelector:@selector(textRenderer:didEncounterURL:inRange:withRect:)])
		{
			[self.delegate textRenderer:self didEncounterURL:URL inRange:range withRect:rect];
		}
	};
	
	if ([[NSThread currentThread] isMainThread])
	{
		notifyBlock();
	}
	else
	{
		dispatch_async(dispatch_get_main_queue(), notifyBlock);
	}
}

- (void)notifyEncounteredTextCheckingResult:(NSTextCheckingResult *)result inRange:(NSRange)range withRect:(CGRect)rect
{
	void(^notifyBlock)(void) = ^ {
		if ([self.delegate respondsToSelector:@selector(textRenderer:didEncounterTextCheckingResult:inRange:withRect:)])
		{
			[self.delegate textRenderer:self didEncounterTextCheckingResult:result inRange:range withRect:rect];
		}
	};
	
	if ([[NSThread currentThread] isMainThread])
	{
		notifyBlock();
	}
	else
	{
		dispatch_async(dispatch_get_main_queue(), notifyBlock);
	}
}

@end
