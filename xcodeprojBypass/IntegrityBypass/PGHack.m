//
//  PGHack.m
//  PGHack
//
//  Created by Kyle Nicol on 10/15/19.
//  Copyright © 2019 Hydra. All rights reserved.
//

#import "PGHack.h"
#import "dyldBypass/dyldBypass.h"

@implementation PGHack

    static void __attribute__((constructor)) initialize(void){
        [dyldBypass init];
    }
@end
