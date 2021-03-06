//
//  AutoExceptions.h
//  Hachidori
//
//  Created by Tail Red on 1/31/15.
//  Copyright 2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import <Foundation/Foundation.h>

@interface AutoExceptions : NSObject
+ (void)importToCoreData;
+ (void)updateAutoExceptions;
+ (void)clearAutoExceptions;
+ (NSManagedObject *)checkAutoExceptionsEntry:(NSString *)ctitle
                                       group:(NSString *)group
                                correcttitle:(NSString *)correcttitle
                                 zeroepisode:(bool)zeroepisode
                                      offset:(int)offset;
@end
