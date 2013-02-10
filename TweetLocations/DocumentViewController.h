//
//  DocumentViewController.h
//  PasteParse
//
//  Created by Curtis Sieber on 10/7/12.
//  Copyright (c) 2012 Curtis Sieber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TWLocDetailViewController.h"

@interface DocumentCell : UITableViewCell

@end

@interface DocumentViewController : UITableViewController
        <UITableViewDataSource, UITableViewDelegate,
            UIDocumentInteractionControllerDelegate, UIAlertViewDelegate> {
                NSArray* theData;
                NSArray* filesizes;
                UIDocumentInteractionController* docCtrl;
}

@property (nonatomic, retain) TWLocDetailViewController* detailView;
@property (nonatomic, retain) NSArray* theData;
@property (nonatomic, retain) NSArray* filesizes;
@property (nonatomic, retain) IBOutlet UIButton* doneButton;

- (IBAction)doDone:(id)sender;

@end
