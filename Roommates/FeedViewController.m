
#import "FeedViewController.h"
#import "Note.h"
#import "User.h"
#import "SVProgressHUD.h"

@interface FeedViewController () <UIAlertViewDelegate>
@end

static int ADD_BUTTON_INDEX = 1;

@implementation FeedViewController


- (IBAction)addNote:(id)sender {
    if ([[User currentUser] isMemberOfAHousehold]) {
        UIAlertView *newNoteAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"New Note", nil)
                                                               message:@""
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                     otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        newNoteAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
        [newNoteAlert textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeSentences;
        [newNoteAlert show];
    } else {
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Not member of a household! Go to Me->Household Settings.", nil)];
    }
}

- (void)createNewNote:(Note *)newNote {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"Creating new Note", nil)];
    [newNote saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        [SVProgressHUD dismiss];
        if (!error) {
            [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"Note Created!", nil)];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NewNoteCreated" object:nil];
        } else {
            [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
        }
    }];
}

#pragma mark UIAlertView Delegate Methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == ADD_BUTTON_INDEX) {
        NSString *noteText = [alertView textFieldAtIndex:0].text;
        
        if ([noteText isEqualToString:@""]) {
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Note cannot be empty", nil)];
        } else {
            PFACL *acl = [PFACL ACL];
            [acl setReadAccess:YES forRoleWithName:[User currentUser].householdChannel];
            
            Note *newNote = [Note object];
            newNote.createdBy = [User currentUser];
            newNote.body = noteText;
            newNote.household = [User currentUser].activeHousehold;
            newNote.ACL = acl;
            
            [self createNewNote:newNote];
        }
    }
}

@end
