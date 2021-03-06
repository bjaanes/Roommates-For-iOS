
#import "TaskListElementsTableViewController.h"
#import "EditTaskListElementViewController.h"
#import "TaskListElement.h"

#import "SVProgressHUD.h"

#define unfinishedSectionNumber 0
#define finishedSectionNumber 1

@interface TaskListElementsTableViewController () <UIAlertViewDelegate, UITextFieldDelegate, UIActionSheetDelegate>

@property (strong, nonatomic) NSArray *finishedTaskListElements; // of TaskListElement *
@property (strong, nonatomic) NSArray *unfinishedTaskListElements; // of TaskListElement *
@property (weak, nonatomic) IBOutlet UITextField *addItemTextField;
@end

@implementation TaskListElementsTableViewController

#pragma mark getters and setters

- (NSArray *)finishedTaskListElements {
    if (!_finishedTaskListElements) {
        _finishedTaskListElements = [[NSArray alloc] init];
    }
    return _finishedTaskListElements;
}

- (NSArray *)unfinishedTaskListElements {
    if (!_unfinishedTaskListElements) {
        _unfinishedTaskListElements = [[NSArray alloc] init];
    }
    return _unfinishedTaskListElements;
}

- (void)setTaskList:(TaskList *)taskList {
    _taskList = taskList;
    [self refreshTaskListElements];
    self.title = taskList.listName;
}

#pragma mark View Controller Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    CGRect frameRect = self.addItemTextField.frame;
    frameRect.size.height = 44;
    self.addItemTextField.frame = frameRect;
    
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = [NSArray arrayWithObjects:
                           [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                           [[UIBarButtonItem alloc]initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithAdding)],
                           nil];
    [numberToolbar sizeToFit];
    self.addItemTextField.inputAccessoryView = numberToolbar;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveResetHouseholdScenesNotification:) name:@"ResetHouseholdScenes" object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![[User currentUser] isMemberOfAHousehold]) {
        [self.navigationController popToRootViewControllerAnimated:NO];
    }
}

#pragma mark Methods

- (void)didReceiveResetHouseholdScenesNotification:(NSNotificationCenter *)notificationCenter {
    [self.navigationController popToRootViewControllerAnimated:NO];
}

- (IBAction)pullToRefresh:(id)sender {
    [self refreshTaskListElements];
}

