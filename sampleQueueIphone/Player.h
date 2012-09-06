//
//  Player.h
//  AudioConverterCoacoa
//
//  Created by Abdullah Bakhach on 9/2/12.
//  Copyright (c) 2012 Amazon. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>



@interface Player : NSObject
{

    @public
        // AudioQueueRef				queue; // the audio queue object
        // AudioStreamBasicDescription dataFormat; // file's data stream description
        AudioFileID					playbackFile; // reference to your output file
        SInt64						packetPosition; // current packet index in output file
        UInt32						numPacketsToRead; // number of packets to read from file
        AudioStreamPacketDescription *packetDescs; // array of packet descriptions for read buffer
        // AudioQueueBufferRef			buffers[kNumberPlaybackBuffers];
        Boolean						isDone; // playback has completed
}

@property (readwrite) AudioFileID					playbackFile; 
@property (readwrite)  SInt64						packetPosition; 
@property (readwrite) UInt32						numPacketsToRead; 
@property (readwrite) AudioStreamPacketDescription  *packetDescs;
@property (readwrite) Boolean						isDone;

@end