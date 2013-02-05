//
//  ViewController.m
//  OnAppStore
//
//  Created by Pavel Gnatyuk on 2/4/13.
//  Copyright (c) 2013 Pavel Gnatyuk. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>

@interface ViewController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>

@property (retain, nonatomic) IBOutlet UITextField      *textFieldApp;
@property (retain, nonatomic) IBOutlet UIButton         *buttonLookup;
@property (retain, nonatomic) IBOutlet UITableView      *tableViewContent;
@property (retain, nonatomic) IBOutlet UITableViewCell  *cellItem;

@property (retain) NSArray *content;

- (IBAction)clickOnButtonLookup:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [_textFieldApp release];
    [_buttonLookup release];
    [_tableViewContent release];
    [_cellItem release];
    [super dealloc];
}

- (IBAction)clickOnButtonLookup:(id)sender {
    if ( [[self textFieldApp] isFirstResponder] ) {
        [[self textFieldApp] resignFirstResponder];
    }
    [self searchFor:[[self textFieldApp] text]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self content] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:[self cellItem]];
        cell = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
        
        NSInteger row = [indexPath row];
        if ( row < [[self content] count] ) {
            NSDictionary *item = [self content][row];
            if ( item ) {
                UILabel *label = (UILabel *)[cell viewWithTag:10001];
                [label setText:item[@"trackName"]];
                
                label = (UILabel *)[cell viewWithTag:10002];
                [label setText:item[@"artistName"]];

                label = (UILabel *)[cell viewWithTag:10003];
                [label setText:[NSString stringWithFormat:@"Rating: %@", item[@"contentAdvisoryRating"]]];
            }
        }
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[self cellItem] frame].size.height;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self content][[indexPath row]];
    if ( item ) {
        NSNumber *appleID = item[@"trackId"];
        if ( appleID ) {
            [self showAppStoreOf:[appleID description]];
        }
    }
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)URLEncodedString:(NSString *)string
{
    CFStringRef stringRef = CFBridgingRetain(string);
    CFStringRef encoded = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                  stringRef,
                                                                  NULL,
                                                                  CFSTR("!*'\"();:@&=+$,/?%#[]% "),
                                                                  kCFStringEncodingUTF8);
    CFRelease(stringRef);
    return CFBridgingRelease(encoded);
}

- (void)searchFor:(NSString *)appleApp
{
    NSString *nameEncoded = [self URLEncodedString:appleApp];
    NSString *storeString = [NSString stringWithFormat:@"https://itunes.apple.com/search?term=%@&country=il&entity=software", nameEncoded];
    NSURL *storeURL = [NSURL URLWithString:storeString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:storeURL];
    [request setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    __block typeof(self) myself = self;

    [[self buttonLookup] setEnabled:NO];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if ( error ) {
            NSLog(@"connection error:%@", [error localizedDescription]);
            
        }
        else {
            if ( [data length] > 0 ) {
                NSError *errorJSON = nil;
                NSDictionary *appData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&errorJSON];
                if ( errorJSON ) {
                    NSLog(@"parsing error:%@", [errorJSON localizedDescription]);
                }
                else {
                    NSLog(@"data: %@", appData);
                    if ( [appData count] > 0 ) {
                        NSInteger count = [appData[@"resultCount"] integerValue];
                        NSLog(@"count = %i", count);
                        NSArray *results = appData[@"results"];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [myself setContent:results];
                            [[myself tableViewContent] reloadData];
                        });
                    }
                    else {
                        NSLog(@"Empty data");
                    }
                }
            }
            else {
                NSLog(@"Empty response");
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[myself buttonLookup] setEnabled:YES];
            });
        }
    }];
    [queue release];
}

- (void)showAppStoreOf:(NSString *)appleID
{
    if ( [SKStoreProductViewController class]) {
        SKStoreProductViewController *productController = [[SKStoreProductViewController alloc] init];
        productController.delegate = (id<SKStoreProductViewControllerDelegate>)self;
        NSDictionary *productParameters = @{SKStoreProductParameterITunesItemIdentifier:appleID};
        [productController loadProductWithParameters:productParameters completionBlock:NULL];
        
        [self presentViewController:productController animated:YES completion:nil];
    }
    else {
        NSString *reviewURL = [NSString stringWithFormat:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%@", appleID];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:reviewURL]];
    }
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)controller
{
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

@end
