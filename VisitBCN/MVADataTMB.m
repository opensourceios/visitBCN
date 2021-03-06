//
//  MVADataBase.m
//  VisitBCN
//
//  Created by Mauro Vime Castillo on 04/09/14.
//  Copyright (c) 2014 Mauro Vime Castillo. All rights reserved.
//

#import "MVADataTMB.h"

@interface MVADataTMB () <SSZipArchiveDelegate,CHCSVParserDelegate>

@property MVAStop *parada;
@property MVACalendar *calendarTMB;
@property MVARoute *route;
@property MVATrip *trip;
@property MVADate *date;
@property MVATime *time;
@property MVAFrequencies *freq;
@property NSString *filePath;
@property NSString *outputPath;
@property NSString *docName;
@property int line;

@end

@implementation MVADataTMB

/**
 *  This function is overriden from NSObject. Returns self initialized
 *
 *  @return self, initialized object
 *
 *  @since version 1.0
 */
-(id)init
{
    self.stops = [[NSMutableArray alloc] init];
    self.stopsHash  = [[NSMutableDictionary alloc] init];
    self.calendars = [[NSMutableArray alloc] init];
    self.routes = [[NSMutableArray alloc] init];
    self.trips = [[NSMutableArray alloc] init];
    self.dates = [[NSMutableArray alloc] init];
    self.tripsHash  = [[NSMutableDictionary alloc] init];
    self.routesHash  = [[NSMutableDictionary alloc] init];
    self.freqs = [[NSMutableArray alloc] init];
    
    return self;
}

-(void)parseDataBase
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"TMB-GTFS" ofType:@"zip"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (data) {
        NSString *fileName = @"TMB-GTFS.zip";
        self.filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        [data writeToFile:self.filePath atomically:YES];
        [self unZip:self.filePath at:@"/TMB_GTFS_ZIP"];
        self.outputPath = [self.outputPath stringByAppendingString:@"/TMB"];
        [self parseGTFSAtPath:self.outputPath];
    }
}

/**
 *  Function that extracts the ziped folder
 *
 *  @param filePath The path of the zip file
 *  @param folder   The name of the folder where the extracted data should be stored
 *
 *  @since version 1.0
 */
-(void)unZip:(NSString *)filePath at:(NSString *)folder
{
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.outputPath = [documentsDirectory stringByAppendingPathComponent:folder];
    [SSZipArchive unzipFileAtPath:filePath toDestination:self.outputPath delegate:self];
}

/**
 *  This function parses the files at a given path
 *
 *  @param filesPath The path of the files that need to be parsed
 *
 *  @since version 1.0
 */
-(void)parseGTFSAtPath:(NSString *)filesPath
{
    NSError *error = nil;
    NSArray *filePathsArray = @[@"routes.txt",@"trips.txt",@"stops.txt",@"stop_times.txt",@"calendar.txt",@"calendar_dates.txt",@"frequencies.txt"];
    if (!error) {
        // PARSEAR TODOS LOS ARCHIVOS -- QUITAR SHAPES
        MVACustomModifications *modi = [[MVACustomModifications alloc] init];
        double total = 0;
        for(int i = 0; i < [filePathsArray count]; ++i) {
            NSString *doc = [filePathsArray objectAtIndex:i];
            if (![modi.documentExceptions containsObject:doc]) {
                NSString *filePath = [filesPath stringByAppendingString:[@"/" stringByAppendingString:doc]];
                NSStringEncoding encoding = 0;
                NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:filePath];
                CHCSVParser * p = [[CHCSVParser alloc] initWithInputStream:stream usedEncoding:&encoding delimiter:','];
                [p setRecognizesBackslashesAsEscapes:YES];
                [p setSanitizesFields:YES];
                [p setDelegate:self];
                self.docName = (NSString *)[filePathsArray objectAtIndex:i];
                NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
                [p parse];
                NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
                double dif = (end-start);
                total += dif;
                //NSLog(@"iteration: %f", dif);
            }
        }
        NSLog(@"total difference: %.16f", total);
        //long falta = EXPECTED_TIME_TMB - total;
        //if (falta > 0) sleep(falta);
    }
}

#pragma mark - parser methods

/**
 *  CHCSVParserDelegate method. Indicates when the parser has begun a new document
 *
 *  @param parser A CHCSVParser object
 *
 *  @since version 1.0
 */
- (void)parserDidBeginDocument:(CHCSVParser *)parser
{
    self.line = 0;
}

