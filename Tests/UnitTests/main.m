//
//  main.m
//  URLUtilsTests
//
//  Created by Nick Lockwood on 12/01/2012.
//  Copyright (c) 2012 Charcoal Design. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StringCodingTests.h"


int main (int argc, const char * argv[])
{
    @autoreleasepool 
	{
        
        //test string functions
        [[[StringCodingTests alloc] init] runTests];
                
    }
    return 0;
}

