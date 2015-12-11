//
// Copyright (C) 2015 Hype Labs - All Rights Reserved
//
// NOTICE: All information contained herein is, and remains the property of
// Hype Labs. The intellectual and technical concepts contained herein are
// proprietary to Hype Labs and may be covered by U.S. and Foreign Patents,
// patents in process, and are protected by trade secret and copyright law.
// Dissemination of this information or reproduction of this material is
// strictly forbidden unless prior written permission is obtained from
// Hype Labs.
//

#import "ServicesViewController.h"
#import <Hype/Hype.h>
#import "ChatViewController.h"

@interface ServicesViewController () <UITableViewDataSource, UITableViewDelegate, HYPObserver>

// Table view lists found services
@property (weak, nonatomic) IBOutlet UITableView *tableView;

// The services array works as a data source to the table view.
@property (strong, nonatomic) NSMutableArray * servicesArray;

@end

@implementation ServicesViewController

-(NSMutableArray *)servicesArray {
    
    if(_servicesArray == nil){
        _servicesArray = [[NSMutableArray alloc] init];
    }
    
    return _servicesArray;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        NSAssert(self.name != nil, @"No name was given");
        
        // Listen to framework events
        [[HYP instance] addHypeObserver:self];
        
        // Generates an announcement that includes a random UUID, simulating a user identifier
        // and the user's name. The identifier is used to uniquely identify the peer on the
        // network and the name is shown to the end user in the table view
        NSMutableDictionary *jsonAnnouncement = [[NSMutableDictionary alloc] init];
        [jsonAnnouncement setObject:[[NSUUID UUID] UUIDString] forKey:@"id"];
        [jsonAnnouncement setObject:self.name forKey:@"name"];
        
        // Encode as JSON; announcements could be sent in any format
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonAnnouncement
                                                           options:kNilOptions
                                                             error:&error];
        if(error != nil){
            
            // Should be handled in a real-life application
            NSLog(@"%@", error);
            
            return;
        }
        
        NSError *addServiceError;
        
        // Registers the service with the framework instance; services have not been started
        // yet, so the service will not yet be visible on the network
        [[HYP instance] addServiceWithName:@"hypeService"
                              announcement:jsonData
                                     error:&addServiceError];
        
        if(addServiceError != nil){
            
            // Should be handled in a real-life application
            NSLog(@"%@", addServiceError);
            
            return;
        }
        
        // Start services; if everything goes well the device should be actively advertising
        // itself on the network
        [[HYP instance] start];
    });
    
    [self.tableView setDelegate:self];
    [self.tableView setDataSource:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.servicesArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        
        // Instantiate a new cell if none is queued
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    
    NSData * announcementData = [[self.servicesArray objectAtIndex:indexPath.row] announcement];
    
    // Announcements are being encoded in JSON format; this snipped parses it as so
    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:announcementData
                                                         options:kNilOptions
                                                           error:&error];

    
    // The cell will show the user's name
    NSString * name = [json objectForKey:@"name"];
    cell.textLabel.text = name;
    
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Fetch the service associated with the selected cell
    NSIndexPath* indexPath = [self.tableView indexPathForCell:sender];
    HYPService * service = [self.servicesArray objectAtIndex:indexPath.row];
    
    // Open a chat session with that service
    ChatViewController *chatViewController = [segue destinationViewController];
    [chatViewController setService:service];
}

#pragma Hype Delegates

- (void)hypeDidStart:(HYP *)hype{
    
    NSLog(@"Hype started services");
}

- (void)hypeDidStop:(HYP *)hype error:(NSError *)error{
    
    NSLog(@"Hype stopped services");
}

- (void)hypeFoundService:(HYPService *) service{
    
    NSLog(@"Hype found service");
    
    // Register the new service with the data source and reload the table
    [self.servicesArray addObject:service];
    [self.tableView reloadData];
}

- (void)hypeLostService:(HYPService *) service{
    
    NSLog(@"Hype lost service");
    
    for (HYPService *lostService in self.servicesArray) {
        
        NSError* jsonServiceError;
        NSDictionary* jsonService = [NSJSONSerialization JSONObjectWithData:lostService.announcement
                                                             options:kNilOptions
                                                               error:&jsonServiceError];
        if(jsonServiceError!=nil){
            
            // TODO handle
            NSLog(@"%@", jsonServiceError);
            
            return;
        }
        
        NSError* myJsonServiceError;
        NSDictionary* myJsonService = [NSJSONSerialization JSONObjectWithData:service.announcement
                                                                    options:kNilOptions
                                                                      error:&myJsonServiceError];
        if(myJsonServiceError!=nil){
            
            // TODO handle
            NSLog(@"%@", myJsonServiceError);
            
            return;
        }
        
        // When the service is found on the registry its removed
        if ([[jsonService objectForKey:@"id"] isEqualToString: [myJsonService objectForKey:@"id"]]) {
            [self.servicesArray removeObject:lostService];
            break;
        }
    }
    [self.tableView reloadData];
}

@end
