//
//  MyAnimeList.m
//  MAL Updater OS X
//
//  Created by James M. on 8/7/10.
//  Copyright 2009-2015 Atelier Shiori. All rights reserved. Code licensed under New BSD License
//

#import "MyAnimeList.h"
#import "Detection.h"
#import "MyAnimeList+Search.h"
#import "MyAnimeList+Update.h"
#import "MyAnimeList+HummingbirdSearch.h"
#import "Reachability.h"

@interface MyAnimeList ()
-(int)detectmedia; // 0 - Nothing, 1 - Same, 2 - Update
-(void)checkExceptions;
@end

@implementation MyAnimeList
@synthesize managedObjectContext;
-(id)init{
    confirmed = true;
    //Create Reachability Object
    reach = [Reachability reachabilityWithHostname:@"malapi.ateliershiori.moe"];
    // Set up blocks
    // Set the blocks
    reach.reachableBlock = ^(Reachability*reach)
    {
        online = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Atarashii-API is reachable.");
        });
    };
    reach.unreachableBlock = ^(Reachability*reach)
    {
        online = false;
        NSLog(@"Computer not connected to internet or Atarashii-API Server is down");
    };
    // Start notifier
    [reach startNotifier];
    return [super init];
}
-(void)setManagedObjectContext:(NSManagedObjectContext *)context{
    managedObjectContext = context;
}
/* 
 
 Accessors
 
 */
-(NSString *)getLastScrobbledTitle
{
    return LastScrobbledTitle;
}
-(NSString *)getLastScrobbledEpisode
{
    return LastScrobbledEpisode;
}
-(NSString *)getLastScrobbledActualTitle{
    return LastScrobbledActualTitle;
}
-(NSString *)getLastScrobbledSource{
    return LastScrobbledSource;
}
-(NSString *)getFailedTitle{
    return FailedTitle;
}
-(NSString *)getFailedEpisode{
    return FailedEpisode;
}
-(NSString *)getAniID
{
    return AniID;
}
-(int)getTotalEpisodes
{
	return TotalEpisodes;
}
-(int)getScore
{
    return TitleScore;
}
-(int)getCurrentEpisode{
    return DetectedCurrentEpisode;
}
-(BOOL)getConfirmed{
    return confirmed;
}
-(BOOL)getisNewTitle{
    return LastScrobbledTitleNew;
}
-(int)getWatchStatus
{
	if ([WatchStatus isEqualToString:@"watching"])
		return 0;
	else if ([WatchStatus isEqualToString:@"completed"])
		return 1;
	else if ([WatchStatus isEqualToString:@"on-hold"])
		return 2;
	else if ([WatchStatus isEqualToString:@"dropped"])
		return 3;
    else if ([WatchStatus isEqualToString:@"plan-to-watch"])
        return 4;
	else
		return 0; //fallback
}
-(BOOL)getSuccess{
    return Success;
}
-(BOOL)getOnlineStatus{
    return online;
}
/*
 
 Update Methods
 
 */

