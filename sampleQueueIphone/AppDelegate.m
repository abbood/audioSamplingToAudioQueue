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
    // Insert code here to initialize your application
    
    player = [[Player alloc] init];
    
    
    [self setupReader];
    [self setupQueue];
    
    
    // initialize reader in a new thread    
    internalThread =[[NSThread alloc]
                     initWithTarget:self
                     selector:@selector(readVBRPackets)
                     object:nil];
    
    [internalThread start];
            
    
    // start the queue. this function returns immedatly and begins
    // invoking the callback, as needed, asynchronously.
    //CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
    
    // and wait
    printf("Playing...\n");
    do
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    } while (!player.isDone /*|| gIsRunning*/);
    
    // isDone represents the state of the Audio File enqueuing. This does not mean the
    // Audio Queue is actually done playing yet. Since we have 3 half-second buffers in-flight
    // run for continue to run for a short additional time so they can be processed
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false);
    
    // end playback
    player.isDone = true;
    CheckError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
    
cleanup:
    AudioQueueDispose(queue, TRUE);
    AudioFileClose(player.playbackFile);
    
    return YES;
    
}


- (NSDictionary *)getPCMaSBD
{
    // Set the read settings
    NSDictionary *PCMaSBD = [[NSMutableDictionary alloc] init];
    
    [PCMaSBD setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM]
                         forKey:AVFormatIDKey];
    [PCMaSBD setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [PCMaSBD setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
    [PCMaSBD setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    [PCMaSBD setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsNonInterleaved];
    [PCMaSBD setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    
    return PCMaSBD;
}

-(AudioStreamBasicDescription)getPCMaSBDRaw
{
    // get the audio data format from the file
    // we know that it is PCM.. since it's converted    
    AudioStreamBasicDescription dataFormat;
    dataFormat.mSampleRate = 44100.0;
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mFormatFlags = kAudioFormatFlagsCanonical;
    dataFormat.mBytesPerPacket = 4;
    dataFormat.mFramesPerPacket = 1;
    dataFormat.mBytesPerFrame = 4;
    dataFormat.mChannelsPerFrame = 2;
    dataFormat.mBitsPerChannel = 16;  
    
    return dataFormat;
    
}

-(AudioStreamBasicDescription)getTrackNativeSettings:(AVAssetTrack *) track
{

    CMFormatDescriptionRef formDesc = (__bridge CMFormatDescriptionRef)[[track formatDescriptions] objectAtIndex:0];
    const AudioStreamBasicDescription* asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formDesc);
    //because this is a pointer and not a struct we need to move the data into a struct so we can use it
    AudioStreamBasicDescription asbd = {0};
    memcpy(&asbd, asbdPointer, sizeof(asbd));
    //asbd now contains a basic description for the track
    return asbd;
    
}

- (void) setupReader 
{
    
    // this value represents the URL of an iPod music item, which was  hardcoded to simplify this example
    // to create UI to allow the user to manually pick their own music etc.. take a look at this tutorial
    // 'Add Music' @ http://developer.apple.com/library/ios/#samplecode/AddMusic/Introduction/Intro.html
    NSURL *assetURL = [NSURL URLWithString:@"ipod-library://item/item.m4a?id=1053020204400037178"];   
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    // from AVAssetReader Class Reference: 
    // AVAssetReader is not intended for use with real-time sources,
    // and its performance is not guaranteed for real-time operations.
    // DON'T LISTEN TO THEM.. it seems to work fine for me
    NSError * error = nil;
    AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    
    AVAssetTrack* track = [songAsset.tracks objectAtIndex:0];     
    nativeTrackASBD = [self getTrackNativeSettings:track];
    
    readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                              outputSettings:nil];
    
    [reader addOutput:readerOutput];
    [reader startReading];   
    

}

- (void) setupQueue
{
    
    AudioStreamBasicDescription asbd = nativeTrackASBD;    
    
    // create a output (playback) queue
    CheckError(AudioQueueNewOutput(&asbd, // ASBD
                                   MyAQOutputCallback, // Callback
                                   (__bridge void *)self, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &queue), // output: reference to AudioQueue object
               "AudioQueueNewOutput failed");
    
    
    // adjust buffer size to represent about a half second (0.5) of audio based on this format
    CalculateBytesForTime(asbd,  0.5, &bufferByteSize, &player->numPacketsToRead);
    bufferByteSize = 2048;
    NSLog(@"this is buffer byte size %lu", bufferByteSize);
 //   bufferByteSize = 800;
    
    // check if we are dealing with a VBR file. ASBDs for VBR files always have 
    // mBytesPerPacket and mFramesPerPacket as 0 since they can fluctuate at any time.
    // If we are dealing with a VBR file, we allocate memory to hold the packet descriptions
    bool isFormatVBR = (asbd.mBytesPerPacket == 0 || asbd.mFramesPerPacket == 0);
    if (isFormatVBR)
        player.packetDescs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * player.numPacketsToRead);
    else
        player.packetDescs = NULL; // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
    
    // get magic cookie from file and set on queue
    MyCopyEncoderCookieToQueue(player.playbackFile, queue);
    
    // allocate the buffers and prime the queue with some data before starting
    player.isDone = false;
    player.packetPosition = 0;
    int i;
    for (i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        CheckError(AudioQueueAllocateBuffer(queue, bufferByteSize, &audioQueueBuffers[i]), "AudioQueueAllocateBuffer failed");    
        
        // EOF (the entire file's contents fit in the buffers)
        if (player.isDone)
            break;
    }	
    
    AudioSessionInitialize (
                            NULL,                          // 'NULL' to use the default (main) run loop
                            NULL,                          // 'NULL' to use the default run loop mode
                            NULL,  //ASAudioSessionInterruptionListenera reference to your interruption callback
                            NULL                       // data to pass to your interruption listener callback
                            );
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (
                             kAudioSessionProperty_AudioCategory,
                             sizeof (sessionCategory),
                             &sessionCategory
                             );
    AudioSessionSetActive(true);
    
    
}


