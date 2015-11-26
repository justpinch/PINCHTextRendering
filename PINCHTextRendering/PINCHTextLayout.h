//
//  PINCHTextLayout.h
//  PINCHTextRendering
//
//  Created by Pim Coumans on 9/26/13.
//  Copyright (c) 2013 PINCH B.V. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

/**
 Inverts given insets to outsets. Used in PINCHTextRendering to switch betweet insetted text and the calculated rect
 */
extern UIEdgeInsets PINCHEdgeInsetsInvert(UIEdgeInsets edgeInsets);

/**
 Returns a created CFDictionaryRef with clipping the given clipping rect and transform applied to it
 */
extern CFDictionaryRef PINCHFrameAttributesCreateWithClippingRect(CGRect clippingRect, CGAffineTransform transform);

/**
 @name Layout attributes
*/
/// Required, expects a UIFont value (Comparable to NSFontAttributeName)
extern NSString *const PINCHTextLayoutFontAttribute;
/// Expects a UIColor value (Comparable to NSForegroundColorAttributeName)
extern NSString *const PINCHTextLayoutTextColorAttribute;
/// Expects an NSNumber float (CGFloat) value
extern NSString *const PINCHTextLayoutKerningAttribute;
/// Expects an NSNumber float (CGFloat) value (Comparable to NSParagraphStyle.maximumLineHeight and minimumLineHeight)
extern NSString *const PINCHTextLayoutLineHeightAttribute;
/// Expects an NSNumber with a value of NSTextAlignment or UITextAlignment. Positioning not greatly with rect calculation
extern NSString *const PINCHTextLayoutTextAlignmentAttribute;
/// Expects an NSNumber integer value.
extern NSString *const PINCHTextLayoutMaximumNumberOfLinesAttribute;
/// Expects an NSValue-wrapped UIEdgeInsets.
extern NSString *const PINCHTextLayoutTextInsetsAttribute;
/// Expects an NSValue-wrapped UIEdgeInsets.
extern NSString *const PINCHTextLayoutClippingRectInsetsAttribute;
/// Expects an NSNumber float (CGFloat) value.
extern NSString *const PINCHTextLayoutMinimumScaleFactorAttribute;
/// Expects an NSNumber BOOL value
extern NSString *const PINCHTextLayoutBreaksLastLineAttribute;
/// Expects an NSNumber BOOL value
extern NSString *const PINCHTextLayoutHyphenatedAttribute;
/// Expects an NSNumber float (CGFloat) value.
extern NSString *const PINCHTextLayoutLastLineInsetAttribute;
/// Expects an NSNumber BOOL value
extern NSString *const PINCHTextLayoutUnderlinedAttribute;
/// Expects an NSNumber BOOL value
extern NSString *const PINCHTextLayoutPrefersNonWrappedWords;
/// Not available yet, expects an NSNumber UIDataDetectorTypes value (unsigned integer)
extern NSString *const PINCHTextLayoutTextCheckingResultAttribute;

/**
 @name AttributedString attributes additions
 */
/// Used as attribute for the attributedString to encapsulate links
extern NSString *const PINCHTextLayoutURLStringAttribute;
/// Used as attribute for the attributedString to encapulate NSTextCheckingResults
extern NSString *const PINCHTextLayoutTextCheckingResultAttribute;

@class PINCHTextRenderer;

/**
 Data object responsible for holding an attributed string, calculating its height and rendering it in a given context.
 Use with the PINCHTextRenderer class to render multiple attributed strings underneath eachother.
 */
@interface PINCHTextLayout : NSObject
{
	/**
	 The bounding size used when every scaleFactor iteration doesn't produce a fitting size.
	 In the default implementation, the size is used when the scale factor is halfway between
	 minimum scalefactor and 1.0f
	 */
	CGSize _sizeIterationFallbackSize;
	/// The fontSize fontsize when scaleFactor = 1
	CGFloat _initialFontSize;
	/// The lineHeight when scaleFactor = 1
	CGFloat _initialLineHeight;
}

