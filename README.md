# iOSDyldIntegrityBypass
This Repo is a proof of concept for a simple method for bypass applications that use dyld integrity checks that will exit due to Dyld's CrashIfInvalidCodeSignature() method. 

If it's helpful for you, throw a Star and Follow me for future open source tweak release around some popular games.

Expected Software/Tools:
- Xcode
- Facebooks Fishhook library (Available on github)

Alternative Tools:
- Theos
- Theos-jailed (Theos extension that includes templates for handling dynamic library generation from your tweak and load command injection)

## General Overview
Applications compiled with iOS dynamic linker (Dyld) file integrity protection will crash on launch when working with a cracked and/or resigned binary. Since we require a decrypted binary to inject any tweaks, preparation on how to bypass these basic FIP protocols is critical for both Jailbreak and Jailed tweak developers.

### Identifying an application is crashing due to Dyld?
You have a cracked/decrypted binary, you injected your tweak, but the application crashes on launch. Check out your devices crash log. If the crash log show's the main thread never makes it past `_dyld_start`, guess what!? It's 99% likely that this Dyld option is killing you!?
  
### What is Dyld doing?
Thankfully the source for dyld, like much of Apple's work, is open and available via apple directly at either, https://github.com/opensource-apple or https://opensource.apple.com. 

This is not a crash course in Dyld operations, but to provide enough context to allow you to get up and running past this protection.

I highly suggest educating yourself on the general MachO Executable structure, and tracing through Dyld source if you seek to understand what is going on here under the hood. Pay attention to `ImageLoaderMachO.h`.

### Dyld versions packaged in iOS versions 12.2 and greater.
If you were to use fishhook or another method to rebind symbols on runtime, and monitored open(), read(), close() you will find 2 calls that should stand out.

1) Open() called on original binary image
2) Read() for 4 Mem Pages (0x4000 Bytes on iOS 64 bit systems)
3) Read() for 1 Mem Page (0x1000 Bytes)
4) close() original binary image.

This initial read pulled *the first* 4 memory pages from the binary. iOS could use this to validate each page based on a hash, and also now has the files header and all load commands. (Think: ensure the filesize, and location of target data is in  alignment and valid) This includes checking the LC_ENCRYPTION_INFO_64 load command, to determine whether or not the file needs decrypted from Apple's FairPlay DRM as any official App store application would, and the LC_CODE_SIGNATURE_64 load command, which contains the offset and size of the binaries original code signature.

Since we know there is the need to validate and abort if code signature is invalid, you may have already been able to guess where this 2nd read is focused. :eyes:

The 2nd read() is located such that the end of this page worth of data includes the beginning of the binary's code signature to ensure that it is valid, else CrashIfInvalidCodeSignature() will throw a non-zero exit.

Given that I could now see where the application was being validated, it's time to give dyld what it wants :wink:

Within the Theos based branch of this project, you can find some samples on how you can easily identify the first however many bytes you'd like to find the starting location of this memory page in the stock encrypted binary target.

Gather up the initial 0x4000 bytes from the original binary while your're already looking at it and now we can make a bypass. 

## Dyld versions in iOS versions 11.*  to <12.2
Dyld versions packaged in iOS between 11 and under 12.2 use a slightly different validation, but the general methedology for mocking the data is the same. 

For these versions, the initial read on the target binary is the first 0x10000 Bytes, and then validates this against the hashes of these pages from the code signature. 

1) Grab first 0x10000 and put them into a uint8_t/Byte Array
2) Run a quick version to log out the first 8 or so bytes on the 2nd read to identify where the second segment is to start
3) Grab the 0x10000 bytes at this location and all set
4) Add some sort of global counter or such to ensure that when it reads you know which array you are memcpy-ing into place.
5) Your target App runs. :magic:

## Crafting your bypass dylib.
For my example, we know that:
1) A read of the first 4 pages (0x4000 Bytes) will be performed, and expects original unmodified binary's data. Dyld will use thiis to identify the location 
2) A read of 1 page (0x1000 Bytes) will be performed, and expects again, original unmodified binary's data

The basic bypass template is available in the bypassDyld folder of the repo. I generalized this into an objectic-c header and .m file so that it could be used with more than a Theos jailed project. 

The bypass is as simple as it sounds. 
1) Hardcode the stock first 4 memory pages into a uint8_t byte array
2) Hardcode the memory page for the code signature validation into a uint8_t byte array.
3) Create a custom read() implementation, and declare a pointer func to hold the original implementation
4) In the custom read, check if size of read is 0x4000 bytes, and you have not swapped them yet with a global counter, memcpy the original 4 memory pages into place after returning original read() Within your implementation. The same logic is applied for the next 0x1000 Byte block, and the global counter upped, such that you don't interfere with any further read() calls of these sizes. If neither of the 2 cases are true, returns the original implementation with original args.
5) Create an init call, where you invoke fishhooks symbol rebinding.

To invoke the bypass, you simply need to invoke the Init call in a constructor block (%ctor in logos) and off you go.

### How to use it?
However you want!? I've personally used a static framework template project in xcode with an additional buildphase to compile the project output into a dylib, and then inject that how i see fit. You could add a buildphase in that same project where you specify your target IPA, inject your dylib, and resign in a single step. 

The world is your oyster.

Shout out to Jorg and The silly Canadaian who helped hold my hand as I learned enough C/C++ to read through source and implement this. <3
