//
//  StringCodingTests.m
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "StringCoding.h"


@interface StringCodingTests : XCTestCase

@end


@implementation StringCodingTests

- (void)testCharValue
{
    //bool
    NSString *input = @"YES";
    char output = YES;
    XCTAssertEqual([input charValue], output);
    
    //hex
    input = @"0xAB";
    output = (char)0xAB;
    XCTAssertEqual([input charValue], output);
    
    //decimal
    input = @"50";
    output = 50;
    XCTAssertEqual([input charValue], output);
    
    //char
    input = @"7";
    output = '7';
    XCTAssertEqual([input charValue], output);
}

- (void)testUnsignedCharValue
{
    //large value
    NSString *input = @"245";
    unsigned char output = 245;
    XCTAssertEqual((unsigned char)[input charValue], output);
}

- (void)testClassValue
{
    NSString *input = @"NSArray";
    Class output = [NSArray class];
    XCTAssertEqual([input classValue], output);
}

- (void)testSelectorValue
{
    //large value
    NSString *input = @"stringWithFormat:";
    SEL output = NSSelectorFromString(input);
    XCTAssertEqual([input selectorValue], output);
}

- (void)testNSURLValue
{
    //relative url
    NSString *input = @"foo/bar";
    NSURL *output = [NSURL URLWithString:@"foo/bar" relativeToURL:[[NSBundle mainBundle] resourceURL]];
    XCTAssertEqualObjects([input NSURLValue], output);

    //remote url
    input = @"http://example.com/foo/bar";
    output = [NSURL URLWithString:@"http://example.com/foo/bar"];
    XCTAssertEqualObjects([input NSURLValue], output);
}

- (void)testColorValue
{
    //const color
    NSString *input = @"darkGray";
    UIColor *output = [UIColor darkGrayColor];
    XCTAssertEqualObjects([input UIColorValue], output);
    
    //rgba color
    input = @"rgba(100,200,250,0.5)";
    output = [UIColor colorWithRed:100/255.0f green:200/255.0f blue:250/255.0f alpha:0.5f];
    XCTAssertEqualObjects([[input UIColorValue] description], [output description]);
    
    //hex color
    input = @"#ff00ffff";
    output = [UIColor colorWithRed:1 green:0 blue:1 alpha:1];
    XCTAssertEqualObjects([input UIColorValue], output);
}

- (void)testFontValue
{
    //bold 15
    NSString *input = @"bold 15";
    UIFont *output = [UIFont boldSystemFontOfSize:15];
    XCTAssertEqualObjects([input UIFontValue], output);
    
    //times
    input = @"times";
    output = [UIFont fontWithName:@"times" size:17];
    XCTAssertEqualObjects([input UIFontValue], output);
}

- (void)testCGPointValue
{
    NSString *input = @"1 2";
    CGPoint output = CGPointMake(1, 2);
    XCTAssertTrue(CGPointEqualToPoint([input CGPointValue], output));
}

- (void)testCGSizeValue
{
    NSString *input = @"1 2";
    CGSize output = CGSizeMake(1, 2);
    XCTAssertTrue(CGSizeEqualToSize([input CGSizeValue], output));
}

- (void)testCGRectValue
{
    NSString *input = @"1 2 3 4";
    CGRect output = CGRectMake(1, 2, 3, 4);
    XCTAssertTrue(CGRectEqualToRect([input CGRectValue], output));
}

@end