/**
 Designated initializer. Creates an PINCHTextLayout instance with a string, attributes and a name
 @param string The string of the textLayout, may not be nil
 @param attributes All attributes as defined in PINCHTextLayout.h, like PINCHTextLayoutFontAttribute and
 PINCHTextLayoutTextColorAttribute
 @param name The name of the textLayout so it can be found via the textRenderer (textLayoutWithName:). Can be nil
 @note The keys and values should be as defined in PINCHTextLayout.h, which are not the same as regular
 NSAttributedString attributes
 */
- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes name:(NSString *)name;

/**
 For compatibility and convenience reasons, this method is added so common attributed strings can be used to render
 in PINCHTextRenderer. While most attributes are supported, some paragraphStyle properties may be overwritten.
 MinimumLineHeight for instance will always be equal to maximumLineHeight.
 Attributes that don't cover the whole string are not supported, all the attributes accessible in the
 properties of each PINCHTextLayout object are retrieved from the first character.
 @note The attributed string used for initializing will not be the same as the one accessible via the
 attributedString property. All properties are used to create a new (mutable) attributed string.
 @param attributedString The attributed string of which the attributes will be used to create the
 PINCHTextLayout
 @param name The name of the textLayout so it can be found via the textRenderer (textLayoutWithName:). May be nil
 */
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString name:(NSString *)name;

/**
 @name Main objects
 */

/// The name of the textLayout.
@property (nonatomic, copy, readonly) NSString *name;

/// Set by the textRenderer when one of the addTextLayout: methods are used
@property (nonatomic, weak) PINCHTextRenderer *textRenderer;

/**
 The attributedString that hold the text and attribute data. If attributes needs to be changed
 use the attribute modifier methods provided by this class. Changing attributes of the string directly 
 may cause unexpected behaviour.
 */
@property (nonatomic, strong, readonly) NSAttributedString *attributedString;

/// The framesetter used to draw the string and calculate its bounds
@property (atomic, assign, readonly) CTFramesetterRef framesetter;

/**
 @name Constraints
 */

/// Sets the allowed number of lines. 0 for no maximum. Default is 0.
@property (nonatomic, assign) NSUInteger maximumNumberOfLines;

/// Set after height calculation, the number of lines that will be drawn
/// Will not exceed maximumNumberOfLines if set
@property (nonatomic, assign) NSUInteger actualNumberOfLines;

/// Extra spacing required around the textLayout
@property (nonatomic, assign) UIEdgeInsets textInsets;

/// Extra spacing around clippingRects (this should actually be outsets with negative values)
@property (nonatomic, assign) UIEdgeInsets clippingRectInsets;

/**
 @name Layout properties and methods
 */

/// The font used to display the attributed string.
/// The pointSize of the font will change with the actualScaleFactor
@property (nonatomic, strong) UIFont *font;

/// The scaleFactor with which the fontSize can be scaled down to fit the size and/or numberOfLines.
@property (nonatomic, assign) CGFloat minimumScaleFactor;

/// The actual scaleFactor applied to make the string fit. Cleared when invalidateLayoutCache is called.
@property (nonatomic, assign, readonly) CGFloat actualScaleFactor;

/// Whether the last line should show an ellipsis
@property (nonatomic, assign) BOOL breaksLastLine;

/// Whether the string is hyphenated, meaning soft hyphens ((unichar)0xad) are a added betwean all syllables
@property (nonatomic, assign, getter = isHyphenated) BOOL hyphenated;

/// Inset for the last line, makes the last line shorter
@property (nonatomic, assign) CGFloat lastLineInset;

/// Wheter a line should be drawn under the text.
/// Clips the underline with a stroke around the text
/// @note This is not the same as NSUnderLineStyle
@property (nonatomic, assign) BOOL underlined;

