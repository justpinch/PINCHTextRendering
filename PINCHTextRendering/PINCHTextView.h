//
//  PINCHTextView.h
//  Pinchlib
//
//  Created by Pim Coumans on 10/18/13.
//  Copyright (c) 2013 PINCH. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 View in which PINCHTextLayout instances can be rendered by the renderer.
 Also capable of handling link selection.
 */
@protocol PINCHTextViewDelegate;
@class PINCHTextRenderer, PINCHTextLayout, PINCHTextLink;
@interface PINCHTextView : UIView

/**
 Initializes a new PINCHTextView instance with the given PINCHTextLayout objects.
 @param frame The CGRect value of the desired frame
 @param textLayouts The PINCHTextLayout instances to set as the layouts for the renderer.
 @return Newly initialized instance of PINCHTextView or nil if failed
 */
- (id)initWithFrame:(CGRect)frame textLayouts:(NSArray<PINCHTextLayout *> *)textLayouts;

@property (nonatomic, weak) id <PINCHTextViewDelegate> delegate;

/**
 The render where textLayout objects can be added and removed.
 @note The textView needs to be the renderer's delegate to behave normally
 */
@property (nonatomic, strong, readonly) PINCHTextRenderer *renderer;

/// The color used to display behind highlighted links
@property (nonatomic, strong) UIColor *linkHighlightBackgroundColor;

/**
 The PINCHTextLink found at the given point
 @param point The point relative to the textView's bounds
 @return PINCHTextLink object when found, otherwise nil
 */
- (PINCHTextLink *)textLinkLinkAtPoint:(CGPoint)point;

/**
 Wether the drawn layouts should show borders and background colors,
 used for debugging.
 */
@property (nonatomic, assign) BOOL debugRendering;

@end

@protocol PINCHTextViewDelegate <NSObject>

@optional

/**
 Notifies the delegate a tap has been recognized on URL. This is a URL created by
 parsing markdown URL's.
 @param textView The textView in which the URL was tapped
 @param URL The tapped URL
 */
- (void)textView:(PINCHTextView *)textView didTapURL:(NSURL *)URL;

/**
 Notifies the delegate a tap has been recognized on a textCheckingResult. This is a
 textCheckingResult created by parsing the textLayout's dataDetectorTypes
 @param textView The textView in which the result was tapped
 @param result The tapped NSTextCheckingResult
 */
- (void)textView:(PINCHTextView *)textView didTapTextCheckingResult:(NSTextCheckingResult *)result;

/**
 Notifies the delegate that one of the layouts has updated its attributes.
 Implement this method to accommodate possible frame changes.
 */
- (void)textViewDidUpdateLayoutAttributes:(PINCHTextView *)textView;

@end