/**
 *  CHCSVParserDelegate method. Indicates when the parser has begun a new line of the document
 *
 *  @param parser       A CHCSVParser object
 *  @param recordNumber The number of the line being parsed
 *
 *  @since version 1.0
 */
- (void)parser:(CHCSVParser *)parser didBeginLine:(NSUInteger)recordNumber
{
    if ([self.docName isEqualToString:@"stops.txt"]) self.parada = [[MVAStop alloc] init];
    else if ([self.docName isEqualToString:@"calendar.txt"]) self.calendarTMB = [[MVACalendar alloc] init];
    else if ([self.docName isEqualToString:@"routes.txt"]) self.route = [[MVARoute alloc] init];
    else if ([self.docName isEqualToString:@"trips.txt"]) self.trip = [[MVATrip alloc] init];
    else if ([self.docName isEqualToString:@"calendar_dates.txt"]) self.date = [[MVADate alloc] init];
    else if ([self.docName isEqualToString:@"stop_times.txt"]) self.time = [[MVATime alloc] init];
    else if ([self.docName isEqualToString:@"frequencies.txt"]) self.freq = [[MVAFrequencies alloc] init];
}

/**
 *  CHCSVParserDelegate method. Indicates when the parser has read a new field of the current line
 *
 *  @param parser     A CHCSVParser object
 *  @param field      The field that has been read
 *  @param fieldIndex The index of this field in the line
 *
 *  @since version 1.0
 */
- (void)parser:(CHCSVParser *)parser didReadField:(NSString *)field atIndex:(NSInteger)fieldIndex
{
    if ([self.docName isEqualToString:@"stops.txt"]) {
        if (self.line > 0) [self.parada insertElement:field atIndex:fieldIndex isFGC:NO];
    }
    else if ([self.docName isEqualToString:@"calendar.txt"]) {
        if (self.line > 0) [self.calendarTMB insertElement:field atIndex:fieldIndex];
    }
    else if ([self.docName isEqualToString:@"routes.txt"]) {
        if (self.line > 0) [self.route insertElement:field atIndex:fieldIndex isFGC:NO];
    }
    else if ([self.docName isEqualToString:@"trips.txt"]) {
        if (self.line > 0) [self.trip insertElement:field atIndex:fieldIndex isFGC:NO];
    }
    else if ([self.docName isEqualToString:@"calendar_dates.txt"]) {
        if (self.line > 0) [self.date insertElement:field atIndex:fieldIndex];
    }
    else if ([self.docName isEqualToString:@"stop_times.txt"]) {
        if (self.line > 0) [self.time insertElement:field atIndex:fieldIndex];
    }
    else if ([self.docName isEqualToString:@"frequencies.txt"]) {
        if (self.line > 0) [self.freq insertElement:field atIndex:fieldIndex];
    }
}

/**
 *  CHCSVParserDelegate method. Indicates when the aprser has finished reading a line
 *
 *  @param parser       A CHCSVParser object
 *  @param recordNumber The number of the line dad has been parsed
 *
 *  @since version 1.0
 */
