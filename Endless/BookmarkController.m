/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "Bookmark.h"
#import "BookmarkController.h"

@implementation BookmarkController

UIBarButtonItem *addItem;
UIBarButtonItem *leftItem;
BOOL isRTL;

- (void)viewDidLoad
{
	[super viewDidLoad];
	isRTL = ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft);
	
	self.title = NSLocalizedString(@"Bookmarks", @"Bookmarks main dialog title");
	self.navigationItem.rightBarButtonItem = addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
	self.navigationItem.leftBarButtonItem = leftItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Bookmarks dialog 'Done' button title, dismisses the dialog")
                                                                                        style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	
	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
	lpgr.minimumPressDuration = 0.75f;
	lpgr.delegate = self;
	[[self tableView] addGestureRecognizer:lpgr];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[Bookmark persistList];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[Bookmark list] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (self.embedded)
		return NSLocalizedString(@"Bookmarks", @"Bookmarks table header title");
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
	if (self.embedded && [view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
		int buttonSize = tableViewHeaderFooterView.frame.size.height - 8;
		
		UIButton *b = [[UIButton alloc] init];
		CGRect frame;
		if(isRTL) {
			frame = CGRectMake(buttonSize + 6, 3, buttonSize, buttonSize);
		} else {
			frame = CGRectMake(tableViewHeaderFooterView.frame.size.width - buttonSize - 6, 3, buttonSize, buttonSize);
		}
		[b setFrame:frame];
		[b setBackgroundColor:[UIColor lightGrayColor]];
		[b setTitle:@"X" forState:UIControlStateNormal];
		[[b titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
		[[b layer] setCornerRadius:buttonSize / 2];
		[b setClipsToBounds:YES];
		
		[b addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
		
		[tableViewHeaderFooterView addSubview:b];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bookmark"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"boomark"];

	Bookmark *b = [[Bookmark list] objectAtIndex:indexPath.row];
	if (b != nil) {
		cell.textLabel.text = b.name;
		cell.detailTextLabel.text = b.urlString;
	}
	
	[cell setShowsReorderControl:YES];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Bookmark *bookmark = [Bookmark list][[indexPath row]];
	
	if (self.embedded)
		[[[AppDelegate sharedAppDelegate] webViewController] prepareForNewURLFromString:[bookmark urlString]];
	else {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit Bookmark", @"Edit Bookmark dialog title")
                                                                                 message:NSLocalizedString(@"Enter the details of the URL to bookmark:", @"Edit Bookmark dialog title text")
                                                                          preferredStyle:UIAlertControllerStyleAlert];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = NSLocalizedString(@"URL", @"'Edit Bookmark' dialog URL field");
			textField.text = bookmark.urlString;
		}];
		[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.placeholder = NSLocalizedString(@"Page Name (leave blank to use URL)", @"'Edit Bookmark' dialog page name field");
			textField.text = bookmark.name;
		}];
		
		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			UITextField *url = alertController.textFields[0];
			bookmark.urlString = [url text];
			
			UITextField *name = alertController.textFields[1];
			bookmark.name = [name text];
			
			[self.tableView reloadData];
		}];
		
		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:cancelAction];
		[alertController addAction:okAction];
		
		[self presentViewController:alertController animated:YES completion:nil];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[[Bookmark list] removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
	Bookmark *s = [Bookmark list][[sourceIndexPath row]];
	[[Bookmark list] removeObjectAtIndex:[sourceIndexPath row]];
	[[Bookmark list] insertObject:s atIndex:[destinationIndexPath row]];
}

- (void)addItem:sender
{
	UIAlertController *uiac = [Bookmark addBookmarkDialogWithOkCallback:^{
		[self.tableView reloadData];
	}];
	
	[self presentViewController:uiac animated:YES completion:nil];
}

- (void)didLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
	CGPoint p = [gestureRecognizer locationInView:[self tableView]];
	
	NSIndexPath *indexPath = [[self tableView] indexPathForRowAtPoint:p];
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan && indexPath != nil) {
		[[self tableView] setEditing:YES animated:YES];
		
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditing:)];
		self.navigationItem.leftBarButtonItem = nil;
	}
}
	
- (void)doneEditing:sender
{
	[[self tableView] setEditing:NO animated:YES];
	self.navigationItem.rightBarButtonItem = addItem;
	self.navigationItem.leftBarButtonItem = leftItem;
}

- (void)close
{
	[self removeFromParentViewController];
	[[self view] removeFromSuperview];
}

@end
