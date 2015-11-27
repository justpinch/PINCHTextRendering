//
//  PINCHTextLayout.m
//  PINCHTextRendering
//
//  Created by Pim Coumans on 9/26/13.
//  Copyright (c) 2013 PINCH B.V. All rights reserved.
//

#import <CoreText/CoreText.h>
#import "PINCHTextLayout.h"
#import "PINCHTextRenderer.h"
#import "PINCHTextRendering.h"

static dispatch_queue_t _pinch_framesetterQueue;

static inline dispatch_queue_t pinch_framesetterQueue();
static int queueKey;

static inline dispatch_queue_t pinch_framesetterQueue() {
	if (_pinch_framesetterQueue == NULL)
	{
		_pinch_framesetterQueue = dispatch_queue_create("com.pinch.framesetterqueue", DISPATCH_QUEUE_SERIAL);
		CFStringRef tag = CFSTR("framesetter");
		dispatch_queue_set_specific(_pinch_framesetterQueue, &queueKey, (void *)tag, NULL);
	}
	return _pinch_framesetterQueue;
};

inline UIEdgeInsets PINCHEdgeInsetsInvert(UIEdgeInsets edgeInsets)
{
	return UIEdgeInsetsMake(-edgeInsets.top, -edgeInsets.left, -edgeInsets.bottom, -edgeInsets.right);
}

inline CFDictionaryRef PINCHFrameAttributesCreateWithClippingRect(CGRect clippingRect, CGAffineTransform transform)
{
	CGPathRef clipPath = CGPathCreateWithRect(clippingRect, &transform);
	
	CFDictionaryRef options;
	
	CFStringRef keys[] = {kCTFramePathClippingPathAttributeName};
	CFTypeRef values[] = {clipPath};
	CFDictionaryRef clippingPathDict = CFDictionaryCreate(NULL,
														  (const void **)&keys, (const void **)&values,
														  sizeof(keys) / sizeof(keys[0]),
														  &kCFTypeDictionaryKeyCallBacks,
														  &kCFTypeDictionaryValueCallBacks);
	
	CFTypeRef clippingArrayValues[] = { clippingPathDict };
	CFArrayRef clippingPaths = CFArrayCreate(NULL, (const void **)clippingArrayValues, sizeof(clippingArrayValues) / sizeof(clippingArrayValues[0]), &kCFTypeArrayCallBacks);
	
	CFStringRef optionsKeys[] = {kCTFrameClippingPathsAttributeName};
	CFTypeRef optionsValues[] = {clippingPaths};
	options = CFDictionaryCreate(NULL, (const void **)&optionsKeys, (const void **)&optionsValues,
								 sizeof(optionsKeys) / sizeof(optionsKeys[0]),
								 &kCFTypeDictionaryKeyCallBacks,
								 &kCFTypeDictionaryValueCallBacks);
	
	CFRelease(clippingPathDict);
	CFRelease(clippingPaths);
	CGPathRelease(clipPath);
	
	return options;
}

#if TARGET_OS_IOS
static NSTextCheckingType PINCHTextCheckingTypeFromUIDataDetectorType(UIDataDetectorTypes dataDetectorType);
static NSTextCheckingType PINCHTextCheckingTypeFromUIDataDetectorType(UIDataDetectorTypes dataDetectorType) {
    NSTextCheckingType textCheckingType = 0;
    if (dataDetectorType & UIDataDetectorTypeAddress)
	{
        textCheckingType |= NSTextCheckingTypeAddress;
    }
    
    if (dataDetectorType & UIDataDetectorTypeCalendarEvent)
	{
        textCheckingType |= NSTextCheckingTypeDate;
    }
	
    if (dataDetectorType & UIDataDetectorTypeLink)
	{
        textCheckingType |= NSTextCheckingTypeLink;
    }
    
    if (dataDetectorType & UIDataDetectorTypePhoneNumber)
	{
        textCheckingType |= NSTextCheckingTypePhoneNumber;
    }
    
    return textCheckingType;
}
#endif

NSString *const PINCHTextLayoutFontAttribute = @"font";
NSString *const PINCHTextLayoutTextColorAttribute = @"textColor";
NSString *const PINCHTextLayoutKerningAttribute = @"kerning";
NSString *const PINCHTextLayoutLineHeightAttribute = @"lineHeight";
NSString *const PINCHTextLayoutTextAlignmentAttribute = @"textAlignment";
NSString *const PINCHTextLayoutMaximumNumberOfLinesAttribute = @"maximumNumberOfLines";
NSString *const PINCHTextLayoutTextInsetsAttribute = @"textInsets";
NSString *const PINCHTextLayoutClippingRectInsetsAttribute = @"clippingRectInsets";
NSString *const PINCHTextLayoutMinimumScaleFactorAttribute = @"minimumScaleFactor";
NSString *const PINCHTextLayoutBreaksLastLineAttribute = @"breaksLastLine";
NSString *const PINCHTextLayoutHyphenatedAttribute = @"hyphenated";
NSString *const PINCHTextLayoutLastLineInsetAttribute = @"lastLineInset";
NSString *const PINCHTextLayoutUnderlinedAttribute = @"underlined";
NSString *const PINCHTextLayoutPrefersNonWrappedWords = @"prefersNonWrappedWords";
NSString *const PINCHTextLayoutDataDetectorTypesAttribute = @"dataDetectorTypes";

/// Used in actual attributed string attributes
NSString *const PINCHTextLayoutURLStringAttribute = @"PINCHURLStringAttribute";
NSString *const PINCHTextLayoutTextCheckingResultAttribute = @"PINCHTextCheckingResultAttribute";

@interface PINCHTextRenderer (PINCHTextLayoutAdditions)

#if TARGET_OS_IOS
/// Added as form of secret protocol between textRenderer and textLayout.
/// TextLayouts don't have a delegate but this method is needed for
/// asynchronous purposes.
- (void)notifyTextCheckingResultsFromTextLayout:(PINCHTextLayout *)textLayout withDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes;
#endif

- (BOOL)textLayoutShouldDebugClipping:(PINCHTextLayout *)textLayout;
- (void)textLayoutWillRender:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context;
- (void)textLayoutDidRender:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context;
- (BOOL)textLayoutShouldCheckForURLS:(PINCHTextLayout *)textLayout;