-(void)readVBRPackets
{
    // initialize a mutex and condition so that we can block on buffers in use.
    pthread_mutex_init(&queueBuffersMutex, NULL);
    pthread_cond_init(&queueBufferReadyCondition, NULL);
    
    state = AS_BUFFERING;  

    while ((sample = [readerOutput copyNextSampleBuffer])) 
    {                                          

        
        Boolean isBufferDataReady = CMSampleBufferDataIsReady(sample);
        
        if (!isBufferDataReady) {
            while (!isBufferDataReady) {
                NSLog(@"buffer is not ready!");
            }
        }
        
        CMBlockBufferRef CMBuffer = CMSampleBufferGetDataBuffer( sample );                                                         
        AudioBufferList audioBufferList;  
        
        CheckError(CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                                                                           sample,
                                                                           NULL,
                                                                           &audioBufferList,
                                                                           sizeof(audioBufferList),
                                                                           NULL,
                                                                           NULL,
                                                                           kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                           &CMBuffer
                                                                           ),
                   "could not read sample data");
        
        const AudioStreamPacketDescription   * inPacketDescriptions;
        size_t								 packetDescriptionsSizeOut;
        size_t inNumberPackets;
        
        CheckError(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample, 
                                                                     &inPacketDescriptions,
                                                                     &packetDescriptionsSizeOut),
                   "could not read sample packet descriptions");
        
        inNumberPackets = packetDescriptionsSizeOut/sizeof(AudioStreamPacketDescription);
        
        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
        

        for (int i = 0; i < inNumberPackets; ++i)
        {
            
            SInt64 dataOffset = inPacketDescriptions[i].mStartOffset;
			UInt32 packetSize   = inPacketDescriptions[i].mDataByteSize;            
            
            size_t packetSpaceRemaining;
            packetSpaceRemaining = bufferByteSize - bytesFilled;
            
            // if the space remaining in the buffer is not enough for the data contained in this packet
            // then just write it
            if (packetSpaceRemaining < packetSize)
            {
                // NSLog(@"oops! packetSpaceRemaining (%zu) is smaller than datasize (%lu) SO WE WILL SHIP PACKET [%d]: (abs number %lu)",
                //     packetSpaceRemaining, dataSize, i, packetNumber);
                
                [self enqueueBuffer];
                
                
                //                [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];                
            }
            
            
            // copy data to the audio queue buffer
            AudioQueueBufferRef fillBuf = audioQueueBuffers[fillBufferIndex];
            memcpy((char*)fillBuf->mAudioData + bytesFilled, 
                   (const char*)(audioBuffer.mData + dataOffset), packetSize);
                                    
            
            
            // fill out packet description
            packetDescs[packetsFilled] = inPacketDescriptions[i];
            packetDescs[packetsFilled].mStartOffset = bytesFilled;
            
            
            bytesFilled += packetSize;
            packetsFilled += 1;
            
            
            // if this is the last packet, then ship it
            size_t packetsDescsRemaining = kAQMaxPacketDescs - packetsFilled;
            if (packetsDescsRemaining == 0) {          
                //NSLog(@"woooah! this is the last packet (%d).. so we will ship it!", i);
                [self enqueueBuffer];
                //  [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];                 
            }                  
        }                                                                                                     
    }
    
}

