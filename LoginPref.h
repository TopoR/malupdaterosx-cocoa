//
//  LoginPref.h
//  MAL Updater OS X
//
//  Created by Nanoha Takamachi on 2014/10/18.
//  Copyright 2014 Atelier Shiori. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MASPreferencesViewController.h"
#import <ASIHTTPRequest/ASIHTTPRequest.h>
#import <ASIHTTPRequest/ASIFormDataRequest.h>
#import "MAL_Updater_OS_XAppDelegate.h"

@interface LoginPref : NSViewController <MASPreferencesViewController> {
	//Login Preferences
	IBOutlet NSTextField * fieldusername;
	IBOutlet NSTextField * fieldpassword;
	IBOutlet NSButton * savebut;
	IBOutlet NSButton * clearbut;
    MAL_Updater_OS_XAppDelegate* appdelegate;
}
- (id)initwithAppDelegate:(MAL_Updater_OS_XAppDelegate *)adelegate;
-(IBAction)startlogin:(id)sender;
-(IBAction)clearlogin:(id)sender;
-(void)showsheetmessage:(NSString *)message
		   explaination:(NSString *)explaination;
-(IBAction)registermal:(id)sender;
-(void)loadlogin;
@end
