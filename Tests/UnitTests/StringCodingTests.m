//
//  StringCodingTests.m
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import "StringCodingTests.h"
#import "StringCoding.h"


@implementation StringCodingTests

- (void)testCharValue
{
    //bool
    NSString *input = @"YES";
    char output = YES;
    NSAssert([input charValue] == output, @"charValue failed");
    
    //hex
    input = @"0xAB";
    output = 0xAB;
    NSAssert([input charValue] == output, @"charValue failed");
    
    //decimal
    input = @"50";
    output = 50;
    NSAssert([input charValue] == output, @"charValue failed");
    
    //char
    input = @"7";
    output = '7';
    NSAssert([input charValue] == output, @"charValue failed");
}

- (void)testUnsignedCharValue
{
    //large value
    NSString *input = @"245";
    unsigned char output = 245;
    NSAssert((unsigned char)[input charValue] == output, @"unsignedCharValue failed");
}

- (void)testClassValue
{
    NSString *input = @"NSArray";
    Class output = [NSArray class];
    NSAssert([input classValue] == output, @"classValue failed");
}

- (void)testSelectorValue
{
    //large value
    NSString *input = @"stringWithFormat:";
    SEL output = @selector(stringWithFormat:);
    NSAssert([input selectorValue] == output, @"selectorValue failed");
}

- (void)testNSURLValue
{
    //relative url
    NSString *input = @"foo/bar";
    NSURL *output = [NSURL URLWithString:@"foo/bar" relativeToURL:[[NSBundle mainBundle] resourceURL]];
    NSAssert([[input NSURLValue] isEqual:output], @"NSURLValue failed");

    //remote url
    input = @"http://example.com/foo/bar";
    output = [NSURL URLWithString:@"http://example.com/foo/bar"];
    NSAssert([[input NSURLValue] isEqual:output], @"NSURLValue failed");
}

- (void)testNSColorValue
{
    //const color
    NSString *input = @"darkGray";
    NSColor *output = [NSColor darkGrayColor];
    NSAssert([[input NSColorValue] isEqual:output], @"NSColorValue failed");
    
    //rgba color
    input = @"rgba(100,200,250,0.5)";
    output = [NSColor colorWithDeviceRed:100/255.0 green:200/255.0 blue:250/255.0 alpha:0.5];
    NSAssert([[input NSColorValue] isEqual:output], @"NSColorValue failed");
    
    //hex color
    input = @"#ff00ffff";
    output = [NSColor colorWithDeviceRed:1 green:0 blue:1 alpha:1];
    NSAssert([[input NSColorValue] isEqual:output], @"NSColorValue failed");
}

- (void)testNSFontValue
{
    //bold 15
    NSString *input = @"bold 15";
    NSFont *output = [NSFont boldSystemFontOfSize:15];
    NSAssert([[input NSFontValue] isEqual:output], @"NSFontValue failed");
    
    //times
    input = @"times";
    output = [NSFont fontWithName:@"times" size:[NSFont systemFontSize]];
    NSAssert([[input NSFontValue] isEqual:output], @"NSFontValue failed");
}

- (void)testCGPointValue
{
    NSString *input = @"1 2";
    CGPoint output = CGPointMake(1, 2);
    NSAssert(CGPointEqualToPoint([input CGPointValue], output), @"CGPointValue failed");
}

- (void)testCGSizeValue
{
    NSString *input = @"1 2";
    CGSize output = CGSizeMake(1, 2);
    NSAssert(CGSizeEqualToSize([input CGSizeValue], output), @"CGSizeValue failed");
}

- (void)testCGRectValue
{
    NSString *input = @"1 2 3 4";
    CGRect output = CGRectMake(1, 2, 3, 4);
    NSAssert(CGRectEqualToRect([input CGRectValue], output), @"CGRectValue failed");
}

@end