//
//  FixSearchDialog.m
//  MAL Updater OS X
//
//  Created by 高町なのは on 2014/11/15.
//  Copyright (c) 2014年 Atelier Shiori. All rights reserved.
//

#import "FixSearchDialog.h"
#import <EasyNSURLConnection/EasyNSURLConnectionClass.h>
#import "NSString_stripHtml.h"
#import "Utility.h"

@interface FixSearchDialog ()

@end

@implementation FixSearchDialog

@synthesize arraycontroller;
@synthesize search;
@synthesize deleteoncorrection;
@synthesize onetimecorrection;
@synthesize tb;
@synthesize selectedsynopsis;
@synthesize selectedtitle;
@synthesize selectedaniid;
@synthesize selectedtotalepisodes;
@synthesize searchquery;
@synthesize correction;
@synthesize allowdelete;

- (id)init{
    self = [super initWithWindowNibName:@"FixSearchDialog"];
     if(!self)
       return nil;
    return self;
}
            
- (void)windowDidLoad {
    if (correction) {
        if (allowdelete) {
            [deleteoncorrection setHidden:NO];
            deleteoncorrection.state = NSOnState;
        }
        [onetimecorrection setHidden:NO];
    }
    else {
        deleteoncorrection.state = 0;
    }
    [super windowDidLoad];
    if (searchquery.length>0) {
        search.stringValue = searchquery;
        [self search:nil];
    }
}

- (IBAction)closesearch:(id)sender {
    [self.window orderOut:self];
    [NSApp endSheet:self.window returnCode:0];
}

- (IBAction)updatesearch:(id)sender {
    NSDictionary *d = arraycontroller.selectedObjects[0];
    if (correction) {
        // Set Up Prompt Message Window
        NSAlert *alert = [[NSAlert alloc] init] ;
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        alert.messageText = [NSString stringWithFormat:@"Do you want to correct this title as %@?",d[@"title"]];
        alert.informativeText = @"Once done, you cannot undo this action.";
        // Set Message type to Warning
        alert.alertStyle = NSWarningAlertStyle;
        if ([alert runModal]== NSAlertFirstButtonReturn) {
            [self finish:d];
        }
        else {
            return;
        }
    }
    else {
        [self finish:d];
    }   
}

- (void)finish:(NSDictionary *)d{
    selectedtitle = d[@"title"];
    selectedaniid = [d[@"id"] stringValue];
	if (d[@"episodes"]) {
    	selectedtotalepisodes = ((NSNumber *)d[@"episodes"]).intValue;
	}
	else {
		// No episode total yet, set to set
		selectedtotalepisodes = @(0);
	}
    [self.window orderOut:self];
    [NSApp endSheet:self.window returnCode:1];
}

- (IBAction)search:(id)sender{
    if (search.stringValue.length> 0) {
        dispatch_queue_t queue = dispatch_get_global_queue(
                                                           DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
        NSString *searchterm = [Utility urlEncodeString:search.stringValue];
        //Set Search API
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/1/anime/search?q=%@",[[NSUserDefaults standardUserDefaults] objectForKey:@"MALAPIURL"], searchterm]];
        EasyNSURLConnection *request = [[EasyNSURLConnection alloc] initWithURL:url];
        //Ignore Cookies
        [request setUseCookies:NO];
        //Perform Search
        [request startRequest];
        // Get Status Code
        long statusCode = [request getStatusCode];
        NSData *response = [request getResponseData];
        dispatch_async(dispatch_get_main_queue(), ^{
        switch (statusCode) {
            case 200:
                [self populateData:response];
                break;
            default:
                break;
        }
        });
        });
    }
    else {
        //Remove all existing Data
        [[arraycontroller mutableArrayValueForKey:@"content"] removeAllObjects];
    }
}

- (IBAction)getHelp:(id)sender{
    //Show Help
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/chikorita157/malupdaterosx-cocoa/wiki/Correction-Exception-Help"]];
}

- (void)populateData:(NSData *)data{
    //Remove all existing Data
    [[arraycontroller mutableArrayValueForKey:@"content"] removeAllObjects];
    
    //Parse Data
    NSError* error;
    
    NSArray *searchdata = [NSJSONSerialization JSONObjectWithData:data options:nil error:&error];
    
    //Add it to the array controller
    [arraycontroller addObjects:searchdata];
    
    //Show on tableview
    [tb reloadData];
    //Deselect Selection
    [tb deselectAll:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification{
    if ([notification.object selectedRow] != -1) {
        // Show synopsis
        NSDictionary *d = arraycontroller.selectedObjects[0];
        selectedsynopsis.string = [[NSString stringWithFormat:@"%@", d[@"synopsis"]] stripHtml];
    }
    else {
        selectedsynopsis.string = @"";
    }

}

- (bool)getdeleteTitleonCorrection{
    return (bool) deleteoncorrection.state;
}

- (bool)getcorrectonce{
    return (bool) onetimecorrection.state;
}

@end
