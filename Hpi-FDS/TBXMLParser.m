//
//  TBXMLParser.m
//  Hpi-FDS
//  采用TBXML方式解析，经测试，解析速度是NSXMLParser的3-4倍
//  Created by 馬文培 on 12-8-15.
//  Copyright (c) 2012年 Landscape. All rights reserved.
//

#import "TBXMLParser.h"
#import <objc/runtime.h>


@implementation TBXMLParser
@synthesize Identification=_Identification;

static int iSoapDone=1; //1未开始 0进行中 3出错
static int iSoapNum=0;
static NSString *version = @"V1.2";
static sqlite3  *database;
UIAlertView *alert;
NSString* alertMsg;
static bool ThreadFinished=TRUE;

- (void)requestSOAP:(NSString *)identification
{
    //由于NSURLConnection是异步方式，加入对当前RunLoop的控制，等待其他进程完成解析后再进行下一个请求的调用。
    while(!ThreadFinished) {
        //        NSLog(@"runloop");
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        
    }
    self.Identification=identification;
    //出错
    if (iSoapDone==3) {
        iSoapNum--;
        if (iSoapNum<1) {
            iSoapDone=1;
        }
        return;
    }
    iSoapDone=0;
    NSString *soapMessage = [NSString stringWithFormat:
                             @"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
                             "<soap12:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap12=\"http://www.w3.org/2003/05/soap-envelope\">\n"
                             "<soap12:Body>\n"
                             "<Get%@Info xmlns=\"http://tempuri.org/\">\n"
                             "<req>\n"
                             "<deviceid>%@</deviceid>\n"
                             "<version>%@</version>\n"
                             "<updatetime>%@</updatetime>\n"
                             "</req>\n"
                             "</Get%@Info>\n"
                             "</soap12:Body>\n"
                             "</soap12:Envelope>\n",_Identification,PubInfo.deviceID,version,PubInfo.currTime,_Identification];
    NSLog(@"soapMessage[%@]",soapMessage);
    NSString *msgLength = [NSString stringWithFormat:@"%d", [soapMessage length]];
    
    NSURL *url = [NSURL URLWithString:PubInfo.baseUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest addValue: @"application/soap+xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [urlRequest addValue: msgLength forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody: [soapMessage dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 请求
    NSURLConnection *theConnection = [[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self] autorelease];
    
    // 如果连接已经建好，则初始化data
    if( theConnection )
    {
        NSLog(@"yes connect");
        
        ThreadFinished=FALSE;
        webData = [[NSMutableData data] retain];
    }
    else
    {
        NSLog(@"theConnection is NULL");
    }
    NSLog(@"dddddddddddd");
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [webData setLength: 0];
    NSLog(@"connection: didReceiveResponse:1");
}
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [webData appendData:data];
    
}
-(void) msgbox
{
	alert = [[UIAlertView alloc]initWithTitle:@"提示" message:alertMsg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
    
	[NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(performDismiss:) userInfo:nil repeats:NO];
    
}
-(void) performDismiss:(NSTimer *)timer
{
    [alert dismissWithClickedButtonIndex:0 animated:YES];
    [alert release];
	alert =  nil;
}
//如果没有连接网络，则出现此信息（不是网络服务器不通）
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"--------------------------------------------ERROR with theConenction");
    //    [connection release];
    [webData release];
    iSoapDone=3;
    //    alertMsg = @"无法连接,请检查网络是否正常?";
    //    [self msgbox];
    //    if (iSoapNum==0) {
    //        iSoapDone=1;
    //    }
    //    iSoapNum=0;
    ThreadFinished = TRUE;
    
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"--------------------------------------------  connectionDidFinishLoading");
    
    [self parseXML];
    ThreadFinished = TRUE;
    //    [connection release];
    [webData release];
}
/*!
 @method parseXML
 @author 马文培
 @version 1.0
 @abstract TBXML方式解析，批量写入数据库
 @discussion 用法
 @param 参数说明
 @result 返回结果
 */
#pragma mark -参数：1，xml子节点【TfCoalType】  2，表的对应实体类 3，插入的表名