- (IBAction)editList:(id)sender {
    NSString *toggleTitle;
    if (self.taskList.done) {
        toggleTitle = NSLocalizedString(@"Mark as unfinished", nil);
    }
    else {
        toggleTitle = NSLocalizedString(@"Mark as finished", nil);
    }
    UIActionSheet *popup =
            [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Edit List", nil)
                                        delegate:self
                               cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                          destructiveButtonTitle:NSLocalizedString(@"Delete Task List", nil)
                               otherButtonTitles:NSLocalizedString(@"Rename Task List", nil),
                                                 toggleTitle,
                                                 nil];
    [popup showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)doneWithAdding {
    [self saveTaskListElement:self.addItemTextField.text];
    [self.addItemTextField setText:@""];
    [self.addItemTextField resignFirstResponder];
}

- (void)refreshTaskListElements {
    if ([[User currentUser] isMemberOfAHousehold]) {
        PFQuery *taskListElementsQuery = [TaskListElement query];
        [taskListElementsQuery whereKey:@"taskList" equalTo:self.taskList];
        [taskListElementsQuery includeKey:@"createdBy"];
        [taskListElementsQuery includeKey:@"updatedBy"];
        [taskListElementsQuery includeKey:@"finishedBy"];
        [taskListElementsQuery orderByDescending:@"updatedAt"];
        
        if (self.unfinishedTaskListElements.count == 0 && self.finishedTaskListElements == 0 && [taskListElementsQuery hasCachedResult]) {
            taskListElementsQuery.cachePolicy = kPFCachePolicyCacheThenNetwork;
        }
        else {
            taskListElementsQuery.cachePolicy = kPFCachePolicyNetworkOnly;
        }
        
        
        [taskListElementsQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            [self.refreshControl endRefreshing];
            if (!error) {
                NSMutableArray *unfinishedTaskListElements = [objects mutableCopy];
                NSMutableArray *finishedTaskListElements = [[NSMutableArray alloc] init];
                
                for (TaskListElement *taskList in objects) {
                    if (taskList.finishedBy) {
                        [finishedTaskListElements addObject:taskList];
                        [unfinishedTaskListElements removeObject:taskList];
                    }
                }
                
                self.unfinishedTaskListElements = unfinishedTaskListElements;
                self.finishedTaskListElements = finishedTaskListElements;
                [self.tableView reloadData];
            } else {
                [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
            }
        }];
    }
    else {
        [self.refreshControl endRefreshing];
        self.unfinishedTaskListElements = [NSArray array];
        self.finishedTaskListElements = [NSArray array];
        [self.tableView reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == unfinishedSectionNumber) {
        return self.unfinishedTaskListElements.count;
    }
    else if (section == finishedSectionNumber) {
        return self.finishedTaskListElements.count;
    }
    else {
        return 0;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"taskListElementCell" forIndexPath:indexPath];
    
    TaskListElement *taskListElement;
    if (indexPath.section == unfinishedSectionNumber) {
        cell.textLabel.textColor = [UIColor blackColor];
        cell.detailTextLabel.textColor = [UIColor blackColor];
        
        taskListElement = [self.unfinishedTaskListElements objectAtIndex:indexPath.row];
        User *createdBy = taskListElement.createdBy;
        cell.detailTextLabel.text =
                [NSString stringWithFormat:NSLocalizedString(@"Added by %@", nil), createdBy.displayName];
    }
    else if (indexPath.section == finishedSectionNumber) {
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        
        taskListElement = [self.finishedTaskListElements objectAtIndex:indexPath.row];
        User *finishedBy = taskListElement.finishedBy;
        cell.detailTextLabel.text =
                [NSString stringWithFormat:NSLocalizedString(@"Finished by %@", nil), finishedBy.displayName];
    }
    
    
    cell.textLabel.text = taskListElement.elementName;
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == unfinishedSectionNumber) {
        TaskListElement *taskListElement = [self.unfinishedTaskListElements objectAtIndex:indexPath.row];
        taskListElement.finishedBy = [User currentUser];

        NSMutableArray *unfinishedTmpArray = [self.unfinishedTaskListElements mutableCopy];
        [unfinishedTmpArray removeObject:taskListElement];
        
        NSMutableArray *finishedTmpArray = [[NSMutableArray alloc] init];
        [finishedTmpArray addObject:taskListElement];
        [finishedTmpArray addObjectsFromArray:self.finishedTaskListElements];
        
        self.unfinishedTaskListElements = unfinishedTmpArray;
        self.finishedTaskListElements = finishedTmpArray;
        [self.tableView reloadData];
        
        
        
        [taskListElement saveEventually];
    }
    else if (indexPath.section == finishedSectionNumber) {
        TaskListElement *taskListElement = [self.finishedTaskListElements objectAtIndex:indexPath.row];
        [taskListElement removeObjectForKey:@"finishedBy"];
        
        NSMutableArray *finishedTmpArray = [self.finishedTaskListElements mutableCopy];
        [finishedTmpArray removeObject:taskListElement];
        
        NSMutableArray *unfinishedTmpArray = [[NSMutableArray alloc] init];
        [unfinishedTmpArray addObject:taskListElement];
        [unfinishedTmpArray addObjectsFromArray:self.unfinishedTaskListElements];
        
        self.unfinishedTaskListElements = unfinishedTmpArray;
        self.finishedTaskListElements = finishedTmpArray;
        [self.tableView reloadData];

        [taskListElement saveEventually];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == unfinishedSectionNumber) {
        return @"";
    }
    else if (section == finishedSectionNumber) {
        return NSLocalizedString(@"Done", nil);
    }
    
    return @"";
}


#pragma mark UITextField Delegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *elementName = textField.text;
    [self saveTaskListElement:elementName];
    textField.text = @"";
    return NO;
}

