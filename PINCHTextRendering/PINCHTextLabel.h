//
//  PINCHTextLabel.h
//  Pinchlib
//
//  Created by Pim Coumans on 1/8/14.
//  Copyright (c) 2014 PINCH. All rights reserved.
//

#import "PINCHTextView.h"

/**
 Subclass of PINCHTextView that works like UILabel, in that it
 accepts only one attributed string or textLayout and implements
 the sizeThatFits: and sizeToFit logic for that single layout
 */
@class PINCHTextLayout;
@interface PINCHTextLabel : PINCHTextView

- (instancetype)initWithFrame:(CGRect)frame textLayouts:(NSArray *)textLayouts __attribute__((unavailable("use initWithFrame: and setTextLayout: or setAttributedString: like in UILabel")));

/**
 Sets the drawn textLayout to a new PINCHTextLayout instance
 created with the given attributed string
 @param attributedString String with the attributes to draw
 @note This will clear the currently drawn textLayout(s)
 */
- (void)setAttributedString:(NSAttributedString *)attributedString;

/**
 The textLayout that is or wil be rendered in the view.
 Setting this replaced the textLayouts array of the renderer
 */
@property (nonatomic, strong) PINCHTextLayout *textLayout;

@end
