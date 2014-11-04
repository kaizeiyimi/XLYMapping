//
//  MangedObjectTableViewController.m
//  XLYMappingDemo
//
//  Created by 王凯 on 14/11/3.
//  Copyright (c) 2014年 kaizei. All rights reserved.
//

#import "MangedObjectTableViewController.h"

#import "Student.h"
#import "Teacher.h"

@interface MangedObjectTableViewController ()

@property (nonatomic, strong) NSArray *scores;
@property (nonatomic, strong) NSManagedObjectContext *context;

@end

@implementation MangedObjectTableViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"]];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSString *dbFile = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"model.db"];
    [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:nil
                                        URL:[NSURL fileURLWithPath:dbFile]
                                    options:nil
                                      error:nil];
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [context setPersistentStoreCoordinator:coordinator];
    [context setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
    self.context = context;
}

- (void)loadView
{
    [super loadView];
    self.refreshControl = [UIRefreshControl new];
    self.refreshControl.tintColor = [UIColor orangeColor];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self reloadModels];
}

- (void)refresh:(id)sender
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"Scores" withExtension:@"json"]];
            id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            [[Teacher defaultMappingInManagedObjectContext:strongSelf.context] performAsyncMappingWithJSONObject:JSONObject completion:^(id result, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf.context save:nil];
                    [strongSelf reloadModels];
                    [strongSelf.refreshControl endRefreshing];
                });
            }];
        }
    });
}

- (void)reloadModels
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Teacher"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"identity" ascending:YES]];
    NSArray *result = [self.context executeFetchRequest:request error:nil];
    self.scores = result;
    NSLog(@"%@", self.scores);
    [self.tableView reloadData];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.scores.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    Teacher *teacher = self.scores[section];
    return teacher.students.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    Student *student = [[[[self.scores[indexPath.section] students] allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO]]] objectAtIndex:indexPath.row];
    cell.textLabel.text = student.name;
    cell.detailTextLabel.text = [@(student.score) stringValue];
    return cell;
}

@end
