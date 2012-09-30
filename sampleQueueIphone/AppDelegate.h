//
//  AppDelegate.h
//  sampleQueueIphone
//
//  Created by Abdullah Bakhach on 9/4/12.
//  Copyright (c) 2012 Amazon. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <pthread.h>

#include "Player.h"

#define kNumberPlaybackBuffers	16

#define kAQMaxPacketDescs 6	// Number of packet descriptions in our array (formerly 512)

typedef enum
{
	AS_INITIALIZED = 0,
	AS_STARTING_FILE_THREAD,
    AS_BUFFERING,
	AS_PLAYING,
    AS_STOPPED
} AudioStreamerState;


@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
    
    CMSampleBufferRef sample;
    AVAssetReaderTrackOutput* readerOutput;
   	UInt32 bufferByteSize;
    size_t bytesFilled;				// how many bytes have been filled
    size_t packetsFilled;			// how many packets have been filled
    
    Player *player;
    AudioQueueBufferRef	audioQueueBuffers[kNumberPlaybackBuffers];
    
    AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
    bool inuse[kNumberPlaybackBuffers];			// flags to indicate that a buffer is still in use
    unsigned int fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
    
    NSThread *internalThread;
    
    pthread_mutex_t queueBuffersMutex;			// a mutex to protect the inuse flags
	pthread_cond_t queueBufferReadyCondition;	// a condition varable for handling the inuse flags
    
    NSInteger buffersUsed;
    
    AudioStreamerState state;
    
   	OSStatus err;
    
   	AudioQueueRef queue;
    AudioStreamBasicDescription nativeTrackASBD;
    
}

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;




void CalculateBytesForTime (AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets);



typedef struct MyPlayer {
	// AudioQueueRef				queue; // the audio queue object
	// AudioStreamBasicDescription dataFormat; // file's data stream description
	AudioFileID					playbackFile; // reference to your output file
	SInt64						packetPosition; // current packet index in output file
	UInt32						numPacketsToRead; // number of packets to read from file
	AudioStreamPacketDescription *packetDescs; // array of packet descriptions for read buffer
	// AudioQueueBufferRef			buffers[kNumberPlaybackBuffers];
	Boolean						isDone; // playback has completed
} MyPlayer;

- (void)myCallback:(void *)userData 
      inAudioQueue:(AudioQueueRef)inAQ
audioQueueBufferRef:(AudioQueueBufferRef)inCompleteAQBuffer;


@end
