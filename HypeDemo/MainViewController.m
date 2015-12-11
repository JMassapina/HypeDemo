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

#import "MainViewController.h"
#import "ServicesViewController.h"

@interface MainViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIButton *okButton;
@property (weak, nonatomic) IBOutlet UITextField *nameTextField;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Listen to text field events; the OK button is toggled as enabled/disabled according
    // to whether text has been entered into the prompt
    self.nameTextField.delegate = self;
    
    // Disable the OK button until some value is written
    [self.okButton setEnabled:NO];
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSUInteger length = self.nameTextField.text.length - range.length + string.length;
    
    if (length > 0) {
        self.okButton.enabled = YES;
    }
    
    else {
        self.okButton.enabled = NO;
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"segueOk"])
    {
        // Propagates the prompted name to the next view controller
        ServicesViewController *servicesViewController = [segue destinationViewController];
        [servicesViewController setName:self.nameTextField.text];
    }
}


@end
