//
//  PINCHTextRenderer.h
//  PINCHTextRendering
//
//  Created by Pim Coumans on 9/26/13.
//  Copyright (c) 2013 PINCH B.V. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PINCHTextLayout;
@protocol PINCHTextRendererDelegate;

/**
 The textRenderer is responsible for rendering multiple layout objects. This class is typically used
 to render instances of PINCHTextLayout objects. While layout objects can be drawn without this class,
 usage of the textRenderer has the benefits of copious delegate calls.
 */
@interface PINCHTextRenderer : NSObject

/// You can set all textLayouts at once with this property, usefull for reusing.
/// This will not call invalidateLayoutCache on the textLayouts added
@property (nonatomic, copy) NSArray *textLayouts;

/**
 Adds a textLayout below all other textLayouts
 @param textLayout Instance of PINCHTextLayout to add
 */
- (void)addTextLayout:(PINCHTextLayout *)textLayout;

/**
 Insert a textLayout at the given index.
 Calls invalidateLayoutCache on textLayout and subsequent layouts;
 @param textLayout Instance of PINCHTextLayout to add
 @param index The indext to insert the textLayout in
 */
- (void)insertTextLayout:(PINCHTextLayout *)textLayout atIndex:(NSUInteger)index;

/**
 Removes textLayout form the textLayouts.
 Calls invalidateLayoutCache on textLayouts beneath the textLayout
 @param textLayout Instance of PINCHTextLayout to remove
 */
- (void)removeTextLayout:(PINCHTextLayout *)textLayout;

/**
 Returns the textLayout with the given name
 @param name NSString with the name of needed textLayout
 @return PINCHTextLayout instance with the given name
 */
- (PINCHTextLayout *)textLayoutWithName:(NSString *)name;

/// The delegate that should conform fot PINCHTextRendererDelegate
@property (nonatomic, weak) id <PINCHTextRendererDelegate> delegate;

/**
 Set to YES if all textLayout objects should align to the bottom.
 Since the rects of the textLayout objects are moved done after calculating
 the bounds, bottom aligning with clippingRects can have unexpected results.
 @note Might not work correct with clippingRects
 */
@property (nonatomic, assign) BOOL alignsToBottom;

/**
 The rect that should clip the textLayouts.
 @note Rects where text should flow on both sides of the frame are not supported.
 Make sure the minX or maxX are on or over the rect in which the strings are
 drawn. Unexpected behavior can result from non-aligned clippingRects.
 */
@property (nonatomic, assign) CGRect clippingRect;

/**
 Returns the clipping rect if it intersects with the given rect
 */
- (CGRect )clippingRectIntersectingRect:(CGRect)rect;

/**
 TextLayout methods
 */

/**
 Calculates the bounding rect of the current textLayouts
 @param rect Bounding rect of where the layouts will be rendered in
 */
- (CGRect)boundingRectForLayoutsInProposedRect:(CGRect)rect;

/**
 Renders all textLayout objects in the textLayouts array in the right order.
 The textLayout objects are rendered from top to bottom and each textLayout object is
 rendered after its bounding rect has been calculated.
 @param context The context in which to draw the layouts
 @param rect The rect to render the textLayouts in. The clippingRects should be positioned
 relative to this rect.
 */
- (void)renderTextLayoutsInContext:(CGContextRef)context withRect:(CGRect)rect;

/**
 Renders a specific textLayout in the given context placed at the given rect, clipped by the given rect.
 Called by renderTextLayoutsInContext:withRect for each textLayout object in textLayouts
 @param textLayout Instance of PINCHTextLayout to render
 @param context CGContextRef to draw the textLayout in
 @param rect CGRect of where to draw the textLayout
 @param clippingRect The rect to clip the text or CGRectZero if no clipping needed
 @return BOOL whether layout actually got rendered (it might not fit of instersect given rect)
 */
- (BOOL)renderTextLayout:(PINCHTextLayout *)textLayout inContext:(CGContextRef)context withRect:(CGRect)rect clippingRect:(CGRect)clippingRect;

@end

@protocol PINCHTextRendererDelegate <NSObject>

@optional

