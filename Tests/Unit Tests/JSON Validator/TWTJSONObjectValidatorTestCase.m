//
//  TWTJSONObjectValidatorTestCase.m
//  TWTValidation
//
//  Created by Jill Cohen on 1/16/15.
//  Copyright (c) 2015 Ticketmaster. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "TWTRandomizedTestCase.h"

#import "TWTJSONSchemaTestDirectories.h"


static NSString *const TWTTestKeywordSchema = @"schema";
static NSString *const TWTTestKeywordDescription = @"description";
static NSString *const TWTTestKeywordData = @"data";
static NSString *const TWTTestKeywordTests = @"tests";
static NSString *const TWTTestKeywordValid = @"valid";


@interface TWTJSONObjectValidatorTestCase : TWTRandomizedTestCase

@end


@implementation TWTJSONObjectValidatorTestCase

- (void)testSuite
{
    NSString *directoryPath = TWTPathForDraft4TestSuite();

    for (NSDictionary *test in [self testsInDirectory:directoryPath]) {
        if ([[self failingTests] containsObject:test[TWTTestKeywordDescription]]) {
            continue;
        }

        TWTJSONObjectValidator *validator = [TWTJSONObjectValidator validatorWithJSONSchema:test[TWTTestKeywordSchema] error:nil warnings:nil];
        XCTAssertNotNil(validator, @"validator is nil from schema: %@", test[TWTTestKeywordSchema]);

        for (NSDictionary *testValue in test[TWTTestKeywordTests]) {
            if ([[self failingTestDescriptions] containsObject:testValue[TWTTestKeywordDescription]]) {
                continue;
            }

            NSError *error = nil;
            BOOL shouldPass = [testValue[TWTTestKeywordValid] boolValue];
            XCTAssertTrue([validator validateValue:testValue[TWTTestKeywordData] error:&error] == shouldPass,
                          @"\nValue: %@\nSchema: %@\nshould have %@ed because %@. (%@)",
                          testValue[TWTTestKeywordData], test[TWTTestKeywordSchema], shouldPass ? @"pass" : @"fail",
                          testValue[TWTTestKeywordDescription], test[TWTTestKeywordDescription]);

            if (!shouldPass) {
                XCTAssertNotNil(error, @"error was not set for a failing value");
            } else {
                XCTAssertNil(error, @"error is non-nil for a passing value");
            }
        }
    }
}


- (void)testCustom
{
    NSString *directoryPath = TWTPathForCustomJSONSchemaTests();

    for (NSDictionary *test in [self testsInDirectory:directoryPath replaceCustom:YES]) {
        TWTJSONObjectValidator *validator = [TWTJSONObjectValidator validatorWithJSONSchema:test[TWTTestKeywordSchema] error:nil warnings:nil];

        for (NSDictionary *testValue in test[TWTTestKeywordTests]) {
            NSError *error = nil;
            BOOL shouldPass = [testValue[TWTTestKeywordValid] boolValue];
            XCTAssertTrue([validator validateValue:testValue[TWTTestKeywordData] error:&error] == shouldPass, @"\nValue: %@\nSchema: %@\nshould have %@ed because %@. (%@)",
                          testValue[TWTTestKeywordData], test[TWTTestKeywordSchema], shouldPass ? @"pass" : @"fail", testValue[TWTTestKeywordDescription], test[TWTTestKeywordDescription]);

            if (!shouldPass) {
                XCTAssertNotNil(error, @"error was not set for a failing value");
            } else {
                XCTAssertNil(error, @"error is non-nil for a passing value");
            }
        }
    }
}


- (void)testDraft4
{
    NSData *data =[NSData dataWithContentsOfFile:[[NSBundle bundleForClass:[TWTJSONObjectValidator class]] pathForResource:@"JSONSchemaDraft4" ofType:@"json"]];
    NSDictionary *draft4 = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    TWTJSONObjectValidator *validator = [TWTJSONObjectValidator validatorWithJSONSchema:draft4 error:nil warnings:nil];
    XCTAssertNotNil(validator, @"validator is nil from draft 4 schema");

    XCTAssertTrue([validator validateValue:draft4 error:nil]);
}


- (NSArray *)testsInDirectory:(NSString *)directoryPath
{
    return [self testsInDirectory:directoryPath replaceCustom:NO];
}


- (NSArray *)testsInDirectory:(NSString *)directoryPath replaceCustom:(BOOL)replace
{
    NSArray *testFilenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:nil];
    NSMutableArray *tests = [[NSMutableArray alloc] init];

    for (NSString *filename in testFilenames) {
        if ([filename hasSuffix:@".json"]) {
            NSError *error = nil;
            NSData *fileData = [NSData dataWithContentsOfFile:[directoryPath stringByAppendingPathComponent:filename] options:0 error:&error];
            if (error) {
                NSLog(@"%@", error.description);
                return nil;
            }

            // Any paths to the local directory are marked with {CUSTOM} in the json file, instead of hardcoding the absolute path
            // Replace this occurance with the path to the custom test directory
            if (replace) {
                NSString *original = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
                NSString *replaced = [original stringByReplacingOccurrencesOfString:@"{CUSTOM}" withString:TWTPathForCustomJSONSchemaTests()];
                fileData = [replaced dataUsingEncoding:NSUTF8StringEncoding];
            }

            id JSONObject = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&error];

            if (error) {
                NSLog(@"Error reading file: %@", error.description);
                return nil;
            }

            if (![JSONObject isKindOfClass:[NSArray class]]) {
                NSLog(@"Expected array of dictionaries with schema as value for ""schema"" key.");
                return nil;
            }
            
            [tests addObjectsFromArray:JSONObject];
        }
    }
    
    return [tests copy];
}


- (NSSet *)failingTestDescriptions
{
    // TWTValidation does not support differentiating between booleans and NSNumbers when checking for unique items in an array,
    // because Objective-C treats 1/0 as equivalent to YES/NO.
    return [NSSet setWithObjects:@"1 and true are unique",
            @"0 and false are unique",
            @"unique heterogeneous types are valid",
            @"remote ref valid", @"remote ref invalid", nil];
}


- (NSSet *)failingTests
{
    // Not currently supporting http URLs
    // or references to fields that aren't keywords or properties
    return [NSSet setWithObjects:@"remote ref, containing refs itself", @"escaped pointer ref",
            @"remote ref", @"fragment within remote ref", @"ref within remote ref", @"change resolution scope", nil];
}

@end
