//
//  dyldBypass.m
//  PGHack
//
//  Created by Kyle Nicol on 10/15/19.
//  Copyright © 2019 Hydra. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "dyldBypass.h"

#import "fishhook.h"

@implementation dyldBypass

#pragma mark Globals for Dyld packaged in iOS 12.2+

int swapLC = 0;
int swapCS = 0;
// Substitute in the first 0x4000 bytes of the target binary... or technically any binary honestly
    uint8_t lcData[0x4000] = {0xcf,0xfa,0x00};
// Start Location is gonna be different between apps for this read, Use the provided GetReadLocation file
// as an example to quickly log the first 8-16 bytes of this second read without a swap, and put those here
    uint8_t csData[0x1000] = {0x6D,0x6B};

#pragma mark Globals for Dyld version package in iOS 11.* to 12.1.4
int readCounter = 0;
// For iOS 11 to 12.1.4 the comparison is of the first 0x10000 bytes and a second segment from the
// code sign hash array for comparison.
    // Load up byte array of the first 0x10000 bytes of the target stock/unmodified binary
    uint8_t firstRead[0x10000] = {0xfa,0x3a,0x00 };
    // Find exact start location like for ios 12.2+ and log output, and find the start in a hex editor or such
    uint8_t hashRead[0x10000] = {0xfa, 0xfa, 0x00};

#pragma mark Custom Read Implementations for bypass
    // Store orig imp to pointer
static ssize_t (*orig_read)(int, void *, ssize_t);

    // Read Replacement implementation for ios 12.2+
ssize_t iOS122Support_read(int fildes, void *buf, ssize_t nbytes){
    if (nbytes == 0x4000 && swapLC == 0){
        ssize_t ret = 0x4000;
        void *origLC = &lcData;
        memcpy(buf, origLC, ret);
        swapLC += 1;
        return ret;
    } else if (nbytes == 0x1000 && swapCS == 0) {
        ssize_t ret = 0x1000;
        void *origCS = &csData;
        memcpy(buf, origCS, ret);
        swapCS += 1;
        return ret;
    } else {
        return orig_read(fildes, buf, nbytes);
    }
}

    // Read Replacement implementation for ios 11 - 12.1.4
ssize_t iOS11Support_read(int fildes, void *buf, ssize_t nbytes){
    if (nbytes == 0x10000 && readCounter == 0){
        ssize_t ret = 0x10000;
        void *data = &firstRead;
        memcpy(buf, data, ret);
        readCounter += 1;
        return ret;
    } else if (nbytes == 0x10000 && readCounter == 1){
        ssize_t ret = 0x10000;
        void *data = &hashRead;
        memcpy(buf, data, ret);
        readCounter += 1;
        return ret;
    } else {
        return orig_read(fildes,buf,nbytes);
    }
}
    
+(void)init{
    NSLog(@"[DEBUG]: Init dyldBypass");
    // To avoid any unintended race where Dyld can read before it got through using both checks in a series of elif statements, I opted to just use 2 seperate
    // implementations for the data substitution and use NSProcessInfo for conditional execution of what impl to swap based on iOS version.
    if ( [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){.majorVersion = 12, .minorVersion = 2, .patchVersion = 0}]){
        rebind_symbols((struct rebinding[1]) {
            { "read", (void *)iOS122Support_read, (void **)&orig_read }
        }, 1);
    } else {
        rebind_symbols((struct rebinding[1]) {
            { "read", (void *)iOS11Support_read, (void **)&orig_read }
        }, 1);
    }
    
}

@end