- (void)notifyEncounteredURL:(NSURL *)URL inRange:(NSRange)range withRect:(CGRect)rect;
- (void)notifyEncounteredTextCheckingResult:(NSTextCheckingResult *)result inRange:(NSRange)range withRect:(CGRect)rect;

@end

@interface PINCHTextLayout ()

@property (nonatomic, strong, readwrite) NSAttributedString *attributedString;
@property (atomic, assign, getter = isFramesetterInvalid) BOOL framesetterInvalid;
@property (nonatomic, copy, readwrite) NSArray *lineRects;
@property (nonatomic, assign, readwrite) BOOL stringFitsProposedRect;
@property (nonatomic, assign, readwrite) CGFloat actualScaleFactor;
@property (nonatomic, strong) NSDataDetector *dataDetector;

@end

@implementation PINCHTextLayout
{
	// Instance variable made mutable for easy changing
	NSMutableAttributedString *_attributedString;
	
	// Custom setters and getter require actual instance variables
	CTFramesetterRef _framesetter;
	BOOL _framesetterInvalid;
	
	// Saving calculation rects
	CGRect _boundingRect;
	CGRect _proposedRect;
	CGRect _clippingRect;
	
	// String properties stored locally
	CGFloat _kerning;
	NSTextAlignment _textAlignment;
	UIColor *_textColor;
	
	/// What modified keypaths should invalidate framesetter
	NSArray *_keyPathsToObserve;
}

#pragma mark - Initializing and setters

- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes name:(NSString *)name
{
	if (!string)
	{
		return nil;
	}
	
    self = [super init];
    if (self)
	{
		_name = name;
		
		_font = [attributes objectForKey:PINCHTextLayoutFontAttribute] ?: [UIFont systemFontOfSize:12];
		_textColor = [attributes objectForKey:PINCHTextLayoutTextColorAttribute] ?: [UIColor blackColor];
		
		_kerning = [[attributes objectForKey:PINCHTextLayoutKerningAttribute] doubleValue];
		_textAlignment = [[attributes objectForKey:PINCHTextLayoutTextAlignmentAttribute] integerValue];
		
		_lineHeight = [[attributes objectForKey:PINCHTextLayoutLineHeightAttribute] doubleValue];
		_maximumNumberOfLines = [[attributes objectForKey:PINCHTextLayoutMaximumNumberOfLinesAttribute] integerValue];
		_textInsets = [[attributes objectForKey:PINCHTextLayoutTextInsetsAttribute] UIEdgeInsetsValue];
		_clippingRectInsets = [[attributes objectForKey:PINCHTextLayoutClippingRectInsetsAttribute] UIEdgeInsetsValue];
		_minimumScaleFactor = [[attributes objectForKey:PINCHTextLayoutMinimumScaleFactorAttribute] doubleValue];
		_breaksLastLine = [[attributes objectForKey:PINCHTextLayoutBreaksLastLineAttribute] boolValue];
		_hyphenated = [[attributes objectForKey:PINCHTextLayoutHyphenatedAttribute] boolValue];
		_lastLineInset = [[attributes objectForKey:PINCHTextLayoutLastLineInsetAttribute] doubleValue];
		_underlined = [[attributes objectForKey:PINCHTextLayoutUnderlinedAttribute] boolValue];
		_prefersNonWrappedWords = [[attributes objectForKey:PINCHTextLayoutPrefersNonWrappedWords] boolValue];
#if TARGET_OS_IOS
		_dataDetectorTypes = [[attributes objectForKey:PINCHTextLayoutDataDetectorTypesAttribute] unsignedIntegerValue];
#endif
		
		[self applyDefaultValuesWithString:string];
    }
    return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString name:(NSString *)name
{
	if (!attributedString)
	{
		return nil;
	}
	
	self = [super init];
	if (self)
	{
		_name = name;
		
		if (attributedString.length > 0)
		{
			_font = [attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
			_textColor = [attributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
			_kerning = [[attributedString attribute:NSKernAttributeName atIndex:0 effectiveRange:NULL] doubleValue];
			
			NSParagraphStyle *paragraphStyle = [attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
			_lineHeight = paragraphStyle.maximumLineHeight;
			_textAlignment = paragraphStyle.alignment;
		}
		
		[self applyDefaultValuesWithString:attributedString.string];
	}
	return self;
}

- (void)applyDefaultValuesWithString:(NSString *)string
{
	NSMutableDictionary *stringAttributes = [@{} mutableCopy];
	NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	if (UIEdgeInsetsEqualToEdgeInsets(_clippingRectInsets, UIEdgeInsetsZero))
	{
		_clippingRectInsets = UIEdgeInsetsMake(0, 5, 0, 5);
	}
	
	if (_font)
	{
		_initialFontSize = _font.pointSize;
		_fontSize = _font.pointSize;
		[stringAttributes setObject:_font forKey:NSFontAttributeName];
	}
	
	if (_textColor)
	{
		[stringAttributes setObject:_textColor forKey:NSForegroundColorAttributeName];
		[stringAttributes setObject:@YES forKey:(NSString *)kCTForegroundColorFromContextAttributeName];
	}
	
	if (_kerning != 0)
	{
		[stringAttributes setObject:@(_kerning) forKey:NSKernAttributeName];
	}
	
	if (_lineHeight <= 0)
	{
		_lineHeight = [self initialLineHeightWithFontSize:_font.pointSize];
	}
	
	_initialLineHeight = _lineHeight;
	paragraphStyle.minimumLineHeight = _lineHeight;
	paragraphStyle.maximumLineHeight = _lineHeight;
	
	
	if (_textAlignment > 0)
	{
		paragraphStyle.alignment = _textAlignment;
	}
	
	[stringAttributes setObject:[paragraphStyle copy] forKey:NSParagraphStyleAttributeName];
	
	_attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:[stringAttributes copy]];
	
	[self parseMarkdown];
	
#if TARGET_OS_IOS
	if (_dataDetectorTypes != UIDataDetectorTypeNone)
	{
		[self applyDataDetectorTypes];
	}
#endif
	
	// Begin at reset state
	[self invalidateLayoutCache];
	
	// Add observers to invalidate cache when changed
	_keyPathsToObserve = @[@"maximumNumberOfLines", @"textInsets", @"clippingRectInsets", @"minimumScaleFactor", @"breaksLastLine", @"hyphenated", @"lastLineInset", @"firstLineInset", @"positionsFirstLineHeadIndentRelatively", @"underlined"];
	
	[_keyPathsToObserve enumerateObjectsUsingBlock:^(NSString *keyPath, NSUInteger index, BOOL *stop) {
		[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
	}];
}

- (void)dealloc
{
	// Remove observers
	[_keyPathsToObserve enumerateObjectsUsingBlock:^(NSString *keyPath, NSUInteger index, BOOL *stop) {
		[self removeObserver:self forKeyPath:keyPath];
	}];
	[self removeFramesetter];
}

#pragma mark - Framesetter creation

- (void)removeFramesetter
{
	if (_framesetter != NULL)
	{
		void(^framesetterBlock)(void) = ^(void) {
			if (_framesetter != NULL)
			{
				@synchronized(self)
				{
					CFRelease(_framesetter);
					_framesetter = NULL;
				}
			}
		};
		
		if (dispatch_get_specific(&queueKey))
		{
			framesetterBlock();
		}
		else
		{
			dispatch_sync(pinch_framesetterQueue(), framesetterBlock);
			
		}
	}
}

- (CTFramesetterRef)framesetter
{
	__block CTFramesetterRef framesetter = NULL;
	
	void(^framesetterBlock)(void) = ^(void) {
		
		if (_framesetterInvalid)
		{
			[self removeFramesetter];
			_framesetterInvalid = NO;
		}
		
		if (_framesetter == NULL)
		{
			@synchronized(_attributedString)
			{
				_framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)_attributedString);
			}
		}
		framesetter = _framesetter;
	};
	
	if (dispatch_get_specific(&queueKey))
	{
		framesetterBlock();
	}
	else
	{
		dispatch_sync(pinch_framesetterQueue(), framesetterBlock);
	}
	
	return framesetter;
}

#pragma mark - Invalidating cache

- (void)invalidateLayoutCache
{
	_boundingRect = CGRectZero;
	_proposedRect = CGRectZero;
	self.lineRects = nil;
	self.actualScaleFactor = 1.0f;
	self.actualNumberOfLines = 0;
	self.stringFitsProposedRect = YES;
}

- (void)setFramesetterInvalid
{
	self.framesetterInvalid = YES;
}

#pragma mark - Layout setters

- (void)setActualScaleFactor:(CGFloat)actualScaleFactor
{
	if (actualScaleFactor == _actualScaleFactor)
		return;
	_actualScaleFactor = actualScaleFactor;
	
	[self setFontSize:roundf(_initialFontSize * _actualScaleFactor) scaled:(actualScaleFactor != 1)];
	[self setLineHeight:roundf(_initialLineHeight * _actualScaleFactor) scaled:(actualScaleFactor != 1)];
}

- (void)setLineHeight:(CGFloat)lineHeight
{
	[self setLineHeight:lineHeight scaled:NO];
}

- (void)setLineHeight:(CGFloat)lineHeight scaled:(BOOL)scaled
{
	if (lineHeight == _lineHeight && !scaled)
		return;
	_lineHeight = lineHeight;
	
	if (!scaled)
	{
		_initialLineHeight = lineHeight;
		[self invalidateLayoutCache];
	}
	
	@synchronized(_attributedString)
	{
		NSRange range = NSMakeRange(0, _attributedString.length);
		if (range.length > 0)
		{
			NSMutableParagraphStyle *paragraphStyle = [[_attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL] mutableCopy];
			
			paragraphStyle.minimumLineHeight = lineHeight;
			paragraphStyle.maximumLineHeight = lineHeight;
			
			[_attributedString addAttribute:NSParagraphStyleAttributeName value:[paragraphStyle copy] range:range];
		}
	}
	
	[self setFramesetterInvalid];
}

- (void)setFontSize:(CGFloat)fontSize
{
	[self setFontSize:fontSize scaled:NO];
}

- (void)setFontSize:(CGFloat)fontSize scaled:(BOOL)scaled
{
	if (fontSize == _fontSize && !scaled)
		return;
	_fontSize = fontSize;
	
	if (!scaled)
	{
		_initialFontSize = _fontSize;
		[self invalidateLayoutCache];
	}
	
	@synchronized(_attributedString)
	{
		NSRange range = NSMakeRange(0, _attributedString.length);
		if (range.length > 0)
		{
			UIFont *font = [_attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
			UIFont *newFont = [UIFont fontWithName:font.fontName size:fontSize];
			
			[_attributedString addAttribute:NSFontAttributeName value:newFont range:range];
		}
	}
	
	[self setFramesetterInvalid];
}

- (void)setFont:(UIFont *)font
{
	if (font == _font)
		return;
	_font = font;
	
	_initialFontSize = font.pointSize;
	UIFont *actualFont = [UIFont fontWithName:_font.fontName size:_initialFontSize * self.actualScaleFactor];
	
	@synchronized(_attributedString)
	{
		NSRange range = NSMakeRange(0, _attributedString.length);
		[_attributedString addAttribute:NSFontAttributeName value:actualFont range:range];
	}
	
	[self invalidateLayoutCache];
	[self setFramesetterInvalid];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
	if (textAlignment == _textAlignment)
		return;
	_textAlignment = textAlignment;
	
	@synchronized(_attributedString)
	{
		NSRange range = NSMakeRange(0, _attributedString.length);
		if (range.length > 0)
		{
			NSMutableParagraphStyle *paragraphStyle = [[_attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL] mutableCopy];
			
			paragraphStyle.alignment = textAlignment;
			
			[_attributedString addAttribute:NSParagraphStyleAttributeName value:[paragraphStyle copy] range:range];
		}
	}
}

#pragma mark - KVO setters

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object != self)
		return;
	
	NSValue *oldValue = change[NSKeyValueChangeOldKey];
	NSValue *newValue = change[NSKeyValueChangeNewKey];
	
	if ([newValue isEqual:oldValue])
		return;
	
	[self invalidateLayoutCache];
	[self setFramesetterInvalid];
}

#pragma mark - Data detection

#if TARGET_OS_IOS
- (void)setDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes
{
	if (dataDetectorTypes == _dataDetectorTypes)
		return;
	_dataDetectorTypes = dataDetectorTypes;
	[self applyDataDetectorTypes];
}

- (void)applyDataDetectorTypes
{
	@synchronized(_attributedString)
	{
		NSRange searchRange = NSMakeRange(0, _attributedString.length);
		[_attributedString enumerateAttribute:PINCHTextLayoutTextCheckingResultAttribute inRange:searchRange options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
			if (!value)
				return;
			[_attributedString removeAttribute:PINCHTextLayoutTextCheckingResultAttribute range:range];
			[_attributedString removeAttribute:NSUnderlineStyleAttributeName range:range];
		}];
		
		if (self.dataDetectorTypes != UIDataDetectorTypeNone) {
			NSTextCheckingTypes textCheckingTypes = PINCHTextCheckingTypeFromUIDataDetectorType(self.dataDetectorTypes);
			if (self.dataDetector == nil || self.dataDetector.checkingTypes != textCheckingTypes)
			{
				self.dataDetector = [NSDataDetector dataDetectorWithTypes:textCheckingTypes error:nil];
			}
			
			PINCHTextWeakObject(self, weakSelf);
			void(^checkingBlock)(void) = ^{
				NSArray *results = [weakSelf.dataDetector matchesInString:_attributedString.string options:0 range:NSMakeRange(0, [_attributedString length])];
				dispatch_async(dispatch_get_main_queue(), ^{
					[weakSelf applyTextCheckingResults:results];
				});
			};
			
			if ([[NSThread currentThread] isMainThread])
			{
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), checkingBlock);
			}
			else
			{
				checkingBlock();
			}
		}
	}
}