- (int)startscrobbling {

    // 0 - nothing playing; 1 - same episode playing; 2 - No Update Needed; 3 - Confirm title before updating  21 - Add Title Successful; 22 - Update Title Successful;  51 - Can't find Title; 52 - Add Failed; 53 - Update Failed; 54 - Scrobble Failed - 23 - Offline Queue;
    int detectstatus;
	//Set up Delegate
	
    detectstatus = [self detectmedia];
	if (detectstatus == 2) { // Detects Title
        if (online){
            return [self scrobble];
        }
        else{
            NSError * error;
            if (![self checkifexistinqueue]) {
                // Store in offline queue
                NSManagedObject *obj = [NSEntityDescription
                                        insertNewObjectForEntityForName:@"OfflineQueue"
                                        inManagedObjectContext: managedObjectContext];
                // Set values in the new record
                [obj setValue:DetectedTitle forKey:@"detectedtitle"];
                [obj setValue:DetectedEpisode forKey:@"detectedepisode"];
                [obj setValue:DetectedType forKey:@"detectedtype"];
                [obj setValue:DetectedSource forKey:@"source"];
                [obj setValue:[NSNumber numberWithInteger:DetectedSeason] forKey:@"detectedseason"];
                [obj setValue:[NSNumber numberWithBool:DetectedTitleisMovie] forKey:@"ismovie"];
                [obj setValue:[NSNumber numberWithBool:DetectedTitleisEpisodeZero] forKey:@"iszeroepisode"];
                [obj setValue:[NSNumber numberWithInteger:23] forKey:@"status"];
                [obj setValue:[NSNumber numberWithBool:false] forKey:@"scrobbled"];
                //Save
                [managedObjectContext save:&error];
            }
            // Store Last Scrobbled Title
            LastScrobbledTitle = DetectedTitle;
            LastScrobbledEpisode = DetectedEpisode;
            DetectedCurrentEpisode = [DetectedEpisode intValue];
            LastScrobbledSource = DetectedSource;
            LastScrobbledActualTitle = DetectedTitle;
            confirmed = true;
            // Reset Detected Info
            DetectedTitle = nil;
            DetectedEpisode = nil;
            DetectedSource = nil;
            DetectedGroup = nil;
            DetectedType = nil;
            DetectedSeason = 0;
            Success = true;
            return 23;
        }
	}

    return detectstatus;
}
-(int)scrobblefromqueue:(NSDictionary *)info{
    // Restore Detected Media
    
}
-(int)scrobbleagain:(NSString *)showtitle Episode:(NSString *)episode correctonce:(BOOL)correctonce{
	correcting = true;
    NSString * lasttitle;
    if (correctonce) {
        lasttitle = LastScrobbledTitle;
    }
    DetectedTitle = showtitle;
    DetectedEpisode = episode;
    if (FailedSource == nil) {
        DetectedSource = LastScrobbledSource;
    }
    else{
        DetectedSource = FailedSource;
    }
    // Check Exceptions
    [self checkExceptions];
    // Scrobble and return status code
    int status = [self scrobble];
    if (correctonce) {
        LastScrobbledTitle = lasttitle; //Set the Last Scrobbled Title to exact title.
    }
    return status;
}
-(int)scrobble{
    NSLog(@"=============");
    NSLog(@"Scrobbling...");
    // Set MAL API URL
    MALApiUrl = [[NSUserDefaults standardUserDefaults] objectForKey:@"MALAPIURL"];
    int status;
    NSLog(@"Finding AniID");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"useSearchCache"]) {
        // Check Cache
        NSString *theid = [self checkCache];
        if (theid.length == 0){
            // Search for title
            AniID = [self startSearch];
        }
           
        else{
            AniID = theid; // Set cached show id as AniID
            //If Detected Episode is missing, set it to 1 for sanity
            if ([DetectedEpisode length] == 0) {
                DetectedEpisode = @"1";
            }
        }
    }
    else {
        AniID = [self startSearch]; //Search Cache Disabled
    }
    if (AniID.length > 0) {
        NSLog(@"Found %@", AniID);
        // Nil out Failed Title and Episode
        FailedTitle = nil;
        FailedEpisode = nil;
        FailedSource = nil;
        // Check Status and Update
        BOOL UpdateBool = [self checkstatus:AniID];
        if (UpdateBool == 1) {
            if (LastScrobbledTitleNew) {
                //Title is not on list. Add Title
                int s = [self addtitle:AniID confirming:confirmed];
                if (s == 21 || s == 3){
                    Success = true;}
                else{
					Success = false;}
				status = s;
            }
            else {
                // Update Title as Usual
                int s = [self updatetitle:AniID confirming:confirmed];
                if (s == 2 || s == 3 ||s == 22 ) {
                    Success = true;
                }
                else{
                    Success = false;}
                status = s;
                
            }
        }
        else{
            if (online) {
                NSLog(@"Error: Invalid Credentials.");
                status = 54;
            }
            else{
                NSLog(@"Error: User is offline.");
                //Ofline
                status = 55;
            }
        }
    }
    else {
        if (online) {
            // Not Successful
            NSLog(@"Error: Couldn't find title %@. Please add an Anime Exception rule.", DetectedTitle);
            // Used for Exception Adding
            FailedTitle = DetectedTitle;
            FailedEpisode = DetectedEpisode;
            FailedSource = DetectedSource;
            status = 51;
        }
        else{
            //Offline
            status = 55;
        }
        
    }
    // Empty out Detected Title/Episode to prevent same title detection
    DetectedTitle = nil;
    DetectedEpisode = nil;
    DetectedSource = nil;
    DetectedGroup = nil;
    DetectedType = nil;
    DetectedSeason = 0;
    // Clear Core Data Objects from Memory
    [managedObjectContext reset];
    // Reset correcting Value
    correcting = false;
    NSLog(@"Scrobble Complete with Status Code: %i", status);
    NSLog(@"=============");
    // Release Detected Title/Episode.
    return status;

}
-(int)detectmedia {
    NSDictionary * result = [Detection detectmedia];
    if (result !=nil) {
        //Populate Data
        DetectedTitle = result[@"detectedtitle"];
        DetectedEpisode = result[@"detectedepisode"];
        DetectedSeason = [(NSNumber *)result[@"detectedseason"] intValue];
        DetectedGroup = result[@"group"];
        DetectedSource = result[@"detectedsource"];
        if ([(NSArray *)result[@"types"] count] > 0) {
            DetectedType = [result[@"types"] objectAtIndex:0];
        }
        else{
            DetectedType = @"";
        }
        // Check for Episode 0 titles
        [self checkzeroEpisode];
        // Check if the title was previously scrobbled
        [self checkExceptions];
        
        if ([DetectedTitle isEqualToString:LastScrobbledTitle] && ([DetectedEpisode isEqualToString: LastScrobbledEpisode]||[self checkBlankDetectedEpisode]) && Success == 1) {
            // Do Nothing
            return 1;
        }
        else {
            // Not Scrobbled Yet or Unsuccessful
            return 2;
        }
    }
    else{
        return 0;
    }
}
-(BOOL)checkBlankDetectedEpisode{
    if ([LastScrobbledEpisode isEqualToString:@"1"] && [DetectedEpisode length] == 0) {
        return true;
    }
    return false;
}
-(BOOL)confirmupdate{
    DetectedTitle = LastScrobbledTitle;
    DetectedEpisode = LastScrobbledEpisode;
    DetectedSource  = LastScrobbledSource;
    NSLog(@"=============");
    NSLog(@"Confirming: %@ - %@",LastScrobbledActualTitle, LastScrobbledEpisode);
    int status;
	if(LastScrobbledTitleNew)
	{
		status = [self addtitle:AniID confirming:true];
	}
	else{
		status = [self updatetitle:AniID confirming:true];
	}
    NSLog(@"Confirming process complete with status code: %i", status);
    switch (status) {
        case 21:
        case 22:
            // Clear Detected Episode and Title
            DetectedTitle = nil;
            DetectedEpisode = nil;
            DetectedSource = nil;
            return true;
            
        default:
            return false;
    }
}
-(NSDictionary *)getLastScrobbledInfo{
	return LastScrobbledInfo;
}
-(void)clearAnimeInfo{
    LastScrobbledInfo = nil;
}
-(void)checkzeroEpisode{
    // For 00 Episodes
    if ([DetectedEpisode isEqualToString:@"00"]||[DetectedEpisode isEqualToString:@"0"]) {
        DetectedEpisode = @"1";
        DetectedTitleisEpisodeZero = true;
    }
    else if ([DetectedType isLike:@"Movie"] && ([DetectedEpisode isEqualToString:@"0"] || DetectedEpisode.length == 0)){
        DetectedEpisode = @"1";
    }
    else{DetectedTitleisEpisodeZero = false;}
}
-(NSString *)checkCache{
    NSManagedObjectContext *moc = managedObjectContext;
    NSFetchRequest * allCaches = [[NSFetchRequest alloc] init];
    [allCaches setEntity:[NSEntityDescription entityForName:@"Cache" inManagedObjectContext:moc]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"detectedTitle == %@", DetectedTitle];
    [allCaches setPredicate:predicate];
    NSError * error = nil;
    NSArray * cache = [moc executeFetchRequest:allCaches error:&error];
    if (cache.count > 0) {
        for (NSManagedObject * cacheentry in cache) {
            NSString * title = [cacheentry valueForKey:@"detectedTitle"];
            if ([title isEqualToString:DetectedTitle]) {
                NSLog(@"%@ is found in cache.", title);
                // Total Episode check
                NSNumber * totalepisodes = [cacheentry valueForKey:@"totalEpisodes"];
                if ( [DetectedEpisode intValue] <= totalepisodes.intValue || totalepisodes.intValue == 0 ) {
                    return [cacheentry valueForKey:@"id"];
                }
            }
        }
    }
    return @"";
}
-(void)checkExceptions{
    // Check Exceptions
    NSManagedObjectContext * moc = self.managedObjectContext;
    bool found = false;
    NSPredicate *predicate;
    for (int i = 0; i < 2; i++) {
        NSFetchRequest * allExceptions = [[NSFetchRequest alloc] init];
        NSError * error = nil;
        if (i == 0) {
            NSLog(@"Check Exceptions List");
            allExceptions.entity = [NSEntityDescription entityForName:@"Exceptions" inManagedObjectContext:moc];
            predicate = [NSPredicate predicateWithFormat: @"detectedTitle == %@", DetectedTitle];
        }
        else if (i== 1 && [[NSUserDefaults standardUserDefaults] boolForKey:@"UseAutoExceptions"]){
            NSLog(@"Checking Auto Exceptions");
            allExceptions.entity = [NSEntityDescription entityForName:@"AutoExceptions" inManagedObjectContext:moc];
            predicate = [NSPredicate predicateWithFormat: @"(detectedTitle ==[c] %@) AND ((group == %@) OR (group == %@))", DetectedTitle, DetectedGroup, @"ALL"];
        }
        else{break;}
        // Set Predicate and filter exceiptions array
        [allExceptions setPredicate: predicate];
        NSArray * exceptions = [moc executeFetchRequest:allExceptions error:&error];
        if (exceptions.count > 0) {
            NSString * correcttitle;
            for (NSManagedObject * entry in exceptions) {
                NSLog(@"%@",(NSString *)[entry valueForKey:@"detectedTitle"]);
                if ([DetectedTitle isEqualToString:(NSString *)[entry valueForKey:@"detectedTitle"]]) {
                    correcttitle = (NSString *)[entry valueForKey:@"correctTitle"];
                    // Set Correct Title and Episode offset (if any)
                    int threshold = ((NSNumber *)[entry valueForKey:@"episodethreshold"]).intValue;
                    int offset = ((NSNumber *)[entry valueForKey:@"episodeOffset"]).intValue;
                    int tmpepisode = DetectedEpisode.intValue - offset;
                    int mappedepisode = [(NSNumber *)[entry valueForKey:@"mappedepisode"] intValue];
                    bool iszeroepisode = [(NSNumber *)[entry valueForKey:@"iszeroepisode"] boolValue];
                    if (i==1 && DetectedTitleisEpisodeZero == true && iszeroepisode == true){
                        NSLog(@"%@ zero episode is found on exceptions list as %@.", DetectedTitle, correcttitle);
                        DetectedTitle = [correcttitle stringByReplacingOccurrencesOfString:@":" withString:@""];
                        DetectedEpisode = [NSString stringWithFormat:@"%i", mappedepisode];
                        DetectedTitleisEpisodeZero = true;
                        found = true;
                        break;
                    }
                    else if (i==1 && DetectedTitleisEpisodeZero == false && iszeroepisode == true){
                        continue;
                    }
                    if ((tmpepisode > threshold && threshold != 0) || (tmpepisode <= 0 && threshold != 1 && i==0)||(tmpepisode <= 0 && i==1)) {
                        continue;
                    }
                    else {
                        NSLog(@"%@ found on exceptions list as %@.", DetectedTitle, correcttitle);
                        DetectedTitle = [correcttitle stringByReplacingOccurrencesOfString:@":" withString:@""];
                        if (tmpepisode > 0) {
                            DetectedEpisode = [NSString stringWithFormat:@"%i", tmpepisode];
                        }
                        DetectedSeason = 0;
                        DetectedTitleisEpisodeZero = false;
                        found = true;
                        break;
                    }
                }
            }
            if (found){break;} //Break from exceptions check loop
        }
    }
}
-(NSString *)startSearch{
    // Performs Search
    NSString * tmpid;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"useHummingbirdSearch"]) {
        // Search using Hummingbird.me Search API to get malapi_id
        tmpid = [self hsearchanime];
        if (tmpid.length == 0) {
            // Fallback
            tmpid =[self searchanime];
        }
    }
    else{
        tmpid = [self searchanime]; // Use MAL Search
    }
    return tmpid;
}
-(NSManagedObject *)checkifexistinqueue{
    // Return existing offline queue item
    NSError * error;
    NSManagedObjectContext * moc = self.managedObjectContext;
    NSPredicate * predicate = [NSPredicate predicateWithFormat: @"(detectedtitle ==[c] %@) AND (detectedepisode ==[c] %@) AND (detectedtype ==[c] %@) AND (ismovie == %i) AND (iszeroepisode == %i) AND (detectedseason == %i) AND (source == %@)", DetectedTitle, DetectedEpisode, DetectedType, DetectedTitleisMovie, DetectedTitleisEpisodeZero, DetectedSeason, DetectedSource];
    NSFetchRequest * queuefetch = [[NSFetchRequest alloc] init];
    queuefetch.entity = [NSEntityDescription entityForName:@"OfflineQueue" inManagedObjectContext:moc];
    [queuefetch setPredicate: predicate];
    NSArray * queue = [moc executeFetchRequest:queuefetch error:&error];
    if (queue.count > 0) {
        return (NSManagedObject *)queue[0];
    }
    return nil;
}
@end
