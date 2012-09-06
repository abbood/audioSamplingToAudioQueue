This is a simple program that reads a media file from an iOS iPod library using AVAssetReader and send it over to an Audio Queue for playback. The reason why I'm sharing this code is because I was frustrated with the lack of information about this whole process. Special mention goes to usre btomw from stack overflow and the book learning core audio.

This example also illustrates a very basic use of multithreading. This is actually my first time ever of using multithreading, easier than I thought! 

usage: The audio file I use for this tutorial is hardcoded. Please check out this project example 'Add Music' from the apple website: http://developer.apple.com/library/ios/#samplecode/AddMusic/Introduction/Intro.html to add the music manually. Perhaps in a later update I'll just incorporate that part.

Apart from that just lanuch the application (ONLY WORKS ON A PHYSICAL IOS DEVICE.. NOT THE SIMULATOR) and the music starts playing immediately.