- (void)applyTextCheckingResults:(NSArray *)results
{
	@synchronized(_attributedString)
	{
		[results enumerateObjectsUsingBlock:^(NSTextCheckingResult *result, NSUInteger index, BOOL *stop) {
			
			if ([_attributedString attribute:PINCHTextLayoutURLStringAttribute atIndex:result.range.location longestEffectiveRange:NULL inRange:result.range])
			{
				/// Don't apply link when a link is already placed
				return;
			}
			
			[_attributedString addAttribute:NSUnderlineStyleAttributeName value:@1 range:result.range];
			[_attributedString addAttribute:PINCHTextLayoutTextCheckingResultAttribute value:result range:result.range];
		}];
		
		[self invalidateLayoutCache];
		[self setFramesetterInvalid];
	}
	
	if ([self.textRenderer respondsToSelector:@selector(notifyTextCheckingResultsFromTextLayout:withDataDetectorTypes:)])
	{
		[self.textRenderer notifyTextCheckingResultsFromTextLayout:self withDataDetectorTypes:self.dataDetectorTypes];
	}
}
#endif

- (void)parseMarkdown
{
	@synchronized(_attributedString)
	{
		NSRange searchRange = NSMakeRange(0, _attributedString.length);
		[_attributedString removeAttribute:NSUnderlineStyleAttributeName range:searchRange];
		[_attributedString removeAttribute:PINCHTextLayoutURLStringAttribute range:searchRange];
		
		NSScanner *scanner = [NSScanner scannerWithString:_attributedString.string];
		NSString *scannedString = nil;
		
		NSMutableArray *foundURLS = [@[] mutableCopy];
		
		while (![scanner isAtEnd])
		{
			[scanner scanUpToString:@"[" intoString:&scannedString];
			
			NSRange URLRange = NSMakeRange([scanner scanLocation], 0);
			NSString *URLNameString = nil;
			NSString *tag = nil;
			
			if ([scanner isAtEnd])
			{
				break;
			}
			[scanner setScanLocation:[scanner scanLocation] + 1];
			
			if([scanner scanUpToString:@"]" intoString:&URLNameString])
			{
				URLRange.length = [scanner scanLocation] - URLRange.location;
				
				if ([scanner isAtEnd])
				{
					break;
				}
				[scanner setScanLocation:NSMaxRange(URLRange)];
				
				NSString *spacing = nil;
				if ([scanner scanUpToString:@"(" intoString:&spacing])
				{
					if ([spacing length] == 1)
					{
						NSString *URLString;
						if ([scanner isAtEnd])
						{
							break;
						}
						[scanner setScanLocation:[scanner scanLocation] + 1];
						if ([scanner scanUpToString:@")" intoString:&URLString])
						{
							tag = [NSString stringWithFormat:@"[%@](%@)", URLNameString, URLString];
							NSURL *URL = [NSURL URLWithString:URLString];
							[foundURLS addObject:@{@"Tag": tag, @"URL": URL, @"URLName": URLNameString}];
						}
					}
				}
			}
		}
		
		[foundURLS enumerateObjectsUsingBlock:^(NSDictionary *foundURL, NSUInteger idx, BOOL *stop) {
			NSString *tag = foundURL[@"Tag"];
			NSURL *URL = foundURL[@"URL"];
			NSString *urlName = foundURL[@"URLName"];
			
			NSRange tagRange = [_attributedString.string rangeOfString:tag];
			[_attributedString replaceCharactersInRange:tagRange withString:urlName];
			
			NSRange linkRange = NSMakeRange(tagRange.location, [urlName length]);
			
			[_attributedString addAttribute:NSUnderlineStyleAttributeName value:@(1) range:linkRange];
			[_attributedString addAttribute:PINCHTextLayoutURLStringAttribute value:URL range:linkRange];
		}];
		
	}
}

#pragma mark - Size calculation