/**
 Notifies the delegate that a change in the textLayouts has occurred and the layouts should be rerendered.
 @param textRenderer The renderer
 @param textLayouts NSArray of new textLayouts
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didUpdateTextLayouts:(NSArray *)textLayouts;

/**
 Notifies the delegate that a bounding rect has been calculated for a textLayout.
 At this point can be decided to change attributes of remaining textLayout objects.
 @param textRenderer the renderer
 @param rect The CGRect containing the textLayout object
 @param textLayout Instance of PINCHTextLayout which boundingRect has been calculated
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didCalculateBoundingRect:(CGRect)rect forTextLayout:(PINCHTextLayout *)textLayout;

/**
 Asks the delegate if the currently calculated textLayouts should be drawn. At this point certain attributes can be adjusted
 and returning NO will let the renderer calculate the bounds again. This is particularly usefull when the clippingRect needs
 to be adjusted to the sizes of textLayouts.
 @param textRenderer the renderer
 @param textLayouts NSArray of instances of PINCHTextLayout that will be drawn
 @return BOOL whether the textLayout objects should be drawn. Returning NO will recalculate the bounds.
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 @note Repeatedly returning NO will result in the textRendering not drawing the layouts at all, to prevent an endless loop.
 */
- (BOOL)textRenderer:(PINCHTextRenderer *)textRenderer shouldRenderTextLayouts:(NSArray *)textLayouts;

/**
 Notifies the delegate that a PINCHTextLayout instance will render in a rect within a context
 @param textRenderer the renderer
 @param textLayout Instance of PINCHTextLayout that will be renderered
 @param rect The CGRect containing the textLayout object
 @param context CGContextRef where the textLayout object will be rendered in
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer willRenderTextLayout:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context;

/**
 Notifies the delegate that the PINCHTextLayout instances will be rendered
 @param textRenderer the renderer
 @param textLayouts Instances of PINCHTextLayout that will be renderered
 @param rect The CGRect containing the all the rects in which the textLayouts will be rendered
 @param context CGContextRef where the textLayout objects will be rendered in
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 @note The array of textLayouts may contain less objects than all provided textLayouts, while some might not fit or not be intersecting the provided rect
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer willRenderTextLayouts:(NSArray *)textLayouts inBoundingRect:(CGRect)rect withContext:(CGContextRef)context;

/**
 Notifies the delegate that a PINCHTextLayout instance has been rendered in a rect within a context
 @param textRenderer the renderer
 @param textLayout Instance of PINCHTextLayout that got renderered
 @param rect The CGRect containing the textLayout object
 @param context CGContextRef where the textLayout object got rendered
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didRenderTextLayout:(PINCHTextLayout *)textLayout inRect:(CGRect)rect withContext:(CGContextRef)context;

/**
 Notifies the delegate that all necessary PINCHTextLayout instances have been rendered
 @param textLayout All PINCHTextLayout instances that have been rendered
 @param rect Bounding CGRect of all rendered textLayouts combined
 @param context CGContextREd where the textLayout instances got rendered in
 @warning This method will be called from the thread in which the renderTextLayoutsInContext:withRect: is called
 @note The array of textLayouts may contain less objects than all provided textLayouts, while some might not fit or not be intersecting the provided rect
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didRenderTextLayouts:(NSArray *)textLayouts withBoundingRect:(CGRect)rect inContext:(CGContextRef)context;

/**
 While rendering, this informs the delegate that a URL has been found in a perticular line.
 The same URL and range can be send multiple times while the rect may change. This is because links can expand over multiple
 lines.
 @param textRenderer the renderer
 @param URL The encountered URL
 @param range The full range of the url. Might be bigger than the line range
 @param rect The rect containing the url in the current line
 @note Always called asynchronously on the main thread, so UI logic can be done
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didEncounterURL:(NSURL *)URL inRange:(NSRange)range withRect:(CGRect)rect;

/**
 While rendering, this informs the delegate that a textCheckingResult has been found in a perticular line.
 The same result and range can be send multiple times while the rect may change. This is because links can expand over multiple
 lines.
 @param textRenderer the renderer
 @param result The encountered NSTextCheckingResult
 @param range The full range of the result. Might be bigger than the line range
 @param rect The rect containing the result in the current line
 @note Always called asynchronously on the main thread, so UI logic can be done
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer didEncounterTextCheckingResult:(NSTextCheckingResult *)result inRange:(NSRange)range withRect:(CGRect)rect;

/**
 When created on the main thread, a textLayout instance handles the dataDetectors on a different thread.
 This means the parsing can complete after the text has rendered. Implement this delegate to update
 the view and render the textLayout again.
 @param textRenderer the renderer
 @param textLayout The textLayout which had parsed the dataDetectorTypes
 @param dataDetectorTypes Which dataDetectorTypes have been parsed.
 */
- (void)textRenderer:(PINCHTextRenderer *)textRenderer textLayout:(PINCHTextLayout *)textLayout didParseDataDetectorTypes:(UIDataDetectorTypes)dataDetectorTypes;

@end