- (void) saveTaskListElement:(NSString *)elementName {
    if (![elementName isEqualToString:@""]) {
        if ([User currentUser] && [User currentUser].activeHousehold && self.taskList) {
            PFACL *acl = [PFACL ACL];
            [acl setReadAccess:YES forRoleWithName:[User currentUser].householdChannel];
            [acl setWriteAccess:YES forRoleWithName:[User currentUser].householdChannel];
            
            TaskListElement *newTaskListElement = [TaskListElement object];
            newTaskListElement.elementName = elementName;
            newTaskListElement.taskList    = self.taskList;
            newTaskListElement.createdBy   = [User currentUser];
            newTaskListElement.ACL         = acl;
            
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Adding New Task List Element", nil) maskType:SVProgressHUDMaskTypeBlack];
            [newTaskListElement saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                [SVProgressHUD dismiss];
                if (!error) {
                    [self refreshTaskListElements];
                }
                else {
                    [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
                }
            }];
        }
    }
}
        

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"editTaskListElementSegue"]) {
        if ([sender isKindOfClass:[UITableViewCell class]] &&
            [segue.destinationViewController isKindOfClass:[EditTaskListElementViewController class]])
        {
            UITableViewCell *cell = sender;
            EditTaskListElementViewController *targetVC = segue.destinationViewController;
            
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            TaskListElement *taskListElement;
            
            if (indexPath.section == 0) {
                taskListElement = [self.unfinishedTaskListElements objectAtIndex:indexPath.row];
            }
            else {
                taskListElement = [self.finishedTaskListElements objectAtIndex:indexPath.row];
            }
            
            targetVC.taskListElement = taskListElement;
        }
    }
}

// Needs to be here for unwind segue...
- (IBAction)unwindToTaskListElements:(UIStoryboardSegue *)unwindSegue {
    [self refreshTaskListElements];
}

#pragma mark UIActionSheet Delegate Methods

//lets us know the behaviour of the actionsheet
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0: // Delete
            [self deleteTaskListDialog];
            break;
        case 1: // Rename
            [self renameTaskListDialog];
            break;
        case 2: // Toggle Finished
            [self toggleFinished];
            break;
        default:
            break;
    }
}

#pragma mark Helper Methods

- (void)deleteTaskListDialog {
    UIAlertView *deleteAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to delete this task list?", nil) message:@"" delegate:self cancelButtonTitle:NSLocalizedString(@"No", nil) otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
    deleteAlert.tag = 0;
    [deleteAlert show];
}

- (void)renameTaskListDialog {
    UIAlertView *renameAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Task List Name", nil) message:@"" delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"Change", nil), nil];
    [renameAlert setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [renameAlert textFieldAtIndex:0].text = self.taskList.listName;
    [renameAlert textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeSentences;
    renameAlert.tag = 1;
    [renameAlert show];
}

- (void)toggleFinished {
    self.taskList.done = !self.taskList.done;
    [self.taskList saveEventually:^(BOOL succeeded, NSError *error) {
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskListChanged" object:nil];
        } else {
            [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
        }
    }];
}

#pragma mark UIAlertView Delegate Methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0) { // delete
        if (buttonIndex == 1) {
            [SVProgressHUD showWithStatus:NSLocalizedString(@"Deleting Task List", nil) maskType:SVProgressHUDMaskTypeBlack];
            [self.taskList deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                [SVProgressHUD dismiss];
                if (!error) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskListChanged" object:nil];
                    [self.navigationController popViewControllerAnimated:YES];
                }
                else {
                    [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
                }
            }];
        }
    }
    else if (alertView.tag == 1) { // rename
        if (buttonIndex == 1) {
            NSString *newName = [alertView textFieldAtIndex:0].text;
            if ([newName isEqualToString:@""]) {
                [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"Name cannot be empty", nil)];
            }
            else {
                self.taskList.listName = newName;
                [self.taskList saveEventually:^(BOOL succeeded, NSError *error) {
                    if (!error) {
                        self.title = self.taskList.listName;
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"TaskListChanged" object:nil];
                    } else {
                        [SVProgressHUD showErrorWithStatus:error.userInfo[@"error"]];
                    }
                }];
            }
            
        }
    }
}

@end
