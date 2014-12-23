//
//  PINCHTextLink.h
//  Pinchlib
//
//  Created by Pim Coumans on 10/30/13.
//  Copyright (c) 2013 PINCH. All rights reserved.
//

#import <Foundation/Foundation.h>

/// The type of textLink
typedef NS_ENUM(NSUInteger, PINCHTextLinkType){
	/// The textLink contains a URL
	PINCHTextLinkTypeURL,
	/// The textLink contains an NSTextCheckingResult
	PINCHTextLinkTypeTextCheckingResult
};

/**
 Used to identify links found in textLayout objects while rendering.
 */
@interface PINCHTextLink : NSObject

/**
 Creates a new textLink object with a URL. A textLink object initiated with this method typically comes from a parsed
 markdown link.
 @param URL NSUrl of the link
 @param range The range of where the link is in the attributed string
 @param rect The rect of the link
 */
- (instancetype)initWithURL:(NSURL *)URL range:(NSRange)range rect:(CGRect)rect;

/**
 Creates a new textLink object with a textCheckingResult. A textLink object initiated with this methdod
 typically comes from parsed dataDetectorTypes.
 @param textCheckingResult The NSTextCheckingResult of the link. The range of the link is stored in this object
 @param rect The rect of the link
 */
- (instancetype)initWithTextCheckingResult:(NSTextCheckingResult *)result rect:(CGRect)rect;

/// Type of the link, defining whether the URL or textCheckingResult property should be used
@property (nonatomic, assign, readonly) PINCHTextLinkType textLinkType;

/// The URL of the link, if the textLinkType = PINCHTextLinkTypeURL
@property (nonatomic, strong, readonly) NSURL *URL;

/// Range of the string. In casoe of PINCHTextLinkTypeURL same as textCheckingResult.range
@property (nonatomic, assign, readonly) NSRange range;

/// The NSTextCheckingResult of the link, if the textLinkType = PINCHTextLinkTypeTextCheckingResult
@property (nonatomic, strong, readonly) NSTextCheckingResult *textCheckingResult;

/**
 When the previously found link has the same range the rect can be added instead of creating a new one
 @param rect The CGRect of the link
 */
- (void)addRect:(CGRect)rect;

/**
 When a link is possibly tapped, this method returns YES if the touch is exaclty on the link.
 @param point CGPoint of the touch, relative of the bounds in which the layouts are drawn
 */
- (BOOL)containsPoint:(CGPoint)point;

/**
 When a link is possibly tapped, this method returns YES if the touch is within the touch region of the link.
 @param point CGPoint of the touch, relative of the bounds in which the layouts are drawn
 @note Touch regions might overlap other links. Use linkContainsPoint: to get accurate taps before using this method
 */
- (BOOL)touchRegionContainsPoint:(CGPoint)point;

/// Use this path when drawing highlighted links
- (UIBezierPath *)bezierPath;

@end