/// When minimumScaleFactor has been set, the textLayout will try a smaller scaleFactor if a word has been wrapped
/// unless the wrapped segment is smaller than 5 characters to prevent weird misplaced clipping behavior
@property (nonatomic, assign) BOOL prefersNonWrappedWords;

#if TARGET_OS_IOS
/// Which dataTypes to detect and be underlined. These can be made tappable in the view this layout is drawn in
@property (nonatomic, assign) UIDataDetectorTypes dataDetectorTypes;
#endif

/// The NSValue-wrapped CGRect values of all line rects after size calculation.
/// The textRenderer may change these values while rendering to accommodate for extra elements
@property (nonatomic, copy, readonly) NSArray *lineRects;

/// Whether the string fits in the proposed rects
/// Initially set to YES, invalidating does the same. Only NO after calculating and string doens't fit
@property (nonatomic, assign, readonly) BOOL stringFitsProposedRect;

/**
 @name String attribute modifiers
 */

/// The line height of each row (changing updates minimumLineHeight, maximumLineHeight and leading)
@property (nonatomic, assign) CGFloat lineHeight;

/// The font size
@property (nonatomic, assign) CGFloat fontSize;

/// Alignment of the text
@property (nonatomic, assign) NSTextAlignment textAlignment;

/**
 Informs the textLayout object it should discard it's cached layout calculations.
 This method should be called when the position of the textLayout has changed,
 and will be called internally when certain attributes has been changed.
 */
- (void)invalidateLayoutCache;

/**
 Calculates the size the attributedString will occupy within the given rect
 @param rect The rect in which the textLayout's bounding rect should be calculated
 @param clippingRect Reference to the CGRect that may clip the string. This rect may be made bigger to accommodate the clippingRectInsets values
 @param containerRect The containerRect (usually CGContextGetClipBoundingBox()) in which transform needs to be made
 @return The bounding rect in which the textLayout can be rendered
 */
- (CGRect)boundingRectForProposedRect:(CGRect)proposedRect withClippingRect:(CGRect *)clippingRect containerRect:(CGRect)containerRect;

/**
 @name Drawing methods
 */

/**
 Draws the layout into the provided context at the given rect
 @param context The CGContextRef to draw the layout in
 @param rect CGRect value with the constraints of the layout
 */
- (void)drawInContext:(CGContextRef)context withRect:(CGRect)rect;

/**
 Draws the layout into the provided context at the given rect
 @param context The CGContextRef to draw the layout in
 @param rect CGRect value with the constraints of the layout
 */
- (void)drawInContext:(CGContextRef)context withRect:(CGRect)rect clippingRect:(CGRect)clippingRect;

@end

@interface PINCHTextLayout (PINCHTextSubclassingHooks)

/**
 Should return an initial lineHeight when there is none set.
 Defaults to fontSize multiplied by 1.2, rounded
 @param fontSize The initial fontSize
 @return The lineHeight to be used with the given fontSize.
 */
- (CGFloat)initialLineHeightWithFontSize:(CGFloat)fontSize;

/**
 Subclass this method to set the size of the steps in iterating the scale factor.
 @return The size of the set (default is 0.05)
 */
- (CGFloat)scaleFactorStepSize;

/**
 Called from boundingRectForProposedRect:withClippingRect:containerRect: at the end of an iteration.
 Handles the change in scale factor and whether the iteration should stop.
 @param size The size the currenlty calculated string
 @param cappedString Whether the string fits in the proposed rect
 @param shouldStopIterationg When set to YES, the returned size will be used to return in boundingRectForProposedRect:
 @return CGSize of the size to return when done calculating
 */
- (CGSize)handleBoundsCalculationIterationWithSize:(CGSize)size cappedString:(BOOL)cappedString shouldStop:(BOOL *)shouldStopIterating;

@end

@interface PINCHTextLayout (PINCHUnavailableMethods)

- (id)init __attribute__((unavailable("use initWithString:attributes: instead")));
+ (id)new __attribute__((unavailable("use initWithString:attributes: instead")));

@end
