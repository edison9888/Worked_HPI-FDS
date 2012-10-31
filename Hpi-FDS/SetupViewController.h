//
//  SetupViewController.h
//  Hpi-FDS
//
//  Created by zcx on 12-4-9.
//  Copyright (c) 2012年 Landscape. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMLParser.h"
#import "PubInfo.h"
@interface SetupViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>{
    IBOutlet UITableView *tableView;
    XMLParser *xmlParser;
    UIActivityIndicatorView *activity;
}

@property(nonatomic,retain) UITableView *tableView;
@property(nonatomic,retain) XMLParser *xmlParser;
@property(nonatomic,retain) UIActivityIndicatorView *activity;
@end