-(void)readCBRPackets
{
    
    // initialize a mutex and condition so that we can block on buffers in use.
    pthread_mutex_init(&queueBuffersMutex, NULL);
    pthread_cond_init(&queueBufferReadyCondition, NULL);
    
    state = AS_BUFFERING;
    
    while ((sample = [readerOutput copyNextSampleBuffer])) {
    
        AudioBufferList audioBufferList;
        CMBlockBufferRef CMBuffer = CMSampleBufferGetDataBuffer( sample ); 
        
        CheckError(CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                                                                           sample,
                                                                           NULL,
                                                                           &audioBufferList,
                                                                           sizeof(audioBufferList),
                                                                           NULL,
                                                                           NULL,
                                                                           kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                           &CMBuffer
                                                                           ),
                   "could not read samples");
        
        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
        
        UInt32 inNumberBytes = audioBuffer.mDataByteSize;
       /*  NSData *bufContent = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize]; 
       NSLog(@"this is bufcontent %@",bufContent);
        NSLog(@"\n\n\n");            
        NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");
        */
        
        
        size_t incomingDataOffset = 0;
        
        
        while (inNumberBytes) {
            size_t bufSpaceRemaining;
            bufSpaceRemaining = bufferByteSize - bytesFilled;
            
            @synchronized(self)
            {
                bufSpaceRemaining = bufferByteSize - bytesFilled;
                size_t copySize;    
                
                if (bufSpaceRemaining < inNumberBytes)
                {
                    copySize = bufSpaceRemaining;             
                }
                else 
                {
                    copySize = inNumberBytes;
                }
                        
                
                // copy data to the audio queue buffer
                AudioQueueBufferRef fillBuf = audioQueueBuffers[fillBufferIndex];
                memcpy((char*)fillBuf->mAudioData + (bytesFilled), 
                       (const char*)(audioBuffer.mData + (incomingDataOffset)), copySize); 
                
                // keep track of bytes filled
                bytesFilled +=copySize;
                incomingDataOffset +=copySize;
                inNumberBytes -=copySize;      
            }
            
            // if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
            if (bufSpaceRemaining < inNumberBytes + bytesFilled)
            {
                [self enqueueBuffer];
            }
            
        }
    }
    
    

     
}

