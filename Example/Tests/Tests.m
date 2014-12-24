//
//  PINCHTextRenderingTests.m
//  PINCHTextRenderingTests
//
//  Created by Pim Coumans on 12/23/2014.
//  Copyright (c) 2014 PINCH B.V. All rights reserved.
//
#import <PINCHTextRendering/PINCHTextRendering.h>
#import <UIKit/UIKit.h>
#include <Expecta+Snapshots/EXPMatchers+FBSnapshotTest.h>

SpecBegin(InitialSpecs)

describe(@"Creating layout objects", ^{
    
    it(@"can create from attributed string", ^{
		
		NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
		paragraphStyle.minimumLineHeight = 20;
		paragraphStyle.maximumLineHeight = 20;
		
		NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:17],
									 NSForegroundColorAttributeName: [UIColor darkGrayColor],
									 NSParagraphStyleAttributeName: paragraphStyle};
		
		NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"Test string" attributes:attributes];
		PINCHTextLayout *layout = [[PINCHTextLayout alloc] initWithAttributedString:attributedString name:@"attributedStringTestLayout"];
		expect(layout).notTo.beNil;
    });
	
	it(@"should return nil with nil string", ^{
		PINCHTextLayout *layout = [[PINCHTextLayout alloc] initWithString:nil attributes:nil name:nil];
		expect(layout).to.beNil;
	});
});

describe(@"Height calculation", ^{
	
	it(@"calculates height", ^{
		PINCHTextLayout *layout = [[PINCHTextLayout alloc] initWithString:@"Test string" attributes:nil name:nil];
		CGRect bounds = CGRectMake(0, 0, 320, 640);
		CGRect clippingRect = CGRectZero;
		CGRect boundingRect = [layout boundingRectForProposedRect:bounds withClippingRect:&clippingRect containerRect:bounds];
		expect(@(CGRectGetHeight(boundingRect))).to.beGreaterThan(@(0));
	});
	
});

describe(@"Rending of layouts", ^{
	
	it(@"renders correctly", ^{
		PINCHTextLayout *titleLayout = [[PINCHTextLayout alloc] initWithString:@"Title" attributes:@{PINCHTextLayoutFontAttribute : [UIFont boldSystemFontOfSize:20]} name:@"title"];
		PINCHTextLayout *bodyLayout = [[PINCHTextLayout alloc] initWithString:@"Body text" attributes:@{PINCHTextLayoutFontAttribute : [UIFont systemFontOfSize:14]} name:@"body"];
		PINCHTextRenderer *renderer = [[PINCHTextRenderer alloc] init];
		[renderer addTextLayout:titleLayout];
		[renderer addTextLayout:bodyLayout];
		
		CGRect bounds = CGRectMake(0, 0, 320, 640);
		UIImage *resultImage = nil;
		UIGraphicsBeginImageContext(bounds.size);
		{
			CGContextRef context = UIGraphicsGetCurrentContext();
			[renderer renderTextLayoutsInContext:context withRect:bounds];
			resultImage = UIGraphicsGetImageFromCurrentImageContext();
		}
		UIGraphicsEndImageContext();
		
		/// Set a breakPoint here to Quick Look the resultImage
		
		// Doesn't work with UIImage: expect(resultImage).to.recordSnapshotNamed(@"PINCHRenderExample");
	});
	
	it(@"Does hyphenation", ^{
		// Considering the positions, the usage of softhyphens should result in 4 lines. This test will succeed if 4 lines have been rendered
		// To check whether actual hyphens have been rendered, set a breakpoint after the image is created and Quick Look the resultImage variable
		unichar softHyphen = (unichar)0xad;
		NSString *string = @"Thislongwordshouldeventuallybe-brokendownintotwowordsresultingin-actualhyphensbeingshownreplacing-thesofthyphensonecanhope";
		string = [string stringByReplacingOccurrencesOfString:@"-" withString:[NSString stringWithFormat:@"%C", softHyphen]];
		PINCHTextLayout *layout = [[PINCHTextLayout alloc] initWithString:string attributes:@{PINCHTextLayoutFontAttribute : [UIFont systemFontOfSize:15], PINCHTextLayoutHyphenatedAttribute : @YES} name:@"hypenTest"];
		PINCHTextRenderer *renderer = [[PINCHTextRenderer alloc] init];
		[renderer addTextLayout:layout];
		
		CGRect bounds = CGRectMake(0, 0, 320, 640);
		UIImage *resultImage = nil;
		UIGraphicsBeginImageContext(bounds.size);
		{
			CGContextRef context = UIGraphicsGetCurrentContext();
			[renderer renderTextLayoutsInContext:context withRect:bounds];
			resultImage = UIGraphicsGetImageFromCurrentImageContext();
		}
		UIGraphicsEndImageContext();
		
		/// Set a breakPoint here to Quick Look the resultImage
		expect(@(layout.actualNumberOfLines)).to.equal(@4);
	});
	
});

SpecEnd