- (CGRect)boundingRectForProposedRect:(CGRect)proposedRect withClippingRect:(CGRect *)clippingRect containerRect:(CGRect)containerRect
{
	UIEdgeInsets textInsets = self.textInsets;
	UIEdgeInsets clippingInsets = self.clippingRectInsets;
	
	if (CGRectGetWidth(proposedRect) == CGFLOAT_MAX)
	{
		proposedRect.size.width = 100000;
	}
	if (CGRectGetHeight(proposedRect) == CGFLOAT_MAX)
	{
		proposedRect.size.height = 100000;
	}
	
	if (!CGRectIsEmpty(*clippingRect) && !UIEdgeInsetsEqualToEdgeInsets(clippingInsets, UIEdgeInsetsZero))
	{
		// Enlarge clippingRect with textInsets before we compare rects
		*clippingRect = UIEdgeInsetsInsetRect(*clippingRect, PINCHEdgeInsetsInvert(clippingInsets));
	}
	
	if (CGRectEqualToRect(proposedRect, _proposedRect) && CGRectEqualToRect(*clippingRect, _clippingRect))
	{
		return _boundingRect;
	}
	
	_proposedRect = proposedRect;
	_clippingRect = *clippingRect;
	
	CGRect fitRect = UIEdgeInsetsInsetRect(proposedRect, textInsets);
	
	CGRect calculatedRect = CGRectZero;
	
	if (fitRect.size.width > 0 && fitRect.size.height > 0)
	{
		CFRange range;
		
		@synchronized(_attributedString)
		{
			range = CFRangeMake(0, (CFIndex)_attributedString.length);
		}
		
		if (range.length == 0)
		{
			return CGRectZero;
		}
		
		__block CFRange fitRange = CFRangeMake(0, 0);
		
		CFDictionaryRef frameAttributes = NULL;
		
		CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, -1.0f);
		transform = CGAffineTransformTranslate(transform, 0, -(CGRectGetHeight(containerRect) - textInsets.top + textInsets.bottom));
		
		if (!CGRectIsEmpty(_clippingRect))
		{
			if (frameAttributes != NULL)
			{
				CFRelease(frameAttributes);
			}
			frameAttributes = PINCHFrameAttributesCreateWithClippingRect(_clippingRect, transform);
		}
		
		CGSize size = CGSizeZero;
		
		BOOL shouldStopIteration = NO;
		self.actualScaleFactor = 1.0;
		
		NSInteger iteration = 0;
		
		NSMutableArray *lineRects = [@[] mutableCopy];
		
		while (shouldStopIteration == NO)
		{
			// Iterate while text doesn't fit proposed rect and minimumScaleFactor is set
			[lineRects removeAllObjects];
			
			iteration++;
			
			CTFramesetterRef framesetter = self.framesetter;
			
			NSParagraphStyle *paragraphStyle;
			UIFont *font;
			NSString *string = nil;
			@synchronized(_attributedString)
			{
				string = _attributedString.string;
				if (_attributedString.length > 0)
				{
					paragraphStyle = [_attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
					font = [_attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
				}
			}
			
			CGFloat descender = roundf(font.descender);
			CGFloat lineHeight = self.lineHeight;
			
			// Whether string is fits in the given rect
			BOOL cappedString = NO;
			
			CFIndex maximumNumberOfLines = (CFIndex)self.maximumNumberOfLines;
			
			CGPathRef framePath = CGPathCreateWithRect(fitRect, &transform);
			CTFrameRef frame = CTFramesetterCreateFrame(framesetter, range, framePath, frameAttributes);
			CGRect frameBounds = CGPathGetPathBoundingBox(framePath);
			
			CFArrayRef lines = CTFrameGetLines(frame);
			CGPoint *origins = malloc(sizeof(CGPoint) * CFArrayGetCount(lines));
			CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
			
			CFIndex numberOfLines = CFArrayGetCount(lines);
			CGFloat maxWidth = 0;
			
			if (numberOfLines > 0)
			{
				CFIndex lastLineIndex = MAX(numberOfLines - 1, 0);
				CGFloat lastLineOffset = origins[lastLineIndex].y;
				
				CGFloat distanceFromTop = CGRectGetMaxY(frameBounds) - (lastLineOffset + descender) - CGRectGetMinY(frameBounds);
				CFIndex actualNumberOfLines = round(distanceFromTop / lineHeight);
				
				CFIndex globalLastLineIndex = lastLineIndex;
				
				if (maximumNumberOfLines > 0 && numberOfLines > maximumNumberOfLines)
				{
					if (actualNumberOfLines > maximumNumberOfLines)
					{
						cappedString = YES;
					}
					
					if (!CGRectIsEmpty(*clippingRect))
					{
						// Two (or more) lines exist when lines are clipped in the middle
						// Search actual last line
						CGFloat actualLastLineOffest = CGRectGetMinY(frameBounds) + (lineHeight * maximumNumberOfLines);
						CGFloat halfLineHeight = round(lineHeight / 2.0f);
						actualLastLineOffest = roundf(actualLastLineOffest / halfLineHeight) * halfLineHeight;
						for (CFIndex lineIndex = actualNumberOfLines - 1; lineIndex >= 0; lineIndex --)
						{
							CGFloat searchLineOriginY = roundf(origins[lineIndex].y / halfLineHeight) * halfLineHeight;
							if (searchLineOriginY == actualLastLineOffest)
							{
								lastLineIndex = lineIndex;
								break;
							}
						}
					}
					else
					{
						lastLineIndex = MIN(numberOfLines, maximumNumberOfLines) - 1;
					}
					
					globalLastLineIndex = MIN(lastLineIndex, maximumNumberOfLines - 1);
				}
				
				
				self.actualNumberOfLines = globalLastLineIndex + 1;
				
				CTLineRef lastLine = NULL;
				
				for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex ++)
				{
					CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
					if (lineIndex == lastLineIndex)
					{
						lastLine = line;
					}
					
					// Check if last character isn't whitespace
					CFRange lineRange = CTLineGetStringRange(line);
					if (self.prefersNonWrappedWords && lineRange.length > 2)
					{
						NSRange lastCharacterRange = NSMakeRange(lineRange.location + lineRange.length - 1, 1);
						if (NSMaxRange(lastCharacterRange) != [string length])
						{
							NSString *lastCharacter = [string substringWithRange:lastCharacterRange];
							NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"\n\r\t- %C", (unichar)0x00AD]];
							NSRange whiteSpaceRange = [lastCharacter rangeOfCharacterFromSet:characterSet];
							if (whiteSpaceRange.location == NSNotFound )
							{
								
								cappedString = YES;
							}
						}
					}
					
					// Calculate the correct linebounds
					CGRect lineRect = CTLineGetBoundsWithOptions(line, 0);
					lineRect.size.height = lineHeight;
					lineRect.size.width -= CTLineGetTrailingWhitespaceWidth(line);
					
					CGPoint lineOrigin = origins[lineIndex];
					lineOrigin.x += CGRectGetMinX(frameBounds);
					lineOrigin.y += CGRectGetMinY(frameBounds) + descender;
					lineOrigin.y = ceilf(CGRectGetMaxY(frameBounds) - lineOrigin.y) + CGRectGetMinY(fitRect) - CGRectGetHeight(lineRect);
					lineRect.origin = lineOrigin;
					
					CGFloat currentWidth;
					// Actual width is measured by max distance from framebounds (clipping full lines moves them)
					if (paragraphStyle.alignment == NSTextAlignmentRight)
					{
						currentWidth = CGRectGetMaxX(frameBounds) - CGRectGetMinX(lineRect);
					}
					else
					{
						currentWidth = CGRectGetMaxX(lineRect) - CGRectGetMinX(frameBounds);
					}
					
					maxWidth = fmaxf(maxWidth, currentWidth);
					
					[lineRects addObject:[NSValue valueWithCGRect:lineRect]];
				}
				
				CGPoint lastLineOrigin = origins[(int)lastLineIndex];
				lastLineOrigin.x += CGRectGetMinX(frameBounds);
				lastLineOrigin.y += CGRectGetMinY(frameBounds) + roundf(font.descender);
				
				CFRange lineRange = CTLineGetStringRange(lastLine);
				fitRange.length = lineRange.location + lineRange.length;
				
				size.width = ceilf(fminf(maxWidth, CGRectGetWidth(fitRect)));
				size.height = ceilf(CGRectGetMaxY(frameBounds) - lastLineOrigin.y);
			}
			
			free(origins);
			CFRelease(frame);
			CGPathRelease(framePath);
			
			if (!cappedString)
			{
				cappedString = (fitRange.length < range.length);
			}
			
			if (!cappedString || self.minimumScaleFactor == 0)
			{
				self.stringFitsProposedRect = !cappedString;
				shouldStopIteration = YES;
			}
			else
			{
				size = [self handleBoundsCalculationIterationWithSize:size cappedString:cappedString shouldStop:&shouldStopIteration];
			}
		}
		
		self.lineRects = lineRects;
		
		if (frameAttributes != NULL)
		{
			CFRelease(frameAttributes);
		}
		
		calculatedRect.size = size;
		calculatedRect.origin = fitRect.origin;
		
		if (size.width < CGRectGetWidth(fitRect))
		{
			if (_textAlignment == NSTextAlignmentRight)
			{
				calculatedRect.origin.x += CGRectGetWidth(fitRect) - size.width;
			}
			else if (_textAlignment == NSTextAlignmentCenter)
			{
				calculatedRect.origin.x = roundf(CGRectGetMidX(fitRect) - (size.width / 2));
			}
		}
	}
	
	if (!CGRectIsEmpty(calculatedRect))
	{
		calculatedRect = UIEdgeInsetsInsetRect(calculatedRect, PINCHEdgeInsetsInvert(self.textInsets));
	}
	
	_boundingRect = calculatedRect;
	return _boundingRect;
}