-(void)parseXML
{
    /***********************TfCoalType**********************/
    if ([_Identification isEqualToString:@"CoalType"]) {
        [TfCoalTypeDao deleteAll];
        [self getDate:@"TfCoalType" entityClass:@"TfCoalType" insertTableName:@"TfCoalType"];
    }
    
    /****************************实时船舶查询-VbShiptrans**************************/
    if ([_Identification isEqualToString:@"ShipTrans"]) {
        //先清空表  数据
        [VbShiptransDao deleteAll];
        //调用  解析
        [self getDate:@"VbShipTrans" entityClass:@"VbShiptrans" insertTableName:@"VbShiptrans"];
    }
    
    /****************************调度日志**************************/
    
    if ([_Identification isEqualToString:@"ThShipTrans"]) {
        [TH_ShipTransDao deleteAll];
        
        [self getDate:@"VbThShipTrans" entityClass:@"TH_ShipTrans" insertTableName:@"Th_ShipTrans"];
        
    }
    /****************************电厂动态查询-FactoryTrans**************************/
    if ([_Identification isEqualToString:@"FactoryTrans"]) {
        //全部删除
        [VbFactoryTransDao deleteAll];
        [self getDate:@"VbFactoryTrans" entityClass:@"VbFactoryTrans" insertTableName:@"VbFactoryTrans"];
    }
    /****************************电厂动态查询-FactoryState**************************/
    if ([_Identification isEqualToString:@"FactoryState"]) {
        //全部删除
        [TbFactoryStateDao deleteAll];
        [self getDate:@"TbFactoryState" entityClass:@"TbFactoryState" insertTableName:@"TbFactoryState"];
    }
    
    /***************************港口信息基础表  **tf_port****************************/
    if ([_Identification isEqualToString:@"Port"]) {
        //全部删除
        [TfPortDao deleteAll];
        [self getDate:@"TfPortInfo" entityClass:@"TfPort" insertTableName:@"TF_Port"];
    }
    /**************************电厂信息基础表******************************/
    if ([_Identification isEqualToString:@"Factory"]) {
        //全部删除
        [TfFactoryDao deleteAll];
        [self getDate:@"TfFactory" entityClass:@"TfFactory" insertTableName:@"TfFactory"];
    }
    /******************************滞期费*****************************/
    if ([_Identification isEqualToString:@"LateFee"]) {
        [TB_LatefeeDao deleteAll];
        [self getDate:@"VbLateFee" entityClass:@"TB_Latefee" insertTableName:@"TB_Latefee"];
    }
    /****************************航运公司份额统计-NTShipCompanyTranShare**************************/
    if ([_Identification isEqualToString:@"TransPorts"]) {
        //全部删除
        [NTShipCompanyTranShareDao deleteAll];
        [self getDate:@"VbTransPorts" entityClass:@"NTShipCompanyTranShare" insertTableName:@"NTShipCompanyTranShare"];
    }
    /****************************电厂运力运量统计-NTFactoryFreightVolume**************************/
    if ([_Identification isEqualToString:@"YunLi"]) {
        
        //全部删除
        [NTFactoryFreightVolumeDao deleteAll];
        [self getDate:@"YunLi" entityClass:@"NTFactoryFreightVolume" insertTableName:@"NTFactoryFreightVolume"];
    }
    /****************************航运计划-vbTransplan**************************/
    if ([_Identification isEqualToString:@"TransPlan"]) {
        //全部删除
        [VbTransplanDao deleteAll];
        
        [self getDate:@"VbTransPlan" entityClass:@"VbTransplan" insertTableName:@"VbTransplan"];
        
    }
    /****************************市场指数-TmIndexinfo**************************/
    if ([_Identification isEqualToString:@"TmIndex"]) {
        //全部删除
        [TmIndexinfoDao deleteAll];
        [self getDate:@"TmIndexInfo" entityClass:@"TmIndexinfo" insertTableName:@"TmIndexinfo"];
        
    }
    /****************************港口信息-TmCoalinfo**************************/
    if ([_Identification isEqualToString:@"Coal"]) {
        //全部删除
        [TmCoalinfoDao deleteAll];
        [self getDate:@"TmCoalInfo" entityClass:@"TmCoalinfo" insertTableName:@"TmCoalinfo"];
    }
    /***********************船舶信息*****-ShipInfo**************************/
    if ([_Identification isEqualToString:@"Ship"]) {
        
        //全部删除
        [TmShipinfoDao deleteAll];
        [self getDate:@"TmShipInfo" entityClass:@"TmShipinfo" insertTableName:@"TmShipinfo"];
        
    }
    /***********************纪要查看*****-TsFileinfo**************************/
//    if ([_Identification isEqualToString:@"TsFile"]) {
//        
//        //全部删除
//        [TsFileinfoDao deleteAll];
//        [self getDate:@"TsFileinfo" entityClass:@"TsFileinfo" insertTableName:@"TsFileinfo"];
//        
//    }
    
}
#pragma mark -参数：1，xml子节点【TfCoalType】  2，表的对应实体类 3，插入的表名
-(void)getDate :(NSString *)element1  entityClass:(NSString *)className    insertTableName:(NSString *)tableName
{
    NSString *elementString1= [NSString stringWithFormat:@"Get%@InfoResult",_Identification];
    NSString *elementString2= [NSString stringWithFormat:@"Get%@InfoResponse",_Identification];
    
    char *errorMsg;
    NSLog(@"start Parser");
    NSError *error = nil;
    tbxml = [TBXML newTBXMLWithXMLData:webData error:&error];
    
    if (error) {
        NSLog(@"Error! %@ %@", [error localizedDescription], [error userInfo]);
        
    } else {
        TBXMLElement * root = tbxml.rootXMLElement;
        //=======================================
        if (root) {
            TBXMLElement *elementNoUsed = [TBXML childElementNamed:@"retinfo" parentElement:[TBXML childElementNamed:elementString1 parentElement:[TBXML childElementNamed:elementString2 parentElement:[TBXML childElementNamed:@"soap:Body" parentElement:root]]]];
            //[_Identification compare:Identification options:NSCaseInsensitiveSearch]
            TBXMLElement *element = [TBXML childElementNamed:element1 parentElement:elementNoUsed];
            
            //打开数据库
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *file= [documentsDirectory stringByAppendingPathComponent:@"database.db"];
            
            if(sqlite3_open([file UTF8String],&database)!=SQLITE_OK)
            {
                sqlite3_close(database);
                NSLog(@"open  database error");
                return;
            }else
            {
                NSLog(@"open  database ");
                
            }
            //为提高数据库写入性能，加入事务控制，批量提交
            if (sqlite3_exec(database, "BEGIN;", 0, 0, &errorMsg)!=SQLITE_OK) {
                sqlite3_close(database);
                NSLog(@"exec begin error");
                return;
            }
            //动态调用某个类的方法
            
            sqlite3_stmt *statement;
            id LenderClass = objc_getClass([className UTF8String]);//要不要释放
            NSUInteger outCount;
            objc_property_t *properties = class_copyPropertyList(LenderClass, &outCount);
            NSString *columName=@" ";
            NSString *columValue=@" ";
            if (_Identification==@"FactoryTrans") {
                outCount=16;
            }
            if (_Identification==@"CoalType") {
                outCount=5;
                
            }
            if(_Identification==@"TransPorts"){
                outCount=7;
                
            }
            if(_Identification==@"YunLi"){
                
                outCount=6;
            }
            
            
            
            for (int i = 0; i < outCount; i++) {
                objc_property_t property = properties[i];
                NSString *propertyName=[[NSString alloc] initWithFormat:@"%s",property_getName(property)];
                columName=[columName stringByAppendingFormat:@"%@,",propertyName];//多一个
                
                columValue=[columValue stringByAppendingFormat:@"%@",@"?,"];//多一个
                
                NSLog(@"%@",propertyName);
                
                
                [propertyName release];
            }
            columName=[columName substringWithRange:NSMakeRange(0,[columName length]-1)];
            columValue=[columValue substringWithRange:NSMakeRange(0,[columValue length]-1)];
            
            TBXMLElement * desc;
            NSString *sql=[NSString stringWithFormat:@"INSERT INTO %@ (%@) values(%@)",tableName,columName,columValue];
            
            
            NSLog(@"==============sql[%@]",sql);
            
            
            
            while (element != nil) {
                int re =sqlite3_prepare(database, [sql UTF8String], -1, &statement, NULL);
                if (re!=SQLITE_OK) {
                    NSLog(@"Error: failed to prepare statement with message [%s]  sql[%s]",sqlite3_errmsg(database),[sql UTF8String]);
                }
                for (int i = 0; i < outCount; i++) {
                    // objc_property_t property = *properties++;
                    objc_property_t property = properties[i];
                    NSString *propertyName=[[NSString alloc] initWithFormat:@"%s",property_getName(property)];
                    NSString *type=[[NSString    alloc] initWithFormat:@"%s",property_getAttributes(property)];
                    desc = [TBXML childElementNamed:[propertyName uppercaseString] parentElement:element];
                    if (desc != nil) {
                        if ([type rangeOfString:@"NSString"].length!=0) {
                            sqlite3_bind_text(statement, i+1, [[TBXML textForElement:desc] UTF8String], -1, SQLITE_TRANSIENT);
                            //                                NSLog(@"1 %@+%s",propertyName,[[TBXML textForElement:desc] UTF8String]);
                        }else{
                            sqlite3_bind_int(statement, i+1,[[TBXML textForElement:desc] integerValue]);
                            //                                NSLog(@"2 %@+%d",propertyName,[[TBXML textForElement:desc] integerValue]);
                            
                        }
                    }
                    [propertyName release];
                    [type release];
                }
                re=sqlite3_step(statement);
                if (re!=SQLITE_DONE) {
                    NSLog( @"Error: insert   error with message [%s]  sql[%s]", sqlite3_errmsg(database),[sql UTF8String]);
                    sqlite3_finalize(statement);
                    return;
                }else {
                    // NSLog(@"insert shipTrans  SUCCESS");
                }
                sqlite3_finalize(statement);
                //element1   :TfCoalType
                
                element = [TBXML nextSiblingNamed:element1 searchFromElement:element];
            }
            
            if (sqlite3_exec(database, "COMMIT;", 0, 0, &errorMsg)!=SQLITE_OK) {
                sqlite3_close(database);
                NSLog(@"exec commit error");
                return;
            }
            sqlite3_close(database);
            NSLog(@"-----------%@-----------commit over  ",_Identification);
            iSoapDone=1;
            iSoapNum--;
        }
        //}
        //====================================
        
    }
}



-(NSInteger)iSoapDone
{
    return iSoapDone;
}
-(NSInteger)iSoapNum
{
    return iSoapNum;
}
-(void)setISoapNum:(NSInteger)theNum
{
    iSoapNum=theNum;
}
@end