- (void)parser:(CHCSVParser *)parser didEndLine:(NSUInteger)recordNumber
{
    if ([self.docName isEqualToString:@"stops.txt"]) {
        if (self.line > 0) {
            if ([self.parada.stopID hasPrefix:@"001"]) {
                [self.stopsHash setObject:[NSNumber numberWithInt:(int)[self.stops count]]
                                    forKey:self.parada.stopID];
                [self.stops addObject:self.parada];
            }
        }
        self.parada = nil;
    }
    else if ([self.docName isEqualToString:@"calendar.txt"]) {
        if (self.line > 0) [self.calendars addObject:self.calendarTMB];
        self.calendarTMB = nil;
    }
    else if ([self.docName isEqualToString:@"routes.txt"]) {
        if (self.line > 0) {
            if (self.route.type == 1) {
                [self.routesHash setObject:[NSNumber numberWithInteger:[self.routes count]]
                                          forKey:self.route.routeID];
                [self.routes addObject:self.route];
            }
        }
        self.route = nil;
    }
    else if ([self.docName isEqualToString:@"trips.txt"]) {
        if (self.line > 0) {
            if ([self.routesHash objectForKey:self.trip.routeID] != nil) {
                NSNumber *num = [self.routesHash objectForKey:self.trip.routeID];
                MVARoute *route = [self.routes objectAtIndex:[num intValue]];
                if (route.trips == nil) route.trips = [[NSMutableArray alloc] init];
                [route.trips addObject:self.trip.tripID];
                
                [self.tripsHash setObject:[NSNumber numberWithInteger:[self.trips count]] forKey:self.trip.tripID];
                [self.trips addObject:self.trip];
            }
            else {
                //NSLog(@"NO QUEREMOS ESTE TRIP");
            }
        }
        self.trip = nil;
    }
    else if ([self.docName isEqualToString:@"calendar_dates.txt"]) {
        if (self.line > 0) {
            [self.dates addObject:self.date];
        }
        self.date = nil;
    }
    else if ([self.docName isEqualToString:@"stop_times.txt"]) {
        if (self.line > 0) {
            NSNumber *num = [self.tripsHash objectForKey:self.time.tripID];
            if (num != nil) {
                MVATrip *trip = [self.trips objectAtIndex:[num intValue]];
                if (trip.sequence == nil) trip.sequence = [[NSMutableArray alloc] init];
                [trip.sequence addObject:self.time.stopID];
                
                if ([self.time.stopID hasPrefix:@"001"]) {
                    [self.time insertInMetro:self.stops isFGC:NO andHash:self.stopsHash andRoute:trip.routeID];
                }
                
            }
            else {
                //NSLog(@"NO QUEREMOS ESTE TIME");
            }
            
        }
        self.time = nil;
    }
    else if ([self.docName isEqualToString:@"frequencies.txt"]) {
        if (self.line > 0) {
            NSNumber *num = [self.tripsHash objectForKey:self.freq.tripID];
            if (num != nil) {
                MVATrip *trip = [self.trips objectAtIndex:[num intValue]];
                if (trip.freqs == nil) trip.freqs = [[NSMutableArray alloc] init];
                [trip.freqs addObject:[NSNumber numberWithInt:(self.line - 1)]];
                [self.freqs addObject:self.freq];
            }
            else {
                //NSLog(@"NO QUEREMOS ESTE TIME");
            }
        }
        self.freq = nil;
    }
    ++self.line;
    //NSLog(@"Line: %d",self.line);
}

/**
 *  CHCSVParserDelegate method. Indicates when the parser has finished parsing a document
 *
 *  @param parser A CHCSVParser object
 *
 *  @since version 1.0
 */
- (void)parserDidEndDocument:(CHCSVParser *)parser
{
    // AÑADIR OBJETO A RECIPIENTE
}

/**
 *  CHCSVParserDelegate method. Indicates that an error ocurred while parsing the document
 *
 *  @param parser A CHCSVParser object
 *  @param error  The NSError indicating why the parsing ahs failed
 *
 *  @since version 1.0
 */
- (void)parser:(CHCSVParser *)parser didFailWithError:(NSError *)error
{
	NSLog(@"ERROR: %@", [error localizedDescription]);
}

#pragma mark - Consulting functions

-(MVACalendar *)getNextCalendarforSubway:(BOOL)subway
{
    
    int daysToAdd = 1;
    NSDate *newDate1 = [[self loadCustomDate] dateByAddingTimeInterval:60*60*24*daysToAdd];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    NSString *anomesdia = [dateFormatter stringFromDate:newDate1];
    BOOL para = NO;
    for(int i = 0; i < [self.dates count] && !para; ++i) {
        MVADate *date = [self.dates objectAtIndex:i];
        if (date.date == [anomesdia intValue] && date.type == 1) {
            for (int j = 0; j < [self.calendars count]; ++j) {
                MVACalendar *cal = [self.calendars objectAtIndex:j];
                if ([cal.serviceID isEqualToString:date.serviceID]) {
                    if (subway && [cal.serviceID hasPrefix:@"001"]) return cal;
                    else if (!subway && [cal.serviceID hasPrefix:@"002"]) return cal;
                }
            }
        }
    }
    
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Madrid"]];
    long day = [self dayOfWeek:newDate1];
    for (int i = 0; i < [self.calendars count]; ++i) {
        MVACalendar *cal = [self.calendars objectAtIndex:i];
        NSString *is = [cal.days objectAtIndex:day];
        if ([is isEqualToString:@"1"]){
            if (subway && [cal.serviceID hasPrefix:@"001"]) return cal;
            else if (!subway && [cal.serviceID hasPrefix:@"002"]) return cal;
        }
    }
    return nil;
}