- (void)drawInContext:(CGContextRef)context withRect:(CGRect)rect
{
	[self drawInContext:context withRect:rect clippingRect:CGRectZero];
}

- (void)drawInContext:(CGContextRef)context withRect:(CGRect)rect clippingRect:(CGRect)clippingRect
{
	if (CGRectIsEmpty(rect))
	{
		return;
	}
	
	CGRect bounds = CGContextGetClipBoundingBox(context);
	
	if (!CGRectIntersectsRect(bounds, rect))
	{
		return;
	}
	
	CGFloat scale = [[UIScreen mainScreen] scale];
	
	@synchronized(self)
	{
		if (self.attributedString.length == 0)
		{
			self.stringFitsProposedRect = YES;
			return;
		}
		
		[self.textRenderer textLayoutWillRender:self inRect:rect withContext:context];
		
		CTFramesetterRef framesetter = self.framesetter;
		CFRange range = CFRangeMake(0, (CFIndex)self.attributedString.length);
		
		BOOL checkForURLs = [self.textRenderer textLayoutShouldCheckForURLS:self];
		BOOL fixUnderlinePosition = false;
		if ([[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)] &&
			[NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 9)
		{
			fixUnderlinePosition = true;
		}
		
		// Save the context state bofore the transforms
		CGContextSaveGState(context);
		{
			CGContextSetTextMatrix(context, CGAffineTransformIdentity);
			UIColor *textColor = [self.attributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL];
			CGContextSetFillColorWithColor(context, textColor.CGColor);
			CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, -1.0f);
			transform = CGAffineTransformTranslate(transform, 0, -(CGRectGetHeight(bounds)));
			CGContextConcatCTM(context, transform);
			
			NSParagraphStyle *paragraphStyle = [self.attributedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
			UIFont *font = [self.attributedString attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
			
			CGFloat descender = roundf(font.descender);
			CGFloat lineHeight = paragraphStyle.maximumLineHeight;
			
			CGPathRef framePath = CGPathCreateWithRect(UIEdgeInsetsInsetRect(rect, self.textInsets), &transform);
			CFDictionaryRef frameAttributes = PINCHFrameAttributesCreateWithClippingRect(clippingRect, transform);
			CTFrameRef frame = CTFramesetterCreateFrame(framesetter, range, framePath, frameAttributes);
			CFRelease(frameAttributes);
			
			// Draw each line individually
			CFArrayRef lines = CTFrameGetLines(frame);
			CGPoint *origins = malloc(sizeof(CGPoint) * CFArrayGetCount(lines));
			CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
			
			CGRect frameBounds = CGPathGetPathBoundingBox(framePath);
			CGRect transformedClippingRect = (CGRectIsEmpty(clippingRect) ? clippingRect : CGRectApplyAffineTransform(clippingRect, transform));
			
			// References for special lines
			CTLineRef truncatedLine = NULL;
			CTLineRef hyphenatedLine = NULL;
			CTLineRef justifiedLine = NULL;
			
			CTFontRef ctFont = NULL;
			
			for (CFIndex lineIndex = 0; lineIndex < CFArrayGetCount(lines); lineIndex ++)
			{
				CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
				CGPoint origin = origins[lineIndex];
				
				CGContextSetTextPosition(context, origin.x + CGRectGetMinX(frameBounds), origin.y + CGRectGetMinY(frameBounds));
				CGRect lineBounds = CTLineGetBoundsWithOptions(line, 0);
				
				CGPoint lineBoundsOrigin = CGContextGetTextPosition(context);
				lineBoundsOrigin.y += descender;
				lineBounds.size.height = lineHeight;
				lineBounds.origin = lineBoundsOrigin;
				
				// Use fullLineBounds to calculate clipping
				CGRect fullLineBounds = lineBounds;
				fullLineBounds.size.width = CGRectGetWidth(frameBounds);
				fullLineBounds.origin.x = CGRectGetMinX(frameBounds);
				
				if ([self.textRenderer textLayoutShouldDebugClipping:self])
				{
					BOOL lineIsBeingClipped = (!CGRectIsEmpty(transformedClippingRect) && CGRectIntersectsRect(fullLineBounds, transformedClippingRect));
					
					if (lineIsBeingClipped)
					{
						CGContextSetStrokeColorWithColor(context, [UIColor yellowColor].CGColor);

						CGContextStrokeRectWithWidth(context, lineBounds, 1);
					}
				}
				
				CFRange cfLineRange = CTLineGetStringRange(line);
				NSRange lineRange = NSMakeRange(cfLineRange.location, cfLineRange.length);
				
				if (checkForURLs)
				{
					[self.attributedString enumerateAttribute:NSUnderlineStyleAttributeName inRange:lineRange options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
						if (value)
						{
							CGRect URLRect = lineBounds;
							URLRect.origin.x += CTLineGetOffsetForStringIndex(line, range.location, NULL);
							URLRect.size.width = CGRectGetMinX(lineBounds) + CTLineGetOffsetForStringIndex(line, NSMaxRange(range), NULL) - CGRectGetMinX(URLRect);
							URLRect.size.height = font.pointSize;
							
							URLRect = CGRectApplyAffineTransform(URLRect, transform);
							
							NSRange rangePointer = range;
							// Get the actual range
							if ((value = [self.attributedString attribute:PINCHTextLayoutURLStringAttribute atIndex:range.location effectiveRange:&rangePointer]))
							{
								[self.textRenderer notifyEncounteredURL:value inRange:rangePointer withRect:URLRect];
							}
							else
							{
								value = [self.attributedString attribute:PINCHTextLayoutTextCheckingResultAttribute atIndex:range.location effectiveRange:&rangePointer];
								[self.textRenderer notifyEncounteredTextCheckingResult:value inRange:[(NSTextCheckingResult *)value range] withRect:URLRect];
							}
							
						}
					}];
				}
				
				static const unichar softHypen = 0x00AD;
				static const CGFloat justificationFactor = 1;
				
				unichar lastChar = 0;
				NSInteger lastCharLocation = lineRange.location + lineRange.length - 1;
				if (lastCharLocation < self.attributedString.length)
				{
					lastChar = [self.attributedString.string characterAtIndex:lineRange.location + lineRange.length-1];
				}
				
				if (self.breaksLastLine && lineIndex == (CFArrayGetCount(lines) - 1) && (cfLineRange.location + cfLineRange.length) < range.length)
				{
					// Show ellipsis when last line range is smaller than total range
					CFRange effectiveRange = (CFRange)range;
					CFAttributedStringRef truncationString = CFAttributedStringCreate(NULL, CFSTR("\u2026"), CFAttributedStringGetAttributes((CFAttributedStringRef)self.attributedString, 0, &effectiveRange));
					CTLineRef truncationToken = CTLineCreateWithAttributedString(truncationString);
					CFRelease(truncationString);
					
					// range to cover everything from the start of lastLine to the end of the string
					CFRange remainingRange = CFRangeMake(cfLineRange.location, range.length - cfLineRange.location);
					
					// substring with that range
					CFAttributedStringRef longString = CFAttributedStringCreateWithSubstring(NULL, (CFAttributedStringRef)self.attributedString, remainingRange);
					// line for that string
					CTLineRef longLine = CTLineCreateWithAttributedString(longString);
					CFRelease(longString);
					
					CGFloat widthAvailable = CGRectGetWidth(frameBounds) - self.lastLineInset;
					
					if (!CGRectIsEmpty(transformedClippingRect))
					{
						if (CGRectIntersectsRect(fullLineBounds, transformedClippingRect))
						{
							CGRect intersection = CGRectIntersection(fullLineBounds, transformedClippingRect);
							widthAvailable -= CGRectGetWidth(intersection);
						}
					}
					
					truncatedLine = CTLineCreateTruncatedLine(longLine, widthAvailable, kCTLineTruncationEnd, truncationToken);
					CFRelease(longLine);
					CFRelease(truncationToken);
					
					// if 'truncated' is NULL, then no truncation was required to fit it
					if (truncatedLine != NULL)
					{
						line = truncatedLine;
					}
					
					// Update the lineRect of the textLayout
					if ([self.lineRects count] > 0)
					{
						NSMutableArray *lineRects = [self.lineRects mutableCopy];
						CGRect lastLineRect = [[lineRects lastObject] CGRectValue];
						lastLineRect.size.width = CGRectGetWidth(CTLineGetBoundsWithOptions(line, 0)) - CTLineGetTrailingWhitespaceWidth(line);
						[lineRects replaceObjectAtIndex:[lineRects count] - 1 withObject:[NSValue valueWithCGRect:lastLineRect]];
						self.lineRects = lineRects;
					}
				}
				else if (self.hyphenated && lastChar == softHypen && lineRange.length > 0)
				{
					NSMutableAttributedString *lineAttrString = [[self.attributedString attributedSubstringFromRange:lineRange] mutableCopy];
					NSRange replaceRange = NSMakeRange(lineRange.length-1, 1);
					[lineAttrString replaceCharactersInRange:replaceRange withString:@"-"];
					
					hyphenatedLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)lineAttrString);
					
					// get the metrics when hyphenated
					CGFloat lineWidth = CTLineGetTypographicBounds(hyphenatedLine, NULL, NULL, NULL);
					
					CGFloat widthAvailable = CGRectGetWidth(frameBounds);
					
					// Calculate whether the current line should be clipped by the clippingRect
					if (!CGRectIsEmpty(transformedClippingRect))
					{
						CGRect fullLineBounds = lineBounds;
						fullLineBounds.size.width = CGRectGetWidth(frameBounds);
						fullLineBounds.origin.x = CGRectGetMinX(frameBounds);
						if (CGRectIntersectsRect(fullLineBounds, transformedClippingRect))
						{
							CGRect clippedLineBounds = lineBounds;
							if (CGRectGetMinX(clippedLineBounds) < CGRectGetMinX(transformedClippingRect))
							{
								clippedLineBounds.size.width = CGRectGetMinX(transformedClippingRect) - CGRectGetMinX(clippedLineBounds);
							}
							else
							{
								clippedLineBounds.size.width = CGRectGetMaxX(frameBounds) - CGRectGetMinX(clippedLineBounds);
							}
							widthAvailable = CGRectGetWidth(clippedLineBounds);
						}
					}
					
					line = hyphenatedLine;
					
					if (lineWidth > widthAvailable || self.textAlignment == NSTextAlignmentJustified)
					{
						justifiedLine = CTLineCreateJustifiedLine(hyphenatedLine, justificationFactor, widthAvailable);
						if (justifiedLine != NULL)
						{
							line = justifiedLine;							
						}
					}
				}
				
				if (self.underlined)
				{
					if (ctFont == NULL)
					{
						ctFont = CTFontCreateWithName((CFStringRef)font.fontName, font.pointSize, &transform);
					}
					CGContextSaveGState(context);
					{
						// Don't draw a shadow with underlined text
						CGContextSetShadowWithColor(context, CGSizeZero, 0.0, NULL);
						
						// Get the starting point of the text
						CGPoint textPoint = CGContextGetTextPosition(context);
						
						CGFloat underlinePosition = CTFontGetUnderlinePosition(ctFont);
						CGFloat underlineThickness = fabs(CTFontGetUnderlineThickness(ctFont));
						CGFloat width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
						CGFloat trailingSpaceWidth = CTLineGetTrailingWhitespaceWidth(line);
						width -= trailingSpaceWidth;
						
						if (fixUnderlinePosition)
						{
							// Since iOS 9, positions of underlines in Core Text are slightly shifted
							// It appears the underlineThickness should be defined in the other direction
							underlinePosition += underlineThickness;
						}
						
						// Create a new context for clipping
						// TODO: create a clipping mask for all lines at once so a new context image doesn't
						// need to be created for every line. This will improve performance drastically
						CGImageRef clippingMask = NULL;
						CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
						CGContextRef clippingContext = CGBitmapContextCreate(NULL, CGRectGetWidth(bounds) * scale, CGRectGetHeight(bounds) * scale, 8, 0, colorspace, kNilOptions);
						CGColorSpaceRelease(colorspace);
						CGContextConcatCTM(clippingContext, CGAffineTransformMakeScale(scale, scale));
						CGContextSetFillColorWithColor(clippingContext, [UIColor whiteColor].CGColor);
						CGContextFillRect(clippingContext, bounds);
						CGContextSetTextPosition(clippingContext, textPoint.x, textPoint.y);
						CGContextSetStrokeColorWithColor(clippingContext, [UIColor blackColor].CGColor);
						CGContextSetLineWidth(clippingContext, floorf(font.pointSize / 8));
						CGContextSetFillColorWithColor(clippingContext, [UIColor blackColor].CGColor);
						CGContextSetTextDrawingMode(clippingContext, kCGTextFillStroke);
					
						CTLineDraw(line, clippingContext);
						
						clippingMask = CGBitmapContextCreateImage(clippingContext);
						CGContextRelease(clippingContext);
						
						// Clip the underline rect
						CGContextClipToMask(context, bounds, clippingMask);
						
						// Draw rect for the underline
						CGRect textRect = CGRectMake(textPoint.x, textPoint.y - underlinePosition - (underlineThickness * 1.5), (CGFloat)width, underlineThickness * 2.0);
						CGContextSetFillColorWithColor(context, textColor.CGColor);
						CGContextFillRect(context, textRect);
						
						CGImageRelease(clippingMask);
					}
					CGContextRestoreGState(context);
				}
				
				// Draw the line
				CTLineDraw(line, context);
				
				if (truncatedLine != NULL)
				{
					CFRelease(truncatedLine);
					truncatedLine = NULL;
				}
				
				if (hyphenatedLine != NULL)
				{
					CFRelease(hyphenatedLine);
					hyphenatedLine = NULL;
				}
				
				if (justifiedLine != NULL)
				{
					CFRelease(justifiedLine);
					justifiedLine = NULL;
				}
			}
			
			free(origins);
			
			if (ctFont != NULL)
			{
				CFRelease(ctFont);
			}
			
			CGPathRelease(framePath);
			if (frame != NULL)
			{
				CFRelease(frame);
			}
			
		}
		CGContextRestoreGState(context);
		[self.textRenderer textLayoutDidRender:self inRect:rect withContext:context];
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, %@", [super description], _attributedString.string];
}

