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

#import "ChatViewController.h"
#import "ServicesViewController.h"

#define kOFFSET_FOR_KEYBOARD 80.0

@interface ChatViewController () <UITableViewDataSource, UITableViewDelegate, HYPObserver, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray * messagesArray;
@property (weak, nonatomic) IBOutlet UITextField *messageTextField;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *keyboardBottomConstraint;
@property (weak, nonatomic) IBOutlet UIView *uiView;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@end

@implementation ChatViewController

- (NSMutableArray *)messagesArray {
    
    // Array used to keep volatile storage of messages; because the storage is volatile, if
    // this screen is exited the messages will be lost
    if(_messagesArray==nil){
        _messagesArray = [[NSMutableArray alloc] init];
    }
    
    return _messagesArray;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self observeKeyboard];
    
    // Register self as a framework observer; in this case we are interested in received messages
    [[HYP instance] addHypeObserver:self];
    
    self.messageTextField.delegate = self;
    
    [self.tableView setDelegate:self];
    [self.tableView setDataSource:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.messagesArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    
    NSString * message = [self.messagesArray objectAtIndex:indexPath.row];
    cell.textLabel.text = message;
    
    return cell;
}

- (IBAction)sendButtonPress:(UIButton *)sender {
    
    if(self.messageTextField.text.length > 0){
        // Send the text entered in the text field
        [self sendMessage:self.messageTextField.text];
    }
}

- (void)sendMessage:(NSString*)message {
    
    NSData* data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error;
    
    // Send the message encoded in UTF-8
    [[HYP instance] sendMessageWithData:data
                              toService:self.service
                                  error:&error];
    
    if(error != nil){
        
        // TODO handle
        NSLog(@"%@", error);
        
        return;
    }
    
    NSString * messageAux = [NSString stringWithFormat:@"Me: %@", message];
    
    // Shows the message in the table view; notice that this will happen even if
    // the message is not delivered. The framework currently does not support
    // delivery acknowledgement
    [self.messagesArray addObject:messageAux];
    [self.tableView reloadData];
    
    // Clean up
    self.messageTextField.text = @"";
    
    [self scrollToBottom];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSUInteger length = self.messageTextField.text.length - range.length + string.length;
    
    if (length > 0) {
        self.sendButton.enabled = YES;
    }
    
    else {
        self.sendButton.enabled = NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if(self.messageTextField.text.length != 0) {
        
        // Send the message when the Enter key is pressed
        [self sendMessage:self.messageTextField.text];
        [self dismissKeyboard];
        
        return YES;
    }
    
    return NO;
}

- (void)scrollToBottom
{
    __weak ChatViewController * weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        ChatViewController * strongSelf = weakSelf;
        
        NSInteger cells_count = [strongSelf tableView:strongSelf.tableView numberOfRowsInSection:0];
        NSIndexPath* ipath = [NSIndexPath indexPathForRow: cells_count-1 inSection:0];
        
        [strongSelf.tableView scrollToRowAtIndexPath: ipath
                                    atScrollPosition: UITableViewScrollPositionTop
                                            animated: YES];
    });
}

#pragma Hype Delegates
- (void)hypeDidReceiveMessageWithData:(NSData *)data fromService:(HYPService *)service{
    NSString * name = [[NSString alloc] initWithData:service.announcement encoding:NSUTF8StringEncoding];
    
    NSString * name2 = [[NSString alloc] initWithData:self.service.announcement encoding:NSUTF8StringEncoding];
    
    if([name isEqualToString:name2]){
        NSData * messageData = data;
        NSString * messageReceive = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
        
        NSError* error;
        NSDictionary* jsonService = [NSJSONSerialization JSONObjectWithData:service.announcement
                                                                    options:kNilOptions
                                                                      error:&error];
        
        NSString * message = [NSString stringWithFormat:@"%@: %@",[jsonService objectForKey:@"name"] ,messageReceive];
        
        [self.messagesArray addObject:message];
        [self.tableView reloadData];
        [self scrollToBottom];
    }
}

- (void)hypeLostService:(HYPService *)service {
    
    NSError* error;
    NSDictionary* currentService = [NSJSONSerialization JSONObjectWithData:self.service.announcement
                                                                options:kNilOptions
                                                                  error:&error];
    if(error != nil){
        
        // TODO handle
        NSLog(@"%@", error);
        
        return;
    }
    
    NSDictionary* lostService = [NSJSONSerialization JSONObjectWithData:service.announcement
                                                                  options:kNilOptions
                                                                    error:&error];
    if(error != nil){
        
        // TODO handle
        NSLog(@"%@", error);
        
        return;
    }
    
    // Check whether the lost service matches the service this window is consuming; if so,
    // communication will no longer be possible and the window must be disabled
    if ([[currentService objectForKey:@"id"] isEqual: [lostService objectForKey:@"id"]]) {
        
        NSString * name = [NSString stringWithFormat:@"Lost %@",[currentService objectForKey:@"name"]];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Lost Service"
                                                        message:name
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        // Do not allow any more messages to be sent; the service is no longer valid
        self.messageTextField.enabled = NO;
    }

}

#pragma Keyboard

- (void)observeKeyboard
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary * info = [notification userInfo];
    NSValue * kbFrame = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    NSDecimalNumber * objAnimationDuration = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration = [objAnimationDuration doubleValue];
    CGRect keyboardFrame = [kbFrame CGRectValue];
    
    CGFloat height = keyboardFrame.size.height;
    
    self.keyboardBottomConstraint.constant = height;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    NSDecimalNumber * objAnimationDuration = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration = [objAnimationDuration doubleValue];
    
    self.keyboardBottomConstraint.constant = 0;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)dismissKeyboard
{
    [self.messageTextField resignFirstResponder];
}

- (IBAction)didRecognizeTapGesture:(UITapGestureRecognizer *)sender
{
    [self dismissKeyboard];
}


@end