-(MVACalendar *)getCurrentCalendarforSubway:(BOOL)subway
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    NSString *anomesdia = [dateFormatter stringFromDate:[self loadCustomDate]];
    BOOL para = NO;
    for(int i = 0; i < [self.dates count] && !para; ++i) {
        MVADate *date = [self.dates objectAtIndex:i];
        if (date.date == [anomesdia intValue] && date.type == 1) {
            for (int j = 0; j < [self.calendars count]; ++j) {
                MVACalendar *cal = [self.calendars objectAtIndex:j];
                if ([cal.serviceID isEqualToString:date.serviceID]) {
                    if (subway && [cal.serviceID hasPrefix:@"001"]) return cal;
                    else if (!subway && [cal.serviceID hasPrefix:@"002"]) return cal;
                }
            }
        }
    }
    
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Madrid"]];
    long day = [self dayOfWeek:[self loadCustomDate]];
    for (int i = 0; i < [self.calendars count]; ++i) {
        MVACalendar *cal = [self.calendars objectAtIndex:i];
        NSString *is = [cal.days objectAtIndex:day];
        if ([is isEqualToString:@"1"]){
            if (subway && [cal.serviceID hasPrefix:@"001"]) return cal;
            else if (!subway && [cal.serviceID hasPrefix:@"002"]) return cal;
        }
    }
    return nil;
}

/**
 *  Returns the day of the week for a given date
 *
 *  @param anyDate A NSDate object
 *
 *  @return The day of the week in European mode
 *
 *  @since version 1.0
 */
-(long)dayOfWeek:(NSDate *)anyDate
{
    NSLocale *frLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"es_ES"];
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [gregorian setLocale:frLocale];
    NSDateComponents *comps = [gregorian components:NSWeekdayCalendarUnit fromDate:anyDate];
    int weekday = (int)[comps weekday];
    int europeanWeekday = ((weekday + 5) % 7) + 1;
    return (europeanWeekday - 1);
}

/**
 *  Loads if the user whants a custom date or the actual
 *
 *  @return A BOOL indicating if the date is custom or not
 */
-(BOOL)customDate
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.visitBCN.com"];
    NSData *data = [defaults objectForKey:@"VisitBCNCustomDateEnabled"];
    if (data == nil) {
        [defaults setObject:@"NO" forKey:@"VisitBCNCustomDateEnabled"];
        return NO;
    }
    NSString *string = [defaults objectForKey:@"VisitBCNCustomDateEnabled"];
    if ([string isEqualToString:@"NO"]) return NO;
    return YES;
}

/**
 *  Loads the MVADate that user desires (the actual or a custom)
 *
 *  @return A NSDate object
 */
-(NSDate *)loadCustomDate
{
    [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Madrid"]];
    if (![self customDate]) return [NSDate date];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.visitBCN.com"];
    NSDate *date = [defaults objectForKey:@"VisitBCNCustomDate"];
    if (!date) return [NSDate date];
    return date;
}

#pragma mark - Saving/Loading functions

/**
 *  Encodes the receiver using a given archiver. (required)
 *
 *  @param coder An archiver object
 *
 *  @since version 1.0
 */
- (void)encodeWithCoder:(NSCoder *)coder;
{
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.stops] forKey:@"subwayStops"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.stopsHash] forKey:@"subwayHash"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.calendars] forKey:@"tmbCalendars"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.routes] forKey:@"subRoutes"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.routesHash] forKey:@"subRoutesHash"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.trips] forKey:@"trips"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.tripsHash] forKey:@"tripsHash"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.freqs] forKey:@"freqs"];
    [coder encodeObject:(NSData *)[NSKeyedArchiver archivedDataWithRootObject:self.dates] forKey:@"tmbDates"];
}

/**
 *  Returns an object initialized from data in a given unarchiver. (required)
 *
 *  @param coder An unarchiver object
 *
 *  @return self, initialized using the data in decoder.
 *
 *  @since version 1.0
 */
- (id)initWithCoder:(NSCoder *)coder;
{
    self = [[MVADataTMB alloc] init];
    if (self != nil) {
        self.stops = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"subwayStops"]] mutableCopy];
        self.stopsHash = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"subwayHash"]] mutableCopy];
        self.calendars = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"tmbCalendars"]] mutableCopy];
        self.routes = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"subRoutes"]] mutableCopy];
        self.routesHash = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"subRoutesHash"]] mutableCopy];
        self.trips = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"trips"]] mutableCopy];
        self.tripsHash = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"tripsHash"]] mutableCopy];
        self.freqs = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"freqs"]] mutableCopy];
        self.dates = [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)[coder decodeObjectForKey:@"tmbDates"]] mutableCopy];
    }
    return self;
}

@end