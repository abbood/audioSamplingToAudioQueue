//
//  AppDelegate.m
//  sampleQueueIphone
//
//  Created by Abdullah Bakhach on 9/4/12.
//  Copyright (c) 2012 Amazon. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    @synchronized(self)
    {

        inuse[fillBufferIndex] = true;		// set in use flag
        buffersUsed++;

        // enqueue buffer
        AudioQueueBufferRef fillBuf = audioQueueBuffers[fillBufferIndex];
        fillBuf->mAudioDataByteSize = bytesFilled;


        /*NSData *bufContent = [NSData dataWithBytes:fillBuf->mAudioData length:fillBuf->mAudioDataByteSize];
        NSLog(@"we are enquing the queue with buffer (length: %lu) %@",fillBuf->mAudioDataByteSize,bufContent);
        NSLog(@"\n\n\n");
        NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");*/

		if (packetsFilled)
		{
    /*        NSLog(@"\n\n\n\n\n\n");
            NSLog(@":::::: we are enqueuing buffer with %zu packtes!",packetsFilled);
            NSLog(@"buffer data is %@",[NSData dataWithBytes:fillBuf->mAudioData length:fillBuf->mAudioDataByteSize]);

            for (int i = 0; i < packetsFilled; i++)
            {
                NSLog(@"\THIS IS THE PACKET WE ARE COPYING TO AUDIO BUFFER----------------\n");
                NSLog(@"this is packetDescriptionArray.mStartOffset: %lld", packetDescs[i].mStartOffset);
                NSLog(@"this is packetDescriptionArray.mVariableFramesInPacket: %lu", packetDescs[i].mVariableFramesInPacket);
                NSLog(@"this is packetDescriptionArray[.mDataByteSize: %lu", packetDescs[i].mDataByteSize);
                NSLog(@"\n----------------\n");
            }
            */
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