-(void)enqueueBuffer 
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
            NSLog(@"\n\n\n\n\n\n");
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
            

                        
			err = AudioQueueEnqueueBuffer(queue, fillBuf, packetsFilled, packetDescs);
		}
		else
		{
            NSLog(@":::::: we are enqueuing buffer with fillBufIndex %d, and bytes %zu", fillBufferIndex, bytesFilled);
            
            //NSLog(@"enqueue buffer thread name %@", [NSThread currentThread].name);
			err = AudioQueueEnqueueBuffer(queue, fillBuf, 0, NULL);
		}

        if (err)
        {
            NSLog(@"could not enqueue queue with buffer");
            return;
        }
        
        
        if (state == AS_BUFFERING)
        {
            //
            // Fill all the buffers before starting. This ensures that the
            // AudioFileStream stays a small amount ahead of the AudioQueue to
            // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
            //
            if (buffersUsed == kNumberPlaybackBuffers - 1)
            {
                NSLog(@"STARTING THE QUEUE");
                err = AudioQueueStart(queue, NULL);
                if (err)
                {
                    NSLog(@"couldn't start queue");
                    return;
                }
                state = AS_PLAYING;
            }
        }
        
        // go to next buffer
        if (++fillBufferIndex >= kNumberPlaybackBuffers) fillBufferIndex = 0;
        bytesFilled = 0;		// reset bytes filled
   		packetsFilled = 0;		// reset packets filled

    }
    
    // wait until next buffer is not in use
    pthread_mutex_lock(&queueBuffersMutex); 
    while (inuse[fillBufferIndex])
    {
        pthread_cond_wait(&queueBufferReadyCondition, &queueBuffersMutex);
    }
    pthread_mutex_unlock(&queueBuffersMutex);
    

}


#pragma mark - utility functions -

// generic error handler - if err is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char str[20];
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}

// we only use time here as a guideline
// we're really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it/*
void CalculateBytesForTime(AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets)
{
    
    // we need to calculate how many packets we read at a time, and how big a buffer we need.
    // we base this on the size of the packets in the file and an approximate duration for each buffer.
    //
    // first check to see what the max size of a packet is, if it is bigger than our default
    // allocation size, that needs to become larger
    
    // we don't have access to file packet size, so we just default it to maxBufferSize
    UInt32 maxPacketSize = 0x10000;
    
    static const int maxBufferSize = 0x10000; // limit size to 64K
    static const int minBufferSize = 0x4000; // limit size to 16K
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    // we're going to limit our size to our default
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize)
        *outBufferSize = maxBufferSize;
    else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    *outNumPackets = *outBufferSize / maxPacketSize;
}

// many encoded formats require a 'magic cookie'. if the file has a cookie we get it
// and configure the queue with it
static void MyCopyEncoderCookieToQueue(AudioFileID theFile, AudioQueueRef queue ) {
    UInt32 propertySize;
    OSStatus result = AudioFileGetPropertyInfo (theFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);
    if (result == noErr && propertySize > 0)
    {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8) * propertySize);	
        CheckError(AudioFileGetProperty (theFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), "get cookie from file failed");
        CheckError(AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize), "set cookie on queue failed");
        free(magicCookie);
    }
}


#pragma mark - audio queue -


static void MyAQOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer) 
{
    AppDelegate *appDelegate = (__bridge AppDelegate *) inUserData;
    [appDelegate myCallback:inUserData
               inAudioQueue:inAQ 
        audioQueueBufferRef:inCompleteAQBuffer];
    
}


- (void)myCallback:(void *)userData 
      inAudioQueue:(AudioQueueRef)inAQ
audioQueueBufferRef:(AudioQueueBufferRef)inCompleteAQBuffer
{

    unsigned int bufIndex = -1;
    for (unsigned int i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        if (inCompleteAQBuffer == audioQueueBuffers[i])
        {
            bufIndex = i;
            break;
        }
    }
    
    if (bufIndex == -1)
    {
        NSLog(@"something went wrong at queue callback");
        return;
    }
    
    // signal waiting thread that the buffer is free.
    pthread_mutex_lock(&queueBuffersMutex);
    
    NSLog(@"in call back and we are freeing buf index %d", bufIndex);
    inuse[bufIndex] = false;
    buffersUsed--;    

    pthread_cond_signal(&queueBufferReadyCondition);
    pthread_mutex_unlock(&queueBuffersMutex);
}



@end