@end

@implementation PINCHTextLayout (PINCHTextSubclassingHooks)

- (CGFloat)initialLineHeightWithFontSize:(CGFloat)fontSize
{
	return roundf(fontSize * 1.2f);
}

- (CGFloat)scaleFactorStepSize
{
	return 0.05f;
}

- (CGSize)handleBoundsCalculationIterationWithSize:(CGSize)size cappedString:(BOOL)cappedString shouldStop:(BOOL *)shouldStopIterating
{
	CGFloat scaleStep = [self scaleFactorStepSize];
	
	// Calculate the middle point of the scaleFactors to create the fallBack when no sizes succeed in fitting
	// Subclasses overwriting this method can define their own logic for the fallback size
	CGFloat halfScaleFactor = ((self.actualScaleFactor - self.minimumScaleFactor) / 2);
	CGFloat multiplier = (1.0f * scaleStep);
	halfScaleFactor = (roundf(halfScaleFactor * multiplier) / multiplier); // round scaleStep by multiplier
	halfScaleFactor += self.minimumScaleFactor;
	
	if (self.actualScaleFactor == halfScaleFactor)
	{
		_sizeIterationFallbackSize = size;
	}
	
	if (self.actualScaleFactor > self.minimumScaleFactor)
	{
		self.actualScaleFactor -= scaleStep;
	}
	else
	{
		// If smallest size doesn't fit, revert to half the scaleFactor
		if (cappedString)
		{
			self.actualScaleFactor = halfScaleFactor;
		}
		self.stringFitsProposedRect = !cappedString;
		*shouldStopIterating = YES; // Stop the loop
		size = _sizeIterationFallbackSize;
	}
	
	return size;
}

@end
