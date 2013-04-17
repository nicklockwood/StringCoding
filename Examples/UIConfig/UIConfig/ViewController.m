//
//  ViewController.m
//  UIConfig
//
//  Created by Nick Lockwood on 15/04/2013.
//  Copyright (c) 2013 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "StringCoding.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UIButton *button;
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    //load config
    NSData *configData = [NSData dataWithContentsOfURL:[@"UIConfig.json" NSURLValue]];
    NSDictionary *config = [NSJSONSerialization JSONObjectWithData:configData options:0 error:NULL];
    
    //apply config
    for (NSString *keyPath in config)
    {
        [self setValue:config[keyPath] forKeyPath:keyPath];
    }
}

- (void)showAlertWithSender:(id)sender event:(UIEvent *)event
{
    [[[UIAlertView alloc] initWithTitle:@"Hello World" message:@"This was connected up by using StringCoding to bind the selector. Cool huh?" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]  show];
}

@end
